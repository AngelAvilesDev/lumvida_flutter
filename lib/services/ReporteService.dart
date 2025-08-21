import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart' as osm;
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

class ReporteService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final CollectionReference _reportesRef;
  final Uuid _uuid = const Uuid();

  ReporteService() : _reportesRef = FirebaseFirestore.instance.collection('reportes');

  // Obtener todos los reportes (sin cambios)
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

  // Obtener reportes filtrados por categoría (sin cambios)
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

  // Obtener reportes de un usuario específico (sin cambios)
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

  // Obtener un reporte por su ID (sin cambios)
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

  // Crear un nuevo reporte - MODIFICADO PARA USAR BASE64
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

      // Lista para almacenar las imágenes en Base64
      List<String> imagenesBase64 = [];

      // Convertir imágenes a Base64 si existen
      if (imagenes != null && imagenes.isNotEmpty) {
        if (kDebugMode) {
          print('Convirtiendo ${imagenes.length} imágenes a Base64...');
        }

        final result = await _convertirImagenesABase64(imagenes);

        if (result['success']) {
          imagenesBase64 = result['base64Images'];
          if (kDebugMode) {
            print('Imágenes convertidas exitosamente: ${imagenesBase64.length}');
          }
        } else {
          // Si falló la conversión, mostrar error específico
          if (kDebugMode) {
            print('Error al convertir imágenes: ${result['error']}');
          }

          // Para errores de conversión, continuar sin imágenes
          imagenesBase64 = [];
        }
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
        'imagenes': imagenesBase64,  // Aquí guardamos las imágenes en Base64
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

      if (kDebugMode) {
        print('Reporte creado exitosamente con ID: ${docRef.id}');
      }

      return docRef.id;
    } catch (e) {
      if (kDebugMode) {
        print('Error al crear reporte: $e');
      }
      rethrow; // Re-lanzar la excepción para que el ViewModel la maneje
    }
  }

  // Convertir imágenes a Base64 - NUEVO MÉTODO
  Future<Map<String, dynamic>> _convertirImagenesABase64(List<File> imagenes) async {
    List<String> base64Images = [];
    List<String> errores = [];

    for (int i = 0; i < imagenes.length; i++) {
      final file = imagenes[i];

      try {
        if (kDebugMode) {
          print('Convirtiendo imagen $i a Base64');
        }

        // Verificar que el archivo existe y es válido
        if (!await file.exists()) {
          errores.add('Archivo $i no existe');
          continue;
        }

        // Verificar el tamaño del archivo (máximo 10MB)
        final fileSize = await file.length();
        if (fileSize > 10 * 1024 * 1024) {
          errores.add('Archivo $i es demasiado grande (${(fileSize / 1024 / 1024).toStringAsFixed(1)}MB)');
          continue;
        }

        // Leer los bytes del archivo
        final bytes = await file.readAsBytes();

        // Convertir a Base64
        final base64String = base64Encode(bytes);

        // Agregar prefijo del tipo de imagen para poder mostrarla después
        final base64WithPrefix = 'data:image/jpeg;base64,$base64String';

        base64Images.add(base64WithPrefix);

        if (kDebugMode) {
          print('Imagen $i convertida exitosamente (${(base64String.length / 1024).toStringAsFixed(1)}KB)');
        }

      } catch (e) {
        final errorMsg = 'Error al convertir imagen $i: $e';
        errores.add(errorMsg);
        if (kDebugMode) {
          print(errorMsg);
        }
      }
    }

    final bool success = base64Images.isNotEmpty;

    return {
      'success': success,
      'base64Images': base64Images,
      'error': errores.isNotEmpty ? errores.join(', ') : null,
      'errores': errores,
      'convertedCount': base64Images.length,
      'totalCount': imagenes.length,
    };
  }

  // Actualizar el estado de un reporte (sin cambios)
  Future<bool> actualizarEstadoReporte({
    required String reporteId,
    required String nuevoEstado,
    String? comentario,
  }) async {
    try {
      final docSnapshot = await _reportesRef.doc(reporteId).get();
      if (!docSnapshot.exists) return false;

      List<dynamic> historialActual = (docSnapshot.data() as Map<String, dynamic>)['historialEstados'] ?? [];

      historialActual.add({
        'estado': nuevoEstado,
        'fecha': Timestamp.now(),
        'comentario': comentario
      });

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

  // Generar un folio único (sin cambios)
  String _generarFolio() {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString().substring(6);
    final random = _uuid.v4().substring(0, 4);
    return 'REP-$timestamp-$random';
  }

  // Codificar una imagen en base64 - MÉTODO MEJORADO
  Future<String> imageToBase64(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final base64String = base64Encode(bytes);
      return 'data:image/jpeg;base64,$base64String';
    } catch (e) {
      if (kDebugMode) {
        print('Error al convertir imagen a base64: $e');
      }
      return '';
    }
  }

  // Método para convertir Base64 de vuelta a imagen (para mostrar)
  static List<int> base64ToBytes(String base64String) {
    try {
      // Remover el prefijo si existe
      String cleanBase64 = base64String;
      if (base64String.contains(',')) {
        cleanBase64 = base64String.split(',')[1];
      }
      return base64Decode(cleanBase64);
    } catch (e) {
      if (kDebugMode) {
        print('Error al decodificar Base64: $e');
      }
      return [];
    }
  }

  // Obtener la dirección de unas coordenadas usando OpenStreetMap Nominatim (sin cambios)
  Future<String> obtenerDireccion(osm.GeoPoint posicion) async {
    try {
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

      return 'Latitud: ${posicion.latitude.toStringAsFixed(6)}, Longitud: ${posicion.longitude.toStringAsFixed(6)}';
    } catch (e) {
      if (kDebugMode) {
        print('Error al obtener dirección: $e');
      }
      return 'Error al obtener la dirección';
    }
  }

  // Método para validar imágenes antes de convertir
  Future<bool> validarImagen(File file) async {
    try {
      // Verificar que existe
      if (!await file.exists()) {
        return false;
      }

      // Verificar tamaño (máximo 10MB)
      final fileSize = await file.length();
      if (fileSize > 10 * 1024 * 1024) {
        return false;
      }

      // Verificar que es una imagen válida intentando leer los primeros bytes
      final bytes = await file.openRead(0, 10).toList();
      if (bytes.isEmpty) {
        return false;
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error al validar imagen: $e');
      }
      return false;
    }
  }

  // Método para obtener información de tamaño de las imágenes Base64
  Map<String, dynamic> obtenerInfoImagenes(List<String> imagenesBase64) {
    int totalSize = 0;
    List<Map<String, dynamic>> imagenInfo = [];

    for (int i = 0; i < imagenesBase64.length; i++) {
      final imagen = imagenesBase64[i];
      final sizeInBytes = (imagen.length * 3 / 4).round(); // Aproximación del tamaño real
      totalSize += sizeInBytes;

      imagenInfo.add({
        'index': i,
        'sizeKB': (sizeInBytes / 1024).toStringAsFixed(1),
        'hasPrefix': imagen.contains('data:image'),
      });
    }

    return {
      'totalImages': imagenesBase64.length,
      'totalSizeKB': (totalSize / 1024).toStringAsFixed(1),
      'totalSizeMB': (totalSize / 1024 / 1024).toStringAsFixed(2),
      'imageInfo': imagenInfo,
    };
  }
}