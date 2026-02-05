import 'dart:math' as math;
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../components/GoogleMapComponent.dart';
import '../utils/report_categories.dart';

class MapViewModel extends ChangeNotifier {
  // Estados
  bool _isLoading = false;
  String? _error;
  List<MarkerData> _reportMarkers = [];
  String? _selectedFilter;
  final List<Map<String, dynamic>> _rawReportes = [];

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

  // MARCADORES FILTRADOS - FUNCIONA PERFECTAMENTE CON GOOGLE MAPS
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

  // CARGAR UBICACIONES - CON CACHÉ LOCAL
  Future<void> cargarUbicacionesReportes({bool forceRefresh = false}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // 1. Intentar cargar desde caché primero (si no es forzado)
      if (!forceRefresh) {
        final cachedReports = await _loadReportsFromCache();
        if (cachedReports.isNotEmpty) {
          if (kDebugMode) print('📦 Cargados ${cachedReports.length} reportes desde caché local');
          _procesarReportes(cachedReports, fromCache: true);
          
          // Ya mostramos datos, quitamos loading
          _isLoading = false;
          notifyListeners();
          
          // 2. Verificar en segundo plano si hay nuevos
          _checkForUpdatesBackground();
          return;
        }
      }

      // Si no hay caché o es forzado, descargar normal
      await _fetchAndSaveReports();
      
    } catch (e) {
      if (kDebugMode) print('Error cargando ubicaciones: $e');
      _isLoading = false;
      _error = 'Error al cargar ubicaciones: $e';
      notifyListeners();
    }
  }

  // Verificar actualizaciones en background (sin mostrar loading)
  Future<void> _checkForUpdatesBackground() async {
    try {
      // Obtener conteo o timestamp ligero para comparar
      // Por simplicidad y ahorro de lectura, podemos verificar el conteo total
      final aggregateQuery = await FirebaseFirestore.instance
          .collection('reportes')
          .count()
          .get();
      
      final serverCount = aggregateQuery.count ?? 0;
      final localCount = _rawReportes.length;

      if (serverCount != localCount) {
        if (kDebugMode) print('🔄 Detectados cambios en servidor ($serverCount vs $localCount local). Actualizando...');
        await _fetchAndSaveReports(isBackgroundUpdate: true);
      } else {
        if (kDebugMode) print('✅ El caché está actualizado.');
      }
    } catch (e) {
      if (kDebugMode) print('Error verificando actualizaciones: $e');
    }
  }

  // Descargar y guardar
  // Helper para sanitizar datos antes de guardar en caché (recursivo)
  dynamic _sanitizeDataForCache(dynamic data) {
    if (data is Timestamp) {
      return data.millisecondsSinceEpoch;
    } else if (data is GeoPoint) {
      return {'latitude': data.latitude, 'longitude': data.longitude};
    } else if (data is Map) {
      final Map<String, dynamic> cleanMap = {};
      data.forEach((key, value) {
        if (key is String) {
          cleanMap[key] = _sanitizeDataForCache(value);
        }
      });
      return cleanMap;
    } else if (data is List) {
      return data.map((item) => _sanitizeDataForCache(item)).toList();
    }
    return data;
  }

  Future<void> _fetchAndSaveReports({bool isBackgroundUpdate = false}) async {
    try {
      if (!isBackgroundUpdate) {
        _isLoading = true;
        notifyListeners();
      }

      final reportesSnapshot = await FirebaseFirestore.instance
          .collection('reportes')
          .get();

      if (kDebugMode) print('🌐 Descargados ${reportesSnapshot.docs.length} reportes de Firebase');

      final List<Map<String, dynamic>> fetchedData = [];
      
      for (var doc in reportesSnapshot.docs) {
        final data = doc.data();
        
        // Sanitizar datos recursivamente para asegurar que no queden Timestamps
        final sanitizedData = _sanitizeDataForCache(data);

        fetchedData.add({
          'id': doc.id,
          ...(sanitizedData as Map<String, dynamic>),
        });
      }

      // Procesar en memoria
      _procesarReportes(fetchedData);
      
      // Guardar en caché
      await _saveReportsToCache(fetchedData);

      _isLoading = false;
      notifyListeners();
      
      if (isBackgroundUpdate) {
         // Notificar discretamente si es necesario, o el notifyListeners ya lo hizo
      }

    } catch (e) {
      if (!isBackgroundUpdate) throw e; // Solo lanzar si es foreground
    }
  }

  // Procesar datos crudos a marcadores
  void _procesarReportes(List<Map<String, dynamic>> rawData, {bool fromCache = false}) {
    final markers = <MarkerData>[];
    _rawReportes.clear();
    
    // Si viene de caché, necesitamos reconstruir Timestamp objects si la app los usa
    // Pero para marcadores solo necesitamos coordenadas y strings
    
    for (var data in rawData) {
      // Restaurar Timestamps si es necesario para detalles del reporte
      // Esto es opcional dependiendo de cómo se usen en el modal
      final processedData = Map<String, dynamic>.from(data);
      if (fromCache) {
          if (processedData['fecha_millis'] != null) {
              processedData['fecha'] = Timestamp.fromMillisecondsSinceEpoch(processedData['fecha_millis']);
          }
      }
        
      _rawReportes.add(processedData);

      // Obtener coordenadas
      double? latitud;
      double? longitud;

      try {
        if (data['latitud'] != null && data['longitud'] != null) {
          latitud = double.tryParse(data['latitud'].toString());
          longitud = double.tryParse(data['longitud'].toString());
        } else if (data['ubicacion'] != null &&
            data['ubicacion'] is Map &&
            data['ubicacion']['latitud'] != null &&
            data['ubicacion']['longitud'] != null) {
          latitud = double.tryParse(data['ubicacion']['latitud'].toString());
          longitud = double.tryParse(data['ubicacion']['longitud'].toString());
        }
      } catch (e) {
        if (kDebugMode) print('Error parsing coordinates for report ${data['id']}: $e');
        continue; // Skip this report
      }

      if (latitud != null && longitud != null) {
        final categoria = data['categoria']?.toString() ?? '';
        final estado = data['estado']?.toString() ?? 'pendiente';
        
        // Optimización: No regenerar iconos si no cambiaron (complicado de checar, mejor generar)
        final markerIcon = _getMarkerIconForCategory(categoria, estado);

        markers.add(
          MarkerData(
            position: LatLng(latitud, longitud),
            icon: markerIcon,
            title: '${data['categoria'] ?? 'Sin categoría'} - ${data['folio'] ?? 'Sin folio'}',
            reportData: processedData,
          ),
        );
      }
    }

    _reportMarkers = markers;
  }

  // ---- MANEJO DE ARCHIVOS LOCALES ----
  
  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  Future<File> get _localFile async {
    final path = await _localPath;
    return File('$path/reportes_cache.json');
  }

  Future<List<Map<String, dynamic>>> _loadReportsFromCache() async {
    try {
      final file = await _localFile;
      if (await file.exists()) {
        final contents = await file.readAsString();
        final List<dynamic> jsonList = jsonDecode(contents);
        return jsonList.cast<Map<String, dynamic>>();
      }
    } catch (e) {
      if (kDebugMode) print('Error leyendo caché: $e');
    }
    return [];
  }

  Future<void> _saveReportsToCache(List<Map<String, dynamic>> reports) async {
    try {
      final file = await _localFile;
      // Convertir timestamps o objetos complejos si quedan
      final jsonString = jsonEncode(reports); // reports ya debería estar limpio
      await file.writeAsString(jsonString);
      if (kDebugMode) print('💾 Caché guardado exitosamente');
    } catch (e) {
      if (kDebugMode) print('Error guardando caché: $e');
    }
  }


  // APLICAR FILTRO - OPTIMIZADO PARA GOOGLE MAPS
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

  // OBTENER ICONO DINÁMICO - ACTUALIZADO PARA INCLUIR COLOR POR ESTADO
  Icon _getMarkerIconForCategory(String categoria, String estado) {
    final category = _getCategoryForName(categoria);
    // Usar color basado en estado en lugar de categoría
    final estadoColor = _getColorPorEstado(estado);

    return Icon(
      category.getEffectiveMapIcon(),
      color: estadoColor,
      size: category.getEffectiveIconSize(),
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

  // OBTENER COLOR POR ESTADO - CONSISTENTE CON MisReportesScreen
  Color _getColorPorEstado(String estado) {
    switch (_normalizeEstado(estado)) {
      case 'pendiente':
        return Colors.grey.shade600; // Gris para Pendiente
      case 'en revisión':
        return Colors.orange.shade600; // Naranja para En Revisión
      case 'asignado':
        return Colors.blue.shade600; // Azul para Asignado
      case 'en proceso':
        return Colors.yellow.shade700; // Amarillo para En Proceso
      case 'resuelto':
        return Colors.green.shade600; // Verde para Resuelto
      default:
        return Colors.grey.shade600; // Gris por defecto
    }
  }

  // NORMALIZAR ESTADO PARA COMPARACIÓN
  String _normalizeEstado(String estado) {
    switch (estado.toLowerCase().trim()) {
      case 'pendiente':
      case 'nuevo':
        return 'pendiente';
      case 'en revision':
      case 'en revisión':
      case 'revision':
        return 'en revisión';
      case 'asignado':
        return 'asignado';
      case 'en proceso':
      case 'proceso':
        return 'en proceso';
      case 'resuelto':
      case 'completado':
      case 'terminado':
        return 'resuelto';
      default:
        return 'pendiente';
    }
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

  // BUSCAR REPORTES CERCANOS - ADAPTADO PARA LATLNG
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

  // NUEVO: Obtener bounds para centrar mapa en todos los reportes
  LatLngBounds? obtenerBoundsDeReportes() {
    if (_reportMarkers.isEmpty) return null;

    double minLat = _reportMarkers.first.position.latitude;
    double maxLat = _reportMarkers.first.position.latitude;
    double minLng = _reportMarkers.first.position.longitude;
    double maxLng = _reportMarkers.first.position.longitude;

    for (final marker in _reportMarkers) {
      minLat = math.min(minLat, marker.position.latitude);
      maxLat = math.max(maxLat, marker.position.latitude);
      minLng = math.min(minLng, marker.position.longitude);
      maxLng = math.max(maxLng, marker.position.longitude);
    }

    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  // NUEVO: Obtener bounds para marcadores filtrados
  LatLngBounds? obtenerBoundsFiltrados() {
    final markers = filteredMarkers;
    if (markers.isEmpty) return null;

    double minLat = markers.first.position.latitude;
    double maxLat = markers.first.position.latitude;
    double minLng = markers.first.position.longitude;
    double maxLng = markers.first.position.longitude;

    for (final marker in markers) {
      minLat = math.min(minLat, marker.position.latitude);
      maxLat = math.max(maxLat, marker.position.latitude);
      minLng = math.min(minLng, marker.position.longitude);
      maxLng = math.max(maxLng, marker.position.longitude);
    }

    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
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