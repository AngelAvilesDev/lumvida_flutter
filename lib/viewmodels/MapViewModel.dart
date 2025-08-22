import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart' as osm;
import 'package:flutter/material.dart';
import '../components/OSMMapComponent.dart';
import '../utils/constants.dart'; // Importar constants

class MapViewModel extends ChangeNotifier {
  // Estados
  bool _isLoading = false;
  String? _error;
  List<MarkerData> _reportMarkers = [];
  String? _selectedFilter;
  List<Map<String, dynamic>> _rawReportes = [];

  // Getters
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<MarkerData> get reportMarkers => _reportMarkers;
  String? get selectedFilter => _selectedFilter;
  List<Map<String, dynamic>> get rawReportes => _rawReportes;

  // Marcadores filtrados - LÓGICA CORREGIDA
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

      // Lógica de filtrado más específica
      switch (filtro) {
        case 'bacheo':
          return categoriaOriginal.contains('bacheo');
        case 'alumbrado':
          return categoriaOriginal.contains('alumbrado');
        case 'basura':
          return categoriaOriginal.contains('basura');
        case 'drenajes':
          return categoriaOriginal.contains('drenajes') || categoriaOriginal.contains('drenaje');
        default:
          return categoriaOriginal.contains(filtro);
      }
    }).toList();
  }

  // Cargar ubicaciones de reportes
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
          // Definir icono según categoría
          final categoria = data['categoria']?.toString().toLowerCase() ?? '';
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

  // Aplicar filtro - CON DEBUG MEJORADO
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

  // Obtener MarkerIcon para categoría - USANDO COLORS CONSISTENTES
  osm.MarkerIcon _getMarkerIconForCategory(String categoria) {
    final icon = _getIconForCategory(categoria);
    return osm.MarkerIcon(icon: icon);
  }

  // Obtener icono para categoría - ICONOS MEJORADOS CON CONSTANTS
  Icon _getIconForCategory(String categoria) {
    const double iconSize = 40.0;

    switch (categoria.toLowerCase().trim()) {
      case 'bacheo':
        return Icon(
          Icons.car_crash,
          color: Colors.orange.shade700,
          size: iconSize,
        );
      case 'alumbrado público':
      case 'alumbrado':
        return Icon(
          Icons.lightbulb,
          color: Colors.amber.shade600,
          size: iconSize,
        );
      case 'basura acumulada':
      case 'basura':
        return Icon(
          Icons.delete,
          color: Colors.brown.shade700,
          size: iconSize,
        );
      case 'drenajes obstruidos':
      case 'drenajes':
      case 'drenaje':
        return Icon(
          Icons.water_drop,
          color: Colors.blue.shade700,
          size: iconSize,
        );
      default:
        return const Icon(
          Icons.report_problem,
          color: kPrimaryColor, // Usando el color primario de constants
          size: iconSize,
        );
    }
  }

  // Método para obtener color de categoría (útil para gráficas y UI)
  Color getCategoryColor(String categoria) {
    switch (categoria.toLowerCase().trim()) {
      case 'bacheo':
        return Colors.orange.shade700;
      case 'alumbrado público':
      case 'alumbrado':
        return Colors.amber.shade600;
      case 'basura acumulada':
      case 'basura':
        return Colors.brown.shade700;
      case 'drenajes obstruidos':
      case 'drenajes':
      case 'drenaje':
        return Colors.blue.shade700;
      default:
        return kPrimaryColor; // Color primario por defecto
    }
  }

  // Obtener estadísticas por categoría
  Map<String, int> obtenerEstadisticasPorCategoria() {
    final stats = <String, int>{
      'Bacheo': 0,
      'Alumbrado Público': 0,
      'Basura Acumulada': 0,
      'Drenajes Obstruidos': 0,
      'Otros': 0,
    };

    for (final reporte in _rawReportes) {
      final categoria = reporte['categoria']?.toString() ?? 'Otros';
      if (stats.containsKey(categoria)) {
        stats[categoria] = (stats[categoria] ?? 0) + 1;
      } else {
        stats['Otros'] = (stats['Otros'] ?? 0) + 1;
      }
    }

    return stats;
  }

  // Obtener reportes por estado - ACTUALIZADO CON NUEVOS ESTADOS
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
      if (stats.containsKey(estado)) {
        stats[estado] = (stats[estado] ?? 0) + 1;
      } else {
        // Para estados que no coinciden exactamente, mapear a los más cercanos
        if (estado.contains('pendiente') || estado.contains('nuevo')) {
          stats['pendiente'] = (stats['pendiente'] ?? 0) + 1;
        } else if (estado.contains('revision') || estado.contains('revisión')) {
          stats['en revision'] = (stats['en revision'] ?? 0) + 1;
        } else if (estado.contains('asignado')) {
          stats['asignado'] = (stats['asignado'] ?? 0) + 1;
        } else if (estado.contains('proceso')) {
          stats['en proceso'] = (stats['en proceso'] ?? 0) + 1;
        } else if (estado.contains('resuelto') || estado.contains('completado')) {
          stats['resuelto'] = (stats['resuelto'] ?? 0) + 1;
        } else {
          // Estados desconocidos van a pendiente por defecto
          stats['pendiente'] = (stats['pendiente'] ?? 0) + 1;
        }
      }
    }

    return stats;
  }

  // Obtener color para estado (usando constants)
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
        return kSecondaryColor; // Color secundario de constants
    }
  }

  // Buscar reportes cerca de una ubicación
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

  // Calcular distancia entre dos puntos (fórmula de Haversine simplificada)
  double _calcularDistancia(double lat1, double lon1, double lat2, double lon2) {
    const double radioTierra = 6371; // Radio de la Tierra en kilómetros

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

  // Limpiar datos
  void limpiar() {
    _reportMarkers.clear();
    _rawReportes.clear();
    _selectedFilter = null;
    _error = null;
    _isLoading = false;
    notifyListeners();
  }

  // Recargar datos
  Future<void> recargar() async {
    await cargarUbicacionesReportes();
  }
}