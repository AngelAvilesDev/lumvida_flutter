import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MisReportesViewModel extends ChangeNotifier {
  // Estados
  bool _isLoading = false;
  String? _error;
  List<Map<String, dynamic>> _reportes = [];
  String _filtroActual = 'Todos';

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
        filtro = 'pendiente';
      } else if (filtro == 'en revisión' || filtro == 'en revision') {
        filtro = 'en revision';
      } else if (filtro == 'asignado') {
        filtro = 'asignado';
      } else if (filtro == 'en proceso') {
        filtro = 'en proceso';
      } else if (filtro == 'resueltos') {
        filtro = 'resuelto';
      }

      return _reportes.where((reporte) {
        final estadoReporte = reporte['estado'].toLowerCase();
        return estadoReporte == filtro ||
            (filtro == 'pendiente' && (estadoReporte == 'nuevo' || estadoReporte == 'pendiente')) ||
            (filtro == 'resuelto' && (estadoReporte == 'completado' || estadoReporte == 'resuelto'));
      }).toList();
    }
  }

  // Cambiar filtro
  void cambiarFiltro(String nuevoFiltro) {
    _filtroActual = nuevoFiltro;
    notifyListeners();
  }

  // Cargar reportes del usuario
  Future<void> cargarReportes(String userId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final reportesSnapshot = await FirebaseFirestore.instance
          .collection('reportes')
          .where('userId', isEqualTo: userId)
          .orderBy('fecha', descending: true)
          .get();

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
      _isLoading = false;
      _error = 'Error al cargar reportes: $e';
      notifyListeners();
    }
  }

  // Recargar reportes
  Future<void> recargarReportes(String userId) async {
    await cargarReportes(userId);
  }

  // Formatear fecha
  String _formatearFecha(dynamic timestamp) {
    if (timestamp == null) return 'Fecha desconocida';

    try {
      if (timestamp is Timestamp) {
        final fecha = timestamp.toDate();
        return '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';
      } else {
        return 'Fecha desconocida';
      }
    } catch (e) {
      return 'Fecha desconocida';
    }
  }

  // Obtener reporte específico por ID
  Map<String, dynamic>? obtenerReportePorId(String reporteId) {
    try {
      return _reportes.firstWhere((reporte) => reporte['id'] == reporteId);
    } catch (e) {
      return null;
    }
  }

  // Obtener estadísticas de reportes
  Map<String, int> obtenerEstadisticas() {
    final stats = {
      'total': _reportes.length,
      'pendientes': 0,
      'enProceso': 0,
      'resueltos': 0,
      'cancelados': 0,
    };

    for (final reporte in _reportes) {
      final estado = reporte['estado'].toLowerCase();
      switch (estado) {
        case 'pendiente':
          stats['pendientes'] = (stats['pendientes'] ?? 0) + 1;
          break;
        case 'en proceso':
          stats['enProceso'] = (stats['enProceso'] ?? 0) + 1;
          break;
        case 'resuelto':
          stats['resueltos'] = (stats['resueltos'] ?? 0) + 1;
          break;
        case 'cancelado':
          stats['cancelados'] = (stats['cancelados'] ?? 0) + 1;
          break;
      }
    }

    return stats;
  }

  // Buscar reportes por término
  List<Map<String, dynamic>> buscarReportes(String termino) {
    if (termino.isEmpty) return reportesFiltrados;

    final terminoLower = termino.toLowerCase();
    return reportesFiltrados.where((reporte) {
      return reporte['folio'].toLowerCase().contains(terminoLower) ||
          reporte['tipo'].toLowerCase().contains(terminoLower) ||
          reporte['descripcion'].toLowerCase().contains(terminoLower) ||
          reporte['ubicacion'].toLowerCase().contains(terminoLower);
    }).toList();
  }

  // Limpiar datos
  void limpiar() {
    _reportes.clear();
    _filtroActual = 'Todos';
    _error = null;
    _isLoading = false;
    notifyListeners();
  }
}