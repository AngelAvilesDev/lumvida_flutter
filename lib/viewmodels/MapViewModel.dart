import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart' as osm;
import 'package:flutter/material.dart';
import '../components/OSMMapComponent.dart';
import '../utils/constants.dart';
import '../utils/report_categories.dart'; // IMPORTAR LAS CATEGORÍAS CENTRALIZADAS

class MapViewModel extends ChangeNotifier {
  // Estados
  bool _isLoading = false;
  String? _error;
  List<MarkerData> _reportMarkers = [];
  String? _selectedFilter;
  List<Map<String, dynamic>> _rawReportes = [];

  // CACHE DE CATEGORÍAS PARA OPTIMIZACIÓN
  late final Map<String, ReportCategory> _categoryCache;
  late final List<String> _availableFilters;

  // Constructor - INICIALIZAR CACHE
  MapViewModel() {
    _initializeCategoryCache();
  }

  void _initializeCategoryCache() {
    _categoryCache = {};
    final categories = ReportCategories.getActiveCategories();

    for (final category in categories) {
      // Agregar variaciones de nombres para mejor matching
      _categoryCache[category.name.toLowerCase()] = category;

      // Agregar variaciones comunes
      if (category.name.toLowerCase().contains('alumbrado')) {
        _categoryCache['alumbrado'] = category;
        _categoryCache['alumbrado público'] = category;
        _categoryCache['alumbrado publico'] = category;
      }
      if (category.name.toLowerCase().contains('basura')) {
        _categoryCache['basura'] = category;
        _categoryCache['basura acumulada'] = category;
      }
      if (category.name.toLowerCase().contains('drenaje')) {
        _categoryCache['drenajes'] = category;
        _categoryCache['drenaje'] = category;
        _categoryCache['drenajes obstruidos'] = category;
      }
      if (category.name.toLowerCase().contains('bacheo')) {
        _categoryCache['bacheo'] = category;
      }
    }

    // Crear lista de filtros disponibles
    _availableFilters = ['Todos'] + ReportCategories.getCategoryNames();

    if (kDebugMode) {
      print('Cache de categorías inicializado con ${_categoryCache.length} entradas');
      print('Filtros disponibles: $_availableFilters');
    }
  }

  // Getters
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<MarkerData> get reportMarkers => _reportMarkers;
  String? get selectedFilter => _selectedFilter;
  List<Map<String, dynamic>> get rawReportes => _rawReportes;
  List<String> get availableFilters => _availableFilters;

  // MARCADORES FILTRADOS - LÓGICA MEJORADA CON CATEGORÍAS DINÁMICAS
  List<MarkerData> get filteredMarkers {
    if (_selectedFilter == null || _selectedFilter == 'Todos') {
      return _reportMarkers;
    }

    return _reportMarkers.where((marker) {
      if (marker.title == null) return false;

      String categoriaOriginal = marker.title!.split(' - ').first.toLowerCase().trim();
      String filtro = _selectedFilter!.toLowerCase().trim();

      if (kDebugMode) {
        print('Comparando: "$categoriaOriginal" con filtro: "$filtro"');
      }

      // Usar el cache de categorías para matching más preciso
      return _categoryCache.containsKey(categoriaOriginal) &&
          _categoryCache.containsKey(filtro) &&
          _categoryCache[categoriaOriginal] == _categoryCache[filtro];
    }).toList();
  }

  // CARGAR UBICACIONES - LÓGICA OPTIMIZADA
  Future<void> cargarUbicacionesReportes() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final reportesSnapshot = await FirebaseFirestore.instance
          .collection('reportes')
          .get();

      if (kDebugMode) {
        print('Número de reportes encontrados: ${reportesSnapshot.docs.length}');
      }

      final markers = <MarkerData>[];
      _rawReportes.clear();

      for (var doc in reportesSnapshot.docs) {
        final data = doc.data();
        _rawReportes.add({
          'id': doc.id,
          ...data,
        });

        if (kDebugMode) {
          print('Datos del reporte: ${data['categoria']} - ${data['folio']}');
        }

        // Obtener coordenadas
        double? latitud;
        double? longitud;

        if (data['latitud'] != null && data['longitud'] != null) {
          latitud = (data['latitud'] as num).toDouble();
          longitud = (data['longitud'] as num).toDouble();
        } else if (data['ubicacion'] != null &&
            data['ubicacion'] is Map &&
            data['ubicacion']['latitud'] != null &&
            data['ubicacion']['longitud'] != null) {
          latitud = (data['ubicacion']['latitud'] as num).toDouble();
          longitud = (data['ubicacion']['longitud'] as num).toDouble();
        }

        if (latitud != null && longitud != null) {
          final categoria = data['categoria']?.toString() ?? '';
          final markerIcon = _getMarkerIconForCategory(categoria);

          if (kDebugMode) {
            print('Añadiendo marcador en: Lat $latitud, Lon $longitud - Categoría: $categoria');
          }

          markers.add(
            MarkerData(
              position: osm.GeoPoint(
                latitude: latitud,
                longitude: longitud,
              ),
              icon: markerIcon,
              title: '${data['categoria'] ?? 'Sin categoría'} - ${data['folio'] ?? 'Sin folio'}',
            ),
          );
        } else {
          if (kDebugMode) {
            print('Reporte sin coordenadas válidas: ${doc.id}');
          }
        }
      }

      if (kDebugMode) {
        print('Total de marcadores creados: ${markers.length}');
      }

      _reportMarkers = markers;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Error cargando ubicaciones: $e');
      }
      _isLoading = false;
      _error = 'Error al cargar ubicaciones: $e';
      notifyListeners();
    }
  }

  // APLICAR FILTRO - LÓGICA OPTIMIZADA
  void aplicarFiltro(String? filtro) {
    if (kDebugMode) {
      print('Aplicando filtro: $filtro');
      print('Marcadores totales antes del filtro: ${_reportMarkers.length}');
    }

    _selectedFilter = filtro;

    if (kDebugMode) {
      print('Marcadores después del filtro: ${filteredMarkers.length}');
      for (var marker in filteredMarkers) {
        print('Marcador filtrado: ${marker.title}');
      }
    }

    notifyListeners();
  }

  // OBTENER MARCADOR DINÁMICO - USA CATEGORÍAS CENTRALIZADAS
  osm.MarkerIcon _getMarkerIconForCategory(String categoria) {
    final category = _getCategoryForName(categoria);
    return osm.MarkerIcon(
      icon: Icon(
        category.getEffectiveMapIcon(),
        color: category.color ?? Colors.white,
        size: category.getEffectiveIconSize(),
      ),
    );
  }

  // OBTENER CATEGORÍA POR NOMBRE - CON CACHE OPTIMIZADO
  ReportCategory _getCategoryForName(String categoria) {
    final lowerCategoria = categoria.toLowerCase().trim();

    // Primero buscar en cache
    if (_categoryCache.containsKey(lowerCategoria)) {
      return _categoryCache[lowerCategoria]!;
    }

    // Si no encuentra, usar el método de ReportCategories
    final category = ReportCategories.getCategoryByName(categoria);

    // Agregar al cache para futuras búsquedas
    _categoryCache[lowerCategoria] = category;

    return category;
  }

  // OBTENER COLOR DE CATEGORÍA - DINÁMICO
  Color getCategoryColor(String categoria) {
    final category = _getCategoryForName(categoria);
    return category.getEffectiveMarkerColor();
  }

  // ESTADÍSTICAS DINÁMICAS POR CATEGORÍA
  Map<String, int> obtenerEstadisticasPorCategoria() {
    final categories = ReportCategories.getActiveCategories();
    final stats = <String, int>{};

    // Inicializar todas las categorías con 0
    for (final category in categories) {
      stats[category.name] = 0;
    }
    stats['Otros'] = 0; // Para categorías no reconocidas

    // Contar reportes por categoría
    for (final reporte in _rawReportes) {
      final categoria = reporte['categoria']?.toString() ?? '';
      final categoryMatch = _getCategoryForName(categoria);

      if (categories.contains(categoryMatch)) {
        stats[categoryMatch.name] = (stats[categoryMatch.name] ?? 0) + 1;
      } else {
        stats['Otros'] = (stats['Otros'] ?? 0) + 1;
      }
    }

    return stats;
  }

  // ESTADÍSTICAS POR ESTADO - MEJORADAS
  Map<String, int> obtenerEstadisticasPorEstado() {
    final stats = <String, int>{
      'pendiente': 0,
      'en revision': 0,
      'asignado': 0,
      'en proceso': 0,
      'resuelto': 0,
    };

    for (final reporte in _rawReportes) {
      final estado = reporte['estado']?.toString().toLowerCase() ?? 'pendiente';

      // Mapeo más inteligente de estados
      if (_isEstadoPendiente(estado)) {
        stats['pendiente'] = (stats['pendiente'] ?? 0) + 1;
      } else if (_isEstadoRevision(estado)) {
        stats['en revision'] = (stats['en revision'] ?? 0) + 1;
      } else if (_isEstadoAsignado(estado)) {
        stats['asignado'] = (stats['asignado'] ?? 0) + 1;
      } else if (_isEstadoProceso(estado)) {
        stats['en proceso'] = (stats['en proceso'] ?? 0) + 1;
      } else if (_isEstadoResuelto(estado)) {
        stats['resuelto'] = (stats['resuelto'] ?? 0) + 1;
      } else {
        stats['pendiente'] = (stats['pendiente'] ?? 0) + 1;
      }
    }

    return stats;
  }

  // MÉTODOS AUXILIARES PARA MAPEO DE ESTADOS
  bool _isEstadoPendiente(String estado) {
    return estado.contains('pendiente') ||
        estado.contains('nuevo') ||
        estado.contains('creado');
  }

  bool _isEstadoRevision(String estado) {
    return estado.contains('revision') ||
        estado.contains('revisión') ||
        estado.contains('evaluacion') ||
        estado.contains('evaluación');
  }

  bool _isEstadoAsignado(String estado) {
    return estado.contains('asignado') ||
        estado.contains('designado');
  }

  bool _isEstadoProceso(String estado) {
    return estado.contains('proceso') ||
        estado.contains('progreso') ||
        estado.contains('trabajando') ||
        estado.contains('ejecutando');
  }

  bool _isEstadoResuelto(String estado) {
    return estado.contains('resuelto') ||
        estado.contains('completado') ||
        estado.contains('finalizado') ||
        estado.contains('terminado') ||
        estado.contains('cerrado');
  }

  // OBTENER COLOR PARA ESTADO - CONSISTENTE
  Color getEstadoColor(String estado) {
    switch (estado.toLowerCase()) {
      case 'pendiente':
        return Colors.grey.shade600;
      case 'en revision':
        return Colors.blue.shade600;
      case 'asignado':
        return Colors.orange.shade600;
      case 'en proceso':
        return Colors.amber.shade700;
      case 'resuelto':
        return Colors.green.shade700;
      default:
        return kSecondaryColor;
    }
  }

  // BUSCAR REPORTES CERCANOS - SIN CAMBIOS
  List<Map<String, dynamic>> obtenerReportesCercanos(
      double latitud,
      double longitud,
      double radioKm
      ) {
    return _rawReportes.where((reporte) {
      final reporteLat = (reporte['latitud'] as num?)?.toDouble();
      final reporteLon = (reporte['longitud'] as num?)?.toDouble();

      if (reporteLat == null || reporteLon == null) return false;

      final distancia = _calcularDistancia(
          latitud, longitud,
          reporteLat, reporteLon
      );

      return distancia <= radioKm;
    }).toList();
  }

  // MÉTODOS DE UTILIDAD - SIN CAMBIOS
  double _calcularDistancia(double lat1, double lon1, double lat2, double lon2) {
    const double radioTierra = 6371;

    final double dLat = _gradosARadianes(lat2 - lat1);
    final double dLon = _gradosARadianes(lon2 - lon1);

    final double lat1Rad = _gradosARadianes(lat1);
    final double lat2Rad = _gradosARadianes(lat2);

    final double a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
            math.cos(lat1Rad) * math.cos(lat2Rad) *
                math.sin(dLon / 2) * math.sin(dLon / 2);

    final double c = 2 * math.asin(math.sqrt(a));

    return radioTierra * c;
  }

  double _gradosARadianes(double grados) {
    return grados * (math.pi / 180);
  }

  // NUEVOS MÉTODOS ÚTILES

  // Obtener estadísticas completas
  Map<String, dynamic> obtenerEstadisticasCompletas() {
    return {
      'categorias': obtenerEstadisticasPorCategoria(),
      'estados': obtenerEstadisticasPorEstado(),
      'total_reportes': _rawReportes.length,
      'total_marcadores': _reportMarkers.length,
      'categorias_activas': ReportCategories.getActiveCategories().length,
    };
  }

  // Validar consistencia de datos
  bool validarConsistenciaDatos() {
    final categorias = ReportCategories.getCategoryNames();
    int reportesInconsistentes = 0;

    for (final reporte in _rawReportes) {
      final categoria = reporte['categoria']?.toString() ?? '';
      if (categoria.isNotEmpty && !categorias.contains(categoria)) {
        reportesInconsistentes++;
        if (kDebugMode) {
          print('Categoría inconsistente encontrada: $categoria');
        }
      }
    }

    if (kDebugMode) {
      print('Reportes con categorías inconsistentes: $reportesInconsistentes');
    }

    return reportesInconsistentes == 0;
  }

  // MÉTODOS DE LIMPIEZA Y RECARGA - SIN CAMBIOS
  void limpiar() {
    _reportMarkers.clear();
    _rawReportes.clear();
    _selectedFilter = null;
    _error = null;
    _isLoading = false;
    notifyListeners();
  }

  Future<void> recargar() async {
    await cargarUbicacionesReportes();
  }

  // MÉTODO PARA REFRESCAR CACHE (útil si las categorías cambian dinámicamente)
  void refrescarCacheCategories() {
    _initializeCategoryCache();
    notifyListeners();
  }
}