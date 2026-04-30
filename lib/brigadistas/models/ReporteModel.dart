import 'package:cloud_firestore/cloud_firestore.dart';

// ============================================
// 📦 MODELOS DE DATOS DE BRIGADISTAS
// ============================================

// Modelo de Reporte
class ReporteModel {
  final String id;
  final String categoria;
  final String descripcion;
  final String direccion;
  final String estado;
  final String? folio;
  final GeoPoint? ubicacion;
  final String? nombreUsuario;
  final List<String>? evidencias;
  final List<String>? imagenes; // Fotos enviadas por el ciudadano
  final Timestamp? fechaCreacion;
  final Timestamp? fechaResolucion;
  final Timestamp? fechaUltimaActualizacion;
  final int duplicados;
  final List<String> reportesRelacionados;
  final String? esDuplicadoDe;


  ReporteModel({
    required this.id,
    required this.categoria,
    required this.descripcion,
    required this.direccion,
    required this.estado,
    this.folio,
    this.ubicacion,
    this.nombreUsuario,
    this.evidencias,
    this.imagenes,
    this.fechaCreacion,
    this.fechaResolucion,
    this.fechaUltimaActualizacion,
    this.duplicados = 0,
    this.reportesRelacionados = const [],
    this.esDuplicadoDe,
  });

  factory ReporteModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    GeoPoint? geoPoint;
    if (data['ubicacion'] != null) {
      geoPoint = data['ubicacion'] as GeoPoint;
    } else if (data['latitud'] != null && data['longitud'] != null) {
      geoPoint = GeoPoint(
        (data['latitud'] as num).toDouble(),
        (data['longitud'] as num).toDouble(),
      );
    }

    return ReporteModel(
      id: doc.id,
      categoria: data['categoria'] ?? 'Sin categoría',
      descripcion: data['descripcion'] ?? data['comentario'] ?? 'Sin descripción',
      direccion: data['direccion'] ?? 'Sin dirección',
      estado: data['estado'] ?? 'pendiente',
      folio: data['folio'],
      ubicacion: geoPoint,
      nombreUsuario: data['nombreCompleto'] ?? data['nombreUsuario'],
      evidencias: data['evidencias'] != null
          ? List<String>.from(data['evidencias'])
          : null,
      imagenes: data['imagenes'] != null
          ? List<String>.from(data['imagenes'])
          : null,
      fechaCreacion: data['fechaCreacion'] ?? data['fecha'],
      fechaResolucion: data['fechaResolucion'],
      fechaUltimaActualizacion: data['fechaUltimaActualizacion'],
      duplicados: data['duplicados'] ?? data['contadorDuplicados'] ?? 0,
      reportesRelacionados: (data['reportesRelacionados'] ?? data['reportantesRelacionados']) != null
          ? List<String>.from(data['reportesRelacionados'] ?? data['reportantesRelacionados'])
          : [],
      esDuplicadoDe: data['esDuplicadoDe'],
    );
  }

  factory ReporteModel.fromMap(Map<String, dynamic> data, String id) {
    GeoPoint? geoPoint;
    if (data['ubicacion'] != null) {
      geoPoint = data['ubicacion'] as GeoPoint;
    } else if (data['latitud'] != null && data['longitud'] != null) {
      geoPoint = GeoPoint(
        (data['latitud'] as num).toDouble(),
        (data['longitud'] as num).toDouble(),
      );
    }

    return ReporteModel(
      id: id,
      categoria: data['categoria'] ?? 'Sin categoría',
      descripcion: data['descripcion'] ?? data['comentario'] ?? 'Sin descripción',
      direccion: data['direccion'] ?? 'Sin dirección',
      estado: data['estado'] ?? 'pendiente',
      folio: data['folio'],
      ubicacion: geoPoint,
      nombreUsuario: data['nombreCompleto'] ?? data['nombreUsuario'],
      evidencias: data['evidencias'] != null
          ? List<String>.from(data['evidencias'])
          : null,
      imagenes: data['imagenes'] != null
          ? List<String>.from(data['imagenes'])
          : null,
      fechaCreacion: data['fechaCreacion'] ?? data['fecha'],
      fechaResolucion: data['fechaResolucion'],
      fechaUltimaActualizacion: data['fechaUltimaActualizacion'],
      duplicados: data['duplicados'] ?? data['contadorDuplicados'] ?? 0,
      reportesRelacionados: (data['reportesRelacionados'] ?? data['reportantesRelacionados']) != null
          ? List<String>.from(data['reportesRelacionados'] ?? data['reportantesRelacionados'])
          : [],
      esDuplicadoDe: data['esDuplicadoDe'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'categoria': categoria,
      'descripcion': descripcion,
      'direccion': direccion,
      'estado': estado,
      'folio': folio,
      'ubicacion': ubicacion,
      'nombreUsuario': nombreUsuario,
      'evidencias': evidencias,
      'imagenes': imagenes,
      'fechaCreacion': fechaCreacion,
      'fechaResolucion': fechaResolucion,
      'fechaUltimaActualizacion': fechaUltimaActualizacion,
      'duplicados': duplicados,
      'reportesRelacionados': reportesRelacionados,
      'esDuplicadoDe': esDuplicadoDe,
    };
  }

  bool get esResuelto => estado == 'resuelto' || estado == 'completado';
  bool get esAsignado => estado == 'asignado';
  bool get esEnProceso => estado == 'en_proceso' || estado == 'en proceso';

  // Getters de conveniencia
  double? get latitud => ubicacion?.latitude;
  double? get longitud => ubicacion?.longitude;
  Timestamp? get createdAt => fechaCreacion;
}

// Modelo de Brigada
class BrigadaModel {
  final String id;
  final String nombre;
  final bool activa;
  final List<dynamic> miembros;
  final List<dynamic> reportesAsignados;

  BrigadaModel({
    required this.id,
    required this.nombre,
    required this.activa,
    required this.miembros,
    required this.reportesAsignados,
  });

  factory BrigadaModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BrigadaModel(
      id: doc.id,
      nombre: data['nombre'] ?? 'Brigada',
      activa: data['activa'] ?? false,
      miembros: data['miembros'] ?? [],
      reportesAsignados: data['reportesAsignados'] ?? [],
    );
  }

  factory BrigadaModel.fromMap(Map<String, dynamic> data, String id) {
    return BrigadaModel(
      id: id,
      nombre: data['nombre'] ?? 'Brigada',
      activa: data['activa'] ?? false,
      miembros: data['miembros'] ?? [],
      reportesAsignados: data['reportesAsignados'] ?? [],
    );
  }
}

// Modelo de Estadísticas
class EstadisticasModel {
  final int total;
  final int asignados;
  final int enProceso;
  final int resueltos;

  EstadisticasModel({
    required this.total,
    required this.asignados,
    required this.enProceso,
    required this.resueltos,
  });

  factory EstadisticasModel.vacio() {
    return EstadisticasModel(
      total: 0,
      asignados: 0,
      enProceso: 0,
      resueltos: 0,
    );
  }
}