import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart' as osm;
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

class ReporteService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final CollectionReference _reportesRef;
  final Uuid _uuid = const Uuid();

  ReporteService() : _reportesRef = FirebaseFirestore.instance.collection('reportes');

  // Obtener todos los reportes
  Stream<List<Map<String, dynamic>>> getReportes() {
    return _reportesRef
        .orderBy('fecha', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => {
        'id': doc.id,
        ...doc.data() as Map<String, dynamic>,
      })
          .toList();
    });
  }

  // Obtener reportes filtrados por categoría
  Stream<List<Map<String, dynamic>>> getReportesByCategoria(String categoria) {
    return _reportesRef
        .where('categoria', isEqualTo: categoria)
        .orderBy('fecha', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => {
        'id': doc.id,
        ...doc.data() as Map<String, dynamic>,
      })
          .toList();
    });
  }

  // Obtener reportes de un usuario específico
  Stream<List<Map<String, dynamic>>> getReportesByUser(String userId) {
    return _reportesRef
        .where('userId', isEqualTo: userId)
        .orderBy('fecha', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => {
        'id': doc.id,
        ...doc.data() as Map<String, dynamic>,
      })
          .toList();
    });
  }

  // Obtener un reporte por su ID
  Future<Map<String, dynamic>?> getReporteById(String reporteId) async {
    try {
      final docSnapshot = await _reportesRef.doc(reporteId).get();
      if (docSnapshot.exists) {
        return {
          'id': docSnapshot.id,
          ...docSnapshot.data() as Map<String, dynamic>,
        };
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Error al obtener reporte: $e');
      }
      return null;
    }
  }

  // Crear un nuevo reporte
  Future<String?> crearReporte({
    required String userId,
    required String categoria,
    required String descripcion,
    required String direccion,
    required osm.GeoPoint ubicacion,
    required String nombreCompleto,
    required String telefono,
    bool isAnonymous = false,
    List<File>? imagenes,
  }) async {
    try {
      // Generar un folio único
      final folio = _generarFolio();

      // Obtener una dirección real si la dirección proporcionada parece ser coordenadas
      if (direccion.contains('Lat:') || direccion.contains('Lon:')) {
        final direccionReal = await obtenerDireccion(ubicacion);
        if (direccionReal.isNotEmpty && !direccionReal.contains('Error') && !direccionReal.contains('Latitud')) {
          direccion = direccionReal;
        }
      }

      // Lista para almacenar URLs de imágenes subidas
      List<String> imagenesUrls = [];

      // Subir imágenes si existen
      if (imagenes != null && imagenes.isNotEmpty) {
        imagenesUrls = await _subirImagenes(imagenes, folio);
      }

      // Crear el reporte con historial inicial
      final nuevoReporte = {
        'folio': folio,
        'categoria': categoria,
        'comentario': descripcion,
        'direccion': direccion,
        'latitud': ubicacion.latitude,
        'longitud': ubicacion.longitude,
        'estado': 'pendiente',
        'fecha': Timestamp.now(),
        'userId': userId,
        'nombreCompleto': nombreCompleto,
        'telefono': telefono,
        'isAnonymous': isAnonymous,
        'imagenes': imagenesUrls,
        'historialEstados': [
          {
            'estado': 'Reporte recibido',
            'fecha': Timestamp.now(),
            'comentario': 'Su reporte ha sido recibido y será revisado a la brevedad.'
          }
        ]
      };

      // Guardar en Firestore
      final docRef = await _reportesRef.add(nuevoReporte);
      return docRef.id;
    } catch (e) {
      if (kDebugMode) {
        print('Error al crear reporte: $e');
      }
      return null;
    }
  }

  // Subir imágenes al Storage
  Future<List<String>> _subirImagenes(List<File> imagenes, String folio) async {
    List<String> urls = [];

    for (int i = 0; i < imagenes.length; i++) {
      final file = imagenes[i];
      final fileName = '$folio-$i.jpg';

      try {
        final Reference ref = _storage.ref().child('reportes/$folio/$fileName');
        final UploadTask uploadTask = ref.putFile(file);
        final TaskSnapshot snapshot = await uploadTask;
        final String downloadUrl = await snapshot.ref.getDownloadURL();

        urls.add(downloadUrl);
      } catch (e) {
        if (kDebugMode) {
          print('Error al subir imagen $i: $e');
        }
      }
    }

    return urls;
  }

  // Actualizar el estado de un reporte
  Future<bool> actualizarEstadoReporte({
    required String reporteId,
    required String nuevoEstado,
    String? comentario,
  }) async {
    try {
      // Obtener el reporte actual
      final docSnapshot = await _reportesRef.doc(reporteId).get();
      if (!docSnapshot.exists) return false;

      // Obtener el historial actual
      List<dynamic> historialActual = (docSnapshot.data() as Map<String, dynamic>)['historialEstados'] ?? [];

      // Agregar el nuevo estado al historial
      historialActual.add({
        'estado': nuevoEstado,
        'fecha': Timestamp.now(),
        'comentario': comentario
      });

      // Actualizar el documento
      await _reportesRef.doc(reporteId).update({
        'estado': nuevoEstado,
        'historialEstados': historialActual,
      });

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error al actualizar estado: $e');
      }
      return false;
    }
  }

  // Generar un folio único
  String _generarFolio() {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString().substring(6);
    final random = _uuid.v4().substring(0, 4);
    return 'REP-$timestamp-$random';
  }

  // Codificar una imagen en base64 (útil para almacenar en caché local)
  Future<String> imageToBase64(File file) async {
    try {
      final bytes = await file.readAsBytes();
      return base64Encode(bytes);
    } catch (e) {
      if (kDebugMode) {
        print('Error al convertir imagen a base64: $e');
      }
      return '';
    }
  }

  // Obtener la dirección de unas coordenadas usando OpenStreetMap Nominatim
  Future<String> obtenerDireccion(osm.GeoPoint posicion) async {
    try {
      //Usamos la API de Nominatim directamente
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=${posicion.latitude}&lon=${posicion.longitude}&zoom=18&addressdetails=1',
      );

      final response = await http.get(
        url,
        headers: {'User-Agent': 'LumVida App'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final String direccion = data['display_name'] ?? '';

        if (direccion.isNotEmpty) {
          return direccion;
        }
      }

      // Si todo falla, retornamos las coordenadas formateadas
      return 'Latitud: ${posicion.latitude.toStringAsFixed(6)}, Longitud: ${posicion.longitude.toStringAsFixed(6)}';
    } catch (e) {
      if (kDebugMode) {
        print('Error al obtener dirección: $e');
      }
      return 'Error al obtener la dirección';
    }
  }
}