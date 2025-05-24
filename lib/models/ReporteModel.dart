import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart' as osm;

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
    );
  }

  // Obtener GeoPoint para OSM
  osm.GeoPoint toOsmGeoPoint() {
    return osm.GeoPoint(latitude: latitud, longitude: longitud);
  }

  // Formatear fecha como string
  String get fechaFormateada {
    return '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';
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
}