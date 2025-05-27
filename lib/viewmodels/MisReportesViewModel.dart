import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

class MisReportesViewModel extends ChangeNotifier {
  // Estados
  bool _isLoading = false;
  String? _error;
  List<Map<String, dynamic>> _reportes = [];
  String _filtroActual = 'Todos';
  StreamSubscription<QuerySnapshot>? _reportesSubscription;

  // Getters
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<Map<String, dynamic>> get reportes => _reportes;
  String get filtroActual => _filtroActual;

  // Reportes filtrados - ACTUALIZADO PARA NUEVOS ESTADOS
  List<Map<String, dynamic>> get reportesFiltrados {
    if (_filtroActual == 'Todos') {
      return _reportes;
    } else {
      String filtro = _filtroActual.toLowerCase();

      // Mapear filtros a estados reales
      if (filtro == 'pendientes') {
        return _reportes.where((reporte) {
          final estadoReporte = reporte['estado']?.toString().toLowerCase() ?? '';
          return estadoReporte == 'pendiente' || estadoReporte == 'nuevo';
        }).toList();
      } else if (filtro == 'en proceso') {
        return _reportes.where((reporte) {
          final estadoReporte = reporte['estado']?.toString().toLowerCase() ?? '';
          return estadoReporte.contains('proceso') || estadoReporte == 'asignado';
        }).toList();
      } else if (filtro == 'resueltos') {
        return _reportes.where((reporte) {
          final estadoReporte = reporte['estado']?.toString().toLowerCase() ?? '';
          return estadoReporte == 'resuelto' || estadoReporte == 'completado';
        }).toList();
      }

      return _reportes;
    }
  }

  // Cambiar filtro
  void cambiarFiltro(String nuevoFiltro) {
    _filtroActual = nuevoFiltro;
    notifyListeners();
  }

  // Cargar reportes del usuario con Stream
  Future<void> cargarReportes(String userId) async {
    if (_isLoading) return; // Evitar múltiples cargas simultáneas

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Cancelar suscripción anterior si existe
      await _reportesSubscription?.cancel();

      // Crear nueva suscripción a los reportes del usuario
      _reportesSubscription = FirebaseFirestore.instance
          .collection('reportes')
          .where('userId', isEqualTo: userId)
          .orderBy('fecha', descending: true)
          .snapshots()
          .listen(
            (snapshot) {
          if (kDebugMode) {
            print('Recibidos ${snapshot.docs.length} reportes para usuario: $userId');
          }

          // Transformar los documentos en una lista de mapas
          _reportes = snapshot.docs.map((doc) {
            final data = doc.data();
            return {
              'id': doc.id,
              'folio': data['folio'] ?? 'Sin folio',
              'fecha': _formatearFecha(data['fecha']),
              'estado': data['estado'] ?? 'pendiente',
              'tipo': data['categoria'] ?? 'Sin categoría',
              'descripcion': data['comentario'] ?? 'Sin descripción',
              'ubicacion': data['direccion'] ?? 'Sin ubicación',
              'nombreCompleto': data['nombreCompleto'] ?? '',
              'telefono': data['telefono'] ?? '',
              'isAnonymous': data['isAnonymous'] ?? false,
              'imagenes': data['imagenes'] ?? [],
              'historialEstados': data['historialEstados'] ?? [],
              // Datos adicionales que podrían ser útiles
              'latitud': data['latitud'],
              'longitud': data['longitud'],
              'fechaCreacion': data['fecha'], // Fecha original para ordenamiento
            };
          }).toList();

          _isLoading = false;
          _error = null;
          notifyListeners();
        },
        onError: (error) {
          if (kDebugMode) {
            print('Error en stream de reportes: $error');
          }
          _isLoading = false;
          _error = 'Error al cargar reportes: $error';
          notifyListeners();
        },
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error iniciando stream de reportes: $e');
      }
      _isLoading = false;
      _error = 'Error al cargar reportes: $e';
      notifyListeners();
    }
  }

  // Cargar reportes una sola vez (sin Stream)
  Future<void> cargarReportesUnaVez(String userId) async {
    if (_isLoading) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final reportesSnapshot = await FirebaseFirestore.instance
          .collection('reportes')
          .where('userId', isEqualTo: userId)
          .orderBy('fecha', descending: true)
          .get();

      if (kDebugMode) {
        print('Cargados ${reportesSnapshot.docs.length} reportes para usuario: $userId');
      }

      if (reportesSnapshot.docs.isEmpty) {
        _reportes = [];
        _isLoading = false;
        notifyListeners();
        return;
      }

      // Transformar los documentos en una lista de mapas
      _reportes = reportesSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'folio': data['folio'] ?? 'Sin folio',
          'fecha': _formatearFecha(data['fecha']),
          'estado': data['estado'] ?? 'pendiente',
          'tipo': data['categoria'] ?? 'Sin categoría',
          'descripcion': data['comentario'] ?? 'Sin descripción',
          'ubicacion': data['direccion'] ?? 'Sin ubicación',
          'nombreCompleto': data['nombreCompleto'] ?? '',
          'telefono': data['telefono'] ?? '',
          'isAnonymous': data['isAnonymous'] ?? false,
          'imagenes': data['imagenes'] ?? [],
          'historialEstados': data['historialEstados'] ?? [],
          // Datos adicionales que podrían ser útiles
          'latitud': data['latitud'],
          'longitud': data['longitud'],
          'fechaCreacion': data['fecha'], // Fecha original para ordenamiento
        };
      }).toList();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Error cargando reportes: $e');
      }
      _isLoading = false;
      _error = 'Error al cargar reportes: $e';
      notifyListeners();
    }
  }

  // Recargar reportes
  Future<void> recargarReportes(String userId) async {
    await cargarReportesUnaVez(userId);
  }

  // Formatear fecha
  String _formatearFecha(dynamic timestamp) {
    if (timestamp == null) return 'Fecha desconocida';

    try {
      if (timestamp is Timestamp) {
        final fecha = timestamp.toDate();
        return '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';
      } else if (timestamp is DateTime) {
        return '${timestamp.day.toString().padLeft(2, '0')}/${timestamp.month.toString().padLeft(2, '0')}/${timestamp.year}';
      } else {
        return 'Fecha desconocida';
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error formateando fecha: $e');
      }
      return 'Fecha desconocida';
    }
  }

  // Obtener reporte específico por ID
  Map<String, dynamic>? obtenerReportePorId(String reporteId) {
    try {
      return _reportes.firstWhere((reporte) => reporte['id'] == reporteId);
    } catch (e) {
      if (kDebugMode) {
        print('Reporte no encontrado: $reporteId');
      }
      return null;
    }
  }

    // Buscar reportes por término
  List<Map<String, dynamic>> buscarReportes(String termino) {
    if (termino.isEmpty) return reportesFiltrados;

    final terminoLower = termino.toLowerCase();
    return reportesFiltrados.where((reporte) {
      final folio = reporte['folio']?.toString().toLowerCase() ?? '';
      final tipo = reporte['tipo']?.toString().toLowerCase() ?? '';
      final descripcion = reporte['descripcion']?.toString().toLowerCase() ?? '';
      final ubicacion = reporte['ubicacion']?.toString().toLowerCase() ?? '';

      return folio.contains(terminoLower) ||
          tipo.contains(terminoLower) ||
          descripcion.contains(terminoLower) ||
          ubicacion.contains(terminoLower);
    }).toList();
  }

  // Limpiar datos
  void limpiar() {
    _reportesSubscription?.cancel();
    _reportes.clear();
    _filtroActual = 'Todos';
    _error = null;
    _isLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _reportesSubscription?.cancel();
    super.dispose();
  }
}