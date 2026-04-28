import 'dart:math' as math; // AGREGAR IMPORT DE MATEMÁTICAS
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart'; // CAMBIADO DE OSM

class ReporteModel {
  final String id;
  final String folio;
  final String categoria;
  final String descripcion;
  final String direccion;
  final double latitud;
  final double longitud;
  final String estado;
  final DateTime fecha;
  final String userId;
  final String nombreCompleto;
  final String telefono;
  final bool isAnonymous;
  final List<String> imagenes;
  final List<HistorialEstado> historialEstados;
  final int duplicados;
  final List<String> reportesRelacionados;
  final String? esDuplicadoDe;


  ReporteModel({
    required this.id,
    required this.folio,
    required this.categoria,
    required this.descripcion,
    required this.direccion,
    required this.latitud,
    required this.longitud,
    required this.estado,
    required this.fecha,
    required this.userId,
    required this.nombreCompleto,
    required this.telefono,
    this.isAnonymous = false,
    this.imagenes = const [],
    this.historialEstados = const [],
    this.duplicados = 0,
    this.reportesRelacionados = const [],
    this.esDuplicadoDe,
  });

  // Convertir desde Firestore
  factory ReporteModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // Convertir historial de estados
    List<HistorialEstado> historial = [];
    if (data['historialEstados'] != null && data['historialEstados'] is List) {
      historial = (data['historialEstados'] as List)
          .map((estado) => HistorialEstado.fromMap(estado))
          .toList();
    }

    // Convertir imágenes
    List<String> imgs = [];
    if (data['imagenes'] != null && data['imagenes'] is List) {
      imgs = List<String>.from(data['imagenes']);
    }

    return ReporteModel(
      id: doc.id,
      folio: data['folio'] ?? 'Sin folio',
      categoria: data['categoria'] ?? 'Sin categoría',
      descripcion: data['comentario'] ?? 'Sin descripción',
      direccion: data['direccion'] ?? 'Sin dirección',
      latitud: (data['latitud'] as num?)?.toDouble() ?? 0.0,
      longitud: (data['longitud'] as num?)?.toDouble() ?? 0.0,
      estado: data['estado'] ?? 'pendiente',
      fecha: data['fecha'] is Timestamp
          ? (data['fecha'] as Timestamp).toDate()
          : DateTime.now(),
      userId: data['userId'] ?? '',
      nombreCompleto: data['nombreCompleto'] ?? '',
      telefono: data['telefono'] ?? '',
      isAnonymous: data['isAnonymous'] ?? false,
      imagenes: imgs,
      historialEstados: historial,
      duplicados: data['duplicados'] ?? 0,
      reportesRelacionados: data['reportesRelacionados'] != null
          ? List<String>.from(data['reportesRelacionados'])
          : [],
      esDuplicadoDe: data['esDuplicadoDe'],
    );
  }

  // Convertir a Map para guardar en Firestore
  Map<String, dynamic> toMap() {
    return {
      'folio': folio,
      'categoria': categoria,
      'comentario': descripcion,
      'direccion': direccion,
      'latitud': latitud,
      'longitud': longitud,
      'estado': estado,
      'fecha': Timestamp.fromDate(fecha),
      'userId': userId,
      'nombreCompleto': nombreCompleto,
      'telefono': telefono,
      'isAnonymous': isAnonymous,
      'imagenes': imagenes,
      'historialEstados': historialEstados.map((e) => e.toMap()).toList(),
      'duplicados': duplicados,
      'reportesRelacionados': reportesRelacionados,
      'esDuplicadoDe': esDuplicadoDe,
    };
  }

  // Crear una copia con algunos cambios
  ReporteModel copyWith({
    String? id,
    String? folio,
    String? categoria,
    String? descripcion,
    String? direccion,
    double? latitud,
    double? longitud,
    String? estado,
    DateTime? fecha,
    String? userId,
    String? nombreCompleto,
    String? telefono,
    bool? isAnonymous,
    List<String>? imagenes,
    List<HistorialEstado>? historialEstados,
    int? duplicados,
    List<String>? reportesRelacionados,
    String? esDuplicadoDe,
  }) {
    return ReporteModel(
      id: id ?? this.id,
      folio: folio ?? this.folio,
      categoria: categoria ?? this.categoria,
      descripcion: descripcion ?? this.descripcion,
      direccion: direccion ?? this.direccion,
      latitud: latitud ?? this.latitud,
      longitud: longitud ?? this.longitud,
      estado: estado ?? this.estado,
      fecha: fecha ?? this.fecha,
      userId: userId ?? this.userId,
      nombreCompleto: nombreCompleto ?? this.nombreCompleto,
      telefono: telefono ?? this.telefono,
      isAnonymous: isAnonymous ?? this.isAnonymous,
      imagenes: imagenes ?? this.imagenes,
      historialEstados: historialEstados ?? this.historialEstados,
      duplicados: duplicados ?? this.duplicados,
      reportesRelacionados: reportesRelacionados ?? this.reportesRelacionados,
      esDuplicadoDe: esDuplicadoDe ?? this.esDuplicadoDe,
    );
  }

  // MÉTODO ACTUALIZADO: Obtener LatLng para Google Maps
  LatLng toLatLng() {
    return LatLng(latitud, longitud);
  }

  // MÉTODO LEGACY: Mantener compatibilidad con OSM si aún se usa en algún lugar
  // osm.GeoPoint toOsmGeoPoint() {
  //   return osm.GeoPoint(latitude: latitud, longitude: longitud);
  // }

  // Formatear fecha como string
  String get fechaFormateada {
    return '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';
  }

  // NUEVO: Método para obtener información de ubicación
  Map<String, dynamic> get ubicacionInfo {
    return {
      'latitud': latitud,
      'longitud': longitud,
      'latlng': toLatLng(),
      'direccion': direccion,
    };
  }

  // NUEVO: Validar si tiene coordenadas válidas
  bool get tieneUbicacionValida {
    return latitud != 0.0 && longitud != 0.0;
  }

  // NUEVO: Obtener distancia a otra ubicación (en km)
  double distanciaA(LatLng otraUbicacion) {
    if (!tieneUbicacionValida) return double.infinity;

    // Fórmula de Haversine simplificada
    const double radioTierra = 6371; // km

    final double dLat = _gradosARadianes(otraUbicacion.latitude - latitud);
    final double dLon = _gradosARadianes(otraUbicacion.longitude - longitud);

    final double lat1Rad = _gradosARadianes(latitud);
    final double lat2Rad = _gradosARadianes(otraUbicacion.latitude);

    final double a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
            math.cos(lat1Rad) * math.cos(lat2Rad) *
                math.sin(dLon / 2) * math.sin(dLon / 2);

    final double c = 2 * math.asin(math.sqrt(a));

    return radioTierra * c;
  }

  double _gradosARadianes(double grados) {
    return grados * (math.pi / 180); // USAR math.pi
  }
}

class HistorialEstado {
  final String estado;
  final DateTime fecha;
  final String? comentario;

  HistorialEstado({
    required this.estado,
    required this.fecha,
    this.comentario,
  });

  factory HistorialEstado.fromMap(Map<String, dynamic> map) {
    return HistorialEstado(
      estado: map['estado'] ?? 'Estado desconocido',
      fecha: map['fecha'] is Timestamp
          ? (map['fecha'] as Timestamp).toDate()
          : DateTime.now(),
      comentario: map['comentario'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'estado': estado,
      'fecha': Timestamp.fromDate(fecha),
      'comentario': comentario,
    };
  }

  String get fechaFormateada {
    return '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';
  }

  String get horaFormateada {
    return '${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}';
  }

  // NUEVO: Obtener timestamp completo formateado
  String get fechaHoraCompleta {
    return '$fechaFormateada a las $horaFormateada';
  }

  // NUEVO: Verificar si es un estado reciente (últimas 24 horas)
  bool get esReciente {
    final ahora = DateTime.now();
    final diferencia = ahora.difference(fecha);
    return diferencia.inHours < 24;
  }
}