import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'dart:async';
import '../models/ReporteModel.dart';

class BrigadaService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // ============================================
  // 🔍 OBTENER BRIGADA DEL USUARIO
  // ============================================
  Future<Map<String, dynamic>?> obtenerBrigadaDelUsuario() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final brigadasSnapshot = await _firestore
          .collection('brigadas')
          .where('activa', isEqualTo: true)
          .get();

      for (var doc in brigadasSnapshot.docs) {
        final data = doc.data();
        final miembros = data['miembros'] as List<dynamic>?;

        if (miembros != null) {
          final perteneceABrigada = miembros.any((miembro) {
            final email = miembro['email'] as String?;
            return email != null && email.toLowerCase() == user.email?.toLowerCase();
          });

          if (perteneceABrigada) {
            return {
              'id': doc.id,
              ...data,
            };
          }
        }
      }

      return null;
    } catch (e) {
      if (kDebugMode) print('❌ Error al obtener brigada del usuario: $e');
      return null;
    }
  }

  // ============================================
  // 📊 OBTENER ESTADÍSTICAS
  // ============================================
  Stream<EstadisticasModel> obtenerEstadisticasStream(List<dynamic> reportesIds) {
    if (reportesIds.isEmpty) {
      return Stream.value(EstadisticasModel.vacio());
    }

    final idsStrings = reportesIds.map((id) => id.toString()).take(10).toList();

    return _firestore
        .collection('reportes')
        .where(FieldPath.documentId, whereIn: idsStrings)
        .snapshots()
        .map((snapshot) {
      int total = 0;
      int asignados = 0;
      int enProceso = 0;
      int resueltos = 0;

      for (var doc in snapshot.docs) {
        if (doc.exists) {
          final estado = doc.data()['estado'] ?? '';

          if (estado != 'pendiente') {
            total++;
            if (estado == 'asignado') asignados++;
            else if (estado == 'en_proceso' || estado == 'en proceso') enProceso++;
            else if (estado == 'resuelto' || estado == 'completado') resueltos++;
          }
        }
      }

      return EstadisticasModel(
        total: total,
        asignados: asignados,
        enProceso: enProceso,
        resueltos: resueltos,
      );
    });
  }

  // ============================================
  // 📋 OBTENER REPORTES (Stream en tiempo real)
  // ============================================
  Stream<List<ReporteModel>> obtenerReportesStream(
      List<dynamic> reportesIds,
      {bool soloActivos = false, bool soloResueltos = false}
      ) {
    if (reportesIds.isEmpty) {
      return Stream.value([]);
    }

    final idsStrings = reportesIds.map((id) => id.toString()).take(10).toList();

    return _firestore
        .collection('reportes')
        .where(FieldPath.documentId, whereIn: idsStrings)
        .snapshots()
        .asyncMap((snapshot) async {
      final reportes = <ReporteModel>[];

      for (var doc in snapshot.docs) {
        if (doc.exists) {
          final reporte = ReporteModel.fromFirestore(doc);

          // Filtrar según tipo
          if (soloActivos && !reporte.esAsignado && !reporte.esEnProceso) {
            continue;
          }
          if (soloResueltos && !reporte.esResuelto) {
            continue;
          }

          reportes.add(reporte);
        }
      }

      // Cargar reportes restantes si hay más de 10
      if (reportesIds.length > 10) {
        final reportesRestantes = await _cargarReportesRestantes(
          reportesIds.skip(10).toList(),
          soloActivos: soloActivos,
          soloResueltos: soloResueltos,
        );
        reportes.addAll(reportesRestantes);
      }

      return reportes;
    });
  }

  Future<List<ReporteModel>> _cargarReportesRestantes(
      List<dynamic> remainingIds,
      {bool soloActivos = false, bool soloResueltos = false}
      ) async {
    final reportes = <ReporteModel>[];

    for (var i = 0; i < remainingIds.length; i += 10) {
      final batch = remainingIds.skip(i).take(10).toList();
      final idsStrings = batch.map((id) => id.toString()).toList();

      try {
        final snapshot = await _firestore
            .collection('reportes')
            .where(FieldPath.documentId, whereIn: idsStrings)
            .get();

        for (var doc in snapshot.docs) {
          if (doc.exists) {
            final reporte = ReporteModel.fromFirestore(doc);

            if (soloActivos && !reporte.esAsignado && !reporte.esEnProceso) {
              continue;
            }
            if (soloResueltos && !reporte.esResuelto) {
              continue;
            }

            reportes.add(reporte);
          }
        }
      } catch (e) {
        if (kDebugMode) print('❌ Error cargando batch: $e');
      }
    }

    return reportes;
  }

  // ============================================
  // 🔄 ACTUALIZAR ESTADO DE REPORTE
  // ============================================
  Future<bool> actualizarEstadoReporte(
      String reporteId,
      String nuevoEstado,
      {List<String>? urlsEvidencias}
      ) async {
    try {
      Map<String, dynamic> updateData = {
        'estado': nuevoEstado,
        'fechaUltimaActualizacion': FieldValue.serverTimestamp(),
      };

      if (nuevoEstado == 'resuelto') {
        updateData['fechaResolucion'] = FieldValue.serverTimestamp();
        if (urlsEvidencias != null && urlsEvidencias.isNotEmpty) {
          updateData['evidencias'] = urlsEvidencias;
        }
      }

      await _firestore.collection('reportes').doc(reporteId).update(updateData);

      if (kDebugMode) print('✅ Estado actualizado: $reporteId → $nuevoEstado');
      return true;
    } catch (e) {
      if (kDebugMode) print('❌ Error al actualizar estado: $e');
      return false;
    }
  }

  // ============================================
  // 📤 SUBIR IMÁGENES A STORAGE
  // ============================================
  Future<List<String>> subirImagenesEvidencia(
      String reporteId,
      List<File> imagenes,
      {Function(double)? onProgress}
      ) async {
    if (kDebugMode) {
      print('═══════════════════════════════════════');
      print('🚀 INICIANDO SUBIDA DE IMÁGENES');
      print('═══════════════════════════════════════');
      print('📋 Total de imágenes: ${imagenes.length}');
      print('📝 ID del reporte: $reporteId');
    }

    List<String> urlsImagenes = [];

    try {
      for (int i = 0; i < imagenes.length; i++) {
        final file = imagenes[i];

        if (kDebugMode) {
          print('\n--- Imagen ${i + 1}/${imagenes.length} ---');
          final fileSize = await file.length();
          final sizeMB = fileSize / (1024 * 1024);
          print('📏 Tamaño: ${sizeMB.toStringAsFixed(2)} MB');
        }

        // Validar tamaño
        final fileSize = await file.length();
        if (fileSize > 10 * 1024 * 1024) {
          throw Exception('La imagen ${i + 1} supera 10MB');
        }

        // Crear nombre único
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final fileName = 'evidencia_${reporteId}_${timestamp}_$i.jpg';
        final path = 'evidencias/$fileName';

        final storageRef = _storage.ref().child(path);

        // Metadata
        final metadata = SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {
            'reporteId': reporteId,
            'uploadedBy': _auth.currentUser?.email ?? 'unknown',
            'uploadedAt': DateTime.now().toIso8601String(),
            'imageIndex': i.toString(),
          },
        );

        // Subir imagen
        final uploadTask = storageRef.putFile(file, metadata);

        // Escuchar progreso
        uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
          final progress = snapshot.bytesTransferred / snapshot.totalBytes;
          final progresoTotal = (i + progress) / imagenes.length;
          onProgress?.call(progresoTotal);
        });

        // Esperar finalización
        await uploadTask.timeout(const Duration(seconds: 90));

        // Obtener URL
        final downloadUrl = await storageRef.getDownloadURL().timeout(
          const Duration(seconds: 15),
        );

        urlsImagenes.add(downloadUrl);

        if (kDebugMode) {
          print('✅ Imagen ${i + 1} subida: ${downloadUrl.substring(0, 60)}...');
        }
      }

      if (kDebugMode) {
        print('\n═══════════════════════════════════════');
        print('🎉 TODAS LAS IMÁGENES SUBIDAS');
        print('═══════════════════════════════════════');
      }

      return urlsImagenes;

    } on FirebaseException catch (e) {
      if (kDebugMode) {
        print('❌ FirebaseException: ${e.code} - ${e.message}');
      }

      String mensajeError;
      switch (e.code) {
        case 'unauthorized':
          mensajeError = 'No tienes permisos para subir imágenes';
          break;
        case 'canceled':
          mensajeError = 'Subida cancelada';
          break;
        default:
          mensajeError = 'Error de Firebase: ${e.message}';
      }

      throw Exception(mensajeError);

    } on TimeoutException catch (e) {
      if (kDebugMode) print('⏱️ Timeout: ${e.message}');
      throw Exception('Conexión lenta. Verifica tu internet.');

    } catch (e) {
      if (kDebugMode) print('❌ Error: $e');
      throw Exception('Error al subir imágenes: $e');
    }
  }
}