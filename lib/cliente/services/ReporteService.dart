import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
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

  // MÉTODO ACTUALIZADO PARA GOOGLE MAPS
  Future<String?> crearReporteFromLatLng({
    required String userId,
    required String categoria,
    required String descripcion,
    required String direccion,
    required LatLng ubicacion, // CAMBIADO DE osm.GeoPoint
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
        final direccionReal = await obtenerDireccionFromLatLng(ubicacion);
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
          if (kDebugMode) {
            print('Error al convertir imágenes: ${result['error']}');
          }
          imagenesBase64 = [];
        }
      }

      // Crear el reporte con historial inicial
      final nuevoReporte = {
        'folio': folio,
        'categoria': categoria,
        'comentario': descripcion,
        'direccion': direccion,
        'latitud': ubicacion.latitude, // USANDO LatLng
        'longitud': ubicacion.longitude, // USANDO LatLng
        'estado': 'pendiente',
        'fecha': Timestamp.now(),
        'userId': userId,
        'nombreCompleto': nombreCompleto,
        'telefono': telefono,
        'isAnonymous': isAnonymous,
        'imagenes': imagenesBase64,
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
      rethrow;
    }
  }

  // MÉTODO LEGACY PARA COMPATIBILIDAD - MANTENER HASTA QUE TODO ESTÉ MIGRADO
  Future<String?> crearReporte({
    required String userId,
    required String categoria,
    required String descripcion,
    required String direccion,
    required dynamic ubicacion, // Acepta tanto LatLng como osm.GeoPoint
    required String nombreCompleto,
    required String telefono,
    bool isAnonymous = false,
    List<File>? imagenes,
  }) async {
    // Convertir a LatLng si viene como osm.GeoPoint
    LatLng latLng;
    if (ubicacion is LatLng) {
      latLng = ubicacion;
    } else {
      // Asumir que viene como osm.GeoPoint con propiedades latitude y longitude
      latLng = LatLng(ubicacion.latitude, ubicacion.longitude);
    }

    return crearReporteFromLatLng(
      userId: userId,
      categoria: categoria,
      descripcion: descripcion,
      direccion: direccion,
      ubicacion: latLng,
      nombreCompleto: nombreCompleto,
      telefono: telefono,
      isAnonymous: isAnonymous,
      imagenes: imagenes,
    );
  }

  // Convertir imágenes a Base64 - CON COMPRESIÓN OPTIMIZADA
  Future<Map<String, dynamic>> _convertirImagenesABase64(List<File> imagenes) async {
    List<String> base64Images = [];
    List<String> errores = [];

    for (int i = 0; i < imagenes.length; i++) {
      final file = imagenes[i];

      try {
        if (kDebugMode) {
          print('🔄 Comprimiendo y convirtiendo imagen $i...');
        }

        // Verificar que el archivo existe y es válido
        if (!await file.exists()) {
          errores.add('Archivo $i no existe');
          continue;
        }

        // Verificar el tamaño del archivo original (máximo 10MB)
        final originalSize = await file.length();
        if (originalSize > 10 * 1024 * 1024) {
          errores.add('Archivo $i es demasiado grande (${(originalSize / 1024 / 1024).toStringAsFixed(1)}MB)');
          continue;
        }

        // 📦 COMPRIMIR IMAGEN (reducir ~70% del tamaño)
        Uint8List? compressedBytes;
        try {
          compressedBytes = await FlutterImageCompress.compressWithFile(
            file.absolute.path,
            quality: 70,          // Calidad 70% (buen balance calidad/tamaño)
            minWidth: 1920,       // Max ancho
            minHeight: 1920,      // Max alto
            format: CompressFormat.jpeg,
          );
        } catch (compressError) {
          if (kDebugMode) {
            print('⚠️ Error de compresión, usando imagen original: $compressError');
          }
          // Fallback: usar imagen sin comprimir
          compressedBytes = await file.readAsBytes();
        }

        if (compressedBytes == null || compressedBytes.isEmpty) {
          errores.add('Error al comprimir imagen $i');
          continue;
        }

        // Convertir a Base64
        final base64String = base64Encode(compressedBytes);

        // Agregar prefijo del tipo de imagen
        final base64WithPrefix = 'data:image/jpeg;base64,$base64String';

        base64Images.add(base64WithPrefix);

        if (kDebugMode) {
          final originalKB = originalSize / 1024;
          final compressedKB = compressedBytes.length / 1024;
          final savings = ((1 - compressedBytes.length / originalSize) * 100).toStringAsFixed(0);
          print('✅ Imagen $i: ${originalKB.toStringAsFixed(0)}KB → ${compressedKB.toStringAsFixed(0)}KB (${savings}% ahorro)');
        }

      } catch (e) {
        final errorMsg = 'Error al convertir imagen $i: $e';
        errores.add(errorMsg);
        if (kDebugMode) {
          print('❌ $errorMsg');
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

  // Codificar una imagen en base64 - SIN CAMBIOS
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

  // Método para convertir Base64 de vuelta a imagen (sin cambios)
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

  // MÉTODO ACTUALIZADO PARA OBTENER DIRECCIÓN CON LatLng - MEJORADO
  Future<String> obtenerDireccionFromLatLng(LatLng posicion) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=${posicion.latitude}&lon=${posicion.longitude}&zoom=18&addressdetails=1&accept-language=es',
      );

      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'LumVida App/1.0 (tu-email@ejemplo.com)', // User-Agent más específico
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // MEJORAR: Construir dirección más legible
        String direccion = '';

        // Intentar obtener dirección formateada
        if (data['display_name'] != null) {
          direccion = data['display_name'];
        } else if (data['address'] != null) {
          // Construir dirección desde componentes
          final address = data['address'];
          List<String> partesDireccion = [];

          // Agregar calle y número
          if (address['house_number'] != null && address['road'] != null) {
            partesDireccion.add('${address['road']} ${address['house_number']}');
          } else if (address['road'] != null) {
            partesDireccion.add(address['road']);
          }

          // Agregar colonia/barrio
          if (address['neighbourhood'] != null) {
            partesDireccion.add(address['neighbourhood']);
          } else if (address['suburb'] != null) {
            partesDireccion.add(address['suburb']);
          }

          // Agregar ciudad
          if (address['city'] != null) {
            partesDireccion.add(address['city']);
          } else if (address['town'] != null) {
            partesDireccion.add(address['town']);
          }

          // Agregar estado
          if (address['state'] != null) {
            partesDireccion.add(address['state']);
          }

          // Agregar código postal
          if (address['postcode'] != null) {
            partesDireccion.add(address['postcode']);
          }

          // Agregar país
          if (address['country'] != null) {
            partesDireccion.add(address['country']);
          }

          direccion = partesDireccion.join(', ');
        }

        if (direccion.isNotEmpty) {
          if (kDebugMode) {
            print('✅ Dirección obtenida: $direccion');
          }
          return direccion;
        }
      } else {
        if (kDebugMode) {
          print('❌ Error en Nominatim: ${response.statusCode}');
        }
      }

      // Fallback mejorado
      return 'Ubicación en Chetumal (${posicion.latitude.toStringAsFixed(4)}, ${posicion.longitude.toStringAsFixed(4)})';

    } catch (e) {
      if (kDebugMode) {
        print('❌ Error al obtener dirección: $e');
      }
      return 'Ubicación seleccionada';
    }
  }

  // MÉTODO LEGACY PARA COMPATIBILIDAD - MANTENER
  Future<String> obtenerDireccion(dynamic posicion) async {
    // Convertir a LatLng si viene como osm.GeoPoint
    if (posicion is LatLng) {
      return obtenerDireccionFromLatLng(posicion);
    } else {
      // Asumir que viene como osm.GeoPoint
      final latLng = LatLng(posicion.latitude, posicion.longitude);
      return obtenerDireccionFromLatLng(latLng);
    }
  }

  // Método para validar imágenes antes de convertir (sin cambios)
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

  // Método para obtener información de tamaño de las imágenes Base64 (sin cambios)
  Map<String, dynamic> obtenerInfoImagenes(List<String> imagenesBase64) {
    int totalSize = 0;
    List<Map<String, dynamic>> imagenInfo = [];

    for (int i = 0; i < imagenesBase64.length; i++) {
      final imagen = imagenesBase64[i];
      final sizeInBytes = (imagen.length * 3 / 4).round();
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