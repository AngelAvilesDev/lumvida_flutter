import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart'; // CAMBIADO DE OSM
import '../services/OpenAIService.dart';

class VerificacionIAViewModel extends ChangeNotifier {
  // Estados del análisis
  bool _isAnalyzing = false;
  bool _isLocationVerified = false;
  bool _isCategoryMatch = false;
  String _detectedCategory = '';
  String _analysisMessage = '';
  String _locationVerificationMessage = '';
  bool _analysisFailed = false;
  bool _canSubmitReport = false;

  // Datos del reporte
  String _categoria = '';
  String _opcionSeleccionada = '';
  String _comentario = '';
  LatLng? _ubicacion; // CAMBIADO DE osm.GeoPoint
  String _direccion = '';
  List<File> _imagenes = [];
  List<String> _imagenesBase64 = [];

  // Getters
  bool get isAnalyzing => _isAnalyzing;
  bool get isLocationVerified => _isLocationVerified;
  bool get isCategoryMatch => _isCategoryMatch;
  String get detectedCategory => _detectedCategory;
  String get analysisMessage => _analysisMessage;
  String get locationVerificationMessage => _locationVerificationMessage;
  bool get analysisFailed => _analysisFailed;
  bool get canSubmitReport => _canSubmitReport;

  // Getters de datos del reporte
  String get categoria => _categoria;
  String get opcionSeleccionada => _opcionSeleccionada;
  String get comentario => _comentario;
  LatLng? get ubicacion => _ubicacion; // ACTUALIZADO
  String get direccion => _direccion;
  List<File> get imagenes => _imagenes;
  List<String> get imagenesBase64 => _imagenesBase64;

  // Inicializar con datos del reporte - ACTUALIZADO
  void inicializarDatos({
    required String categoria,
    required String opcionSeleccionada,
    required String comentario,
    required LatLng ubicacion, // CAMBIADO DE osm.GeoPoint
    required String direccion,
    required List<File> imagenes,
  }) {
    _categoria = categoria;
    _opcionSeleccionada = opcionSeleccionada;
    _comentario = comentario;
    _ubicacion = ubicacion;
    _direccion = direccion;
    _imagenes = List.from(imagenes);

    // Resetear estados de análisis
    _isAnalyzing = false;
    _isLocationVerified = false;
    _isCategoryMatch = false;
    _detectedCategory = categoria;
    _analysisMessage = '';
    _locationVerificationMessage = '';
    _analysisFailed = false;
    _canSubmitReport = false;
    _imagenesBase64.clear();

    notifyListeners();
  }

  // Inicializar con datos del reporte y Base64 - ACTUALIZADO
  void inicializarDatosConBase64({
    required String categoria,
    required String opcionSeleccionada,
    required String comentario,
    required LatLng ubicacion, // CAMBIADO DE osm.GeoPoint
    required String direccion,
    required List<File> imagenes,
    required List<String> imagenesBase64,
  }) {
    _categoria = categoria;
    _opcionSeleccionada = opcionSeleccionada;
    _comentario = comentario;
    _ubicacion = ubicacion;
    _direccion = direccion;
    _imagenes = List.from(imagenes);
    _imagenesBase64 = List.from(imagenesBase64);

    // Resetear estados de análisis
    _isAnalyzing = false;
    _isLocationVerified = false;
    _isCategoryMatch = false;
    _detectedCategory = categoria;
    _analysisMessage = '';
    _locationVerificationMessage = '';
    _analysisFailed = false;
    _canSubmitReport = false;

    notifyListeners();
  }

  // Analizar imágenes con IA - ACTUALIZADO PARA LATLNG
  Future<void> analizarImagenes() async {
    _isAnalyzing = true;
    _analysisFailed = false;
    _canSubmitReport = false;
    notifyListeners();

    try {
      // Validar que hay imágenes
      if (_imagenes.isEmpty && _imagenesBase64.isEmpty) {
        _finalizarAnalisisConError(
            'No se encontraron imágenes para analizar. Por favor adjunta imágenes del problema para poder verificar la categoría.'
        );
        return;
      }

      // Convertir imágenes a Base64 si no están ya convertidas
      if (_imagenesBase64.isEmpty && _imagenes.isNotEmpty) {
        await _convertirImagenesABase64();
      }

      // Validar que se pudieron convertir
      if (_imagenesBase64.isEmpty) {
        _finalizarAnalisisConError(
            'Error al procesar las imágenes. No se pudieron convertir para el análisis.'
        );
        return;
      }

      // Analizar la primera imagen Base64 con OpenAI
      final Map<String, dynamic> imageAnalysis = await OpenAIService.analyzeImageFromBase64(
          _imagenesBase64[0],
          _categoria,
          "Analiza esta imagen y determina si muestra un problema de '$_categoria' como se ha reportado. "
              "Responde ÚNICAMENTE si la imagen coincide EXACTAMENTE con la categoría reportada. "
              "Si coincide, confirma que sí. Si NO coincide, indica qué tipo de problema se muestra realmente en la imagen, "
              "eligiendo ÚNICAMENTE entre: 'Bacheo', 'Alumbrado Público', 'Basura Acumulada' o 'Drenajes Obstruidos'. "
              "Si la imagen no muestra ninguno de estos problemas urbanos, indica que no es un problema válido para reportar."
      );

      // Verificar metadatos de ubicación usando Base64 - ACTUALIZADO PARA LATLNG
      Map<String, dynamic> locationVerification = {'isLocationVerified': false, 'message': ''};
      if (_ubicacion != null && _imagenesBase64.isNotEmpty) {
        locationVerification = await OpenAIService.verifyLocationMetadataFromBase64(
          _imagenesBase64[0],
          _ubicacion!.latitude, // USANDO LatLng
          _ubicacion!.longitude, // USANDO LatLng
        );
      }

      // Actualizar estados con los resultados
      // Actualizar estados con los resultados
      _isAnalyzing = false;
      _detectedCategory = imageAnalysis['detectedCategory'] ?? _categoria;
      _analysisMessage = imageAnalysis['message'] ?? 'No se pudo analizar la imagen';
      _isLocationVerified = locationVerification['isLocationVerified'] ?? false;
      _locationVerificationMessage = locationVerification['message'] ?? 'No se pudieron verificar los metadatos de ubicación.';

      // LÓGICA DE FUZZY MATCH
      // Si la IA dice que no coincide, pero la categoría detectada es la misma (ignorando mayúsculas/tildes y espacios)
      bool stringMatch = _normalizeString(_detectedCategory) == _normalizeString(_categoria);
      
      _isCategoryMatch = (imageAnalysis['isMatch'] ?? false) || stringMatch;

      // LÓGICA CRÍTICA: Solo permitir envío si la categoría coincide EXACTAMENTE o por similitud de texto
      _canSubmitReport = _isCategoryMatch;

      notifyListeners();
    } catch (e) {
      _finalizarAnalisisConError('Error al analizar las imágenes: $e');
    }
  }

  String _normalizeString(String input) {
    return input.trim().toLowerCase()
        .replaceAll('á', 'a').replaceAll('é', 'e').replaceAll('í', 'i').replaceAll('ó', 'o').replaceAll('ú', 'u')
        .replaceAll('ñ', 'n');
  }

  // Convertir imágenes a Base64 - SIN CAMBIOS
  Future<void> _convertirImagenesABase64() async {
    try {
      _imagenesBase64.clear();

      for (final imagen in _imagenes) {
        if (kDebugMode) {
          print('Convirtiendo imagen a Base64 para análisis...');
        }

        final base64String = await OpenAIService.fileToBase64(imagen);

        if (base64String.isNotEmpty && OpenAIService.isValidBase64Image(base64String)) {
          _imagenesBase64.add(base64String);
        } else {
          if (kDebugMode) {
            print('Error: No se pudo convertir imagen a Base64 válido');
          }
        }
      }

      if (kDebugMode) {
        print('Convertidas ${_imagenesBase64.length} imágenes a Base64');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error convirtiendo imágenes a Base64: $e');
      }
    }
  }

  // Finalizar análisis con error - SIN CAMBIOS
  void _finalizarAnalisisConError(String mensaje) {
    _isAnalyzing = false;
    _analysisFailed = true;
    _analysisMessage = mensaje;
    _detectedCategory = _categoria;
    _isCategoryMatch = false;
    _isLocationVerified = false;
    _locationVerificationMessage = 'No se pudieron verificar los metadatos de ubicación.';
    _canSubmitReport = false;
    notifyListeners();
  }

  // Reintentar análisis - SIN CAMBIOS
  Future<void> reintentarAnalisis() async {
    await analizarImagenes();
  }

  // Analizar múltiples imágenes - ACTUALIZADO PARA LATLNG
  Future<void> analizarMultiplesImagenes() async {
    _isAnalyzing = true;
    _analysisFailed = false;
    _canSubmitReport = false;
    notifyListeners();

    try {
      // Validar que hay imágenes
      if (_imagenesBase64.isEmpty && _imagenes.isNotEmpty) {
        await _convertirImagenesABase64();
      }

      if (_imagenesBase64.isEmpty) {
        _finalizarAnalisisConError(
            'No se encontraron imágenes para analizar.'
        );
        return;
      }

      // Analizar todas las imágenes
      final Map<String, dynamic> multiAnalysis = await OpenAIService.analyzeMultipleImagesFromBase64(
          _imagenesBase64,
          _categoria
      );

      // Verificar metadatos de ubicación - ACTUALIZADO PARA LATLNG
      Map<String, dynamic> locationVerification = {'isLocationVerified': false, 'message': ''};
      if (_ubicacion != null && _imagenesBase64.isNotEmpty) {
        locationVerification = await OpenAIService.verifyLocationMetadataFromBase64(
          _imagenesBase64[0],
          _ubicacion!.latitude, // USANDO LatLng
          _ubicacion!.longitude, // USANDO LatLng
        );
      }

      // Actualizar estados con los resultados
      _isAnalyzing = false;
      _isCategoryMatch = multiAnalysis['isMatch'] ?? false;
      _detectedCategory = multiAnalysis['detectedCategory'] ?? _categoria;
      _analysisMessage = multiAnalysis['message'] ?? 'No se pudo analizar las imágenes';
      _isLocationVerified = locationVerification['isLocationVerified'] ?? false;
      _locationVerificationMessage = locationVerification['message'] ?? 'No se pudieron verificar los metadatos de ubicación.';

      // Solo permitir envío si la mayoría de imágenes coinciden
      _canSubmitReport = _isCategoryMatch;

      notifyListeners();
    } catch (e) {
      _finalizarAnalisisConError('Error al analizar las imágenes: $e');
    }
  }

  // Obtener resumen del análisis - SIN CAMBIOS
  Map<String, dynamic> obtenerResumenAnalisis() {
    return {
      'categoria_solicitada': _categoria,
      'categoria_detectada': _detectedCategory,
      'coincide_categoria': _isCategoryMatch,
      'ubicacion_verificada': _isLocationVerified,
      'puede_enviar_reporte': _canSubmitReport,
      'mensaje_analisis': _analysisMessage,
      'mensaje_ubicacion': _locationVerificationMessage,
      'numero_imagenes': _imagenes.length,
      'numero_imagenes_base64': _imagenesBase64.length,
    };
  }

  // Validar si se puede proceder - SIN CAMBIOS
  bool puedeProcedera() {
    return !_isAnalyzing && !_analysisFailed && _canSubmitReport;
  }

  // Obtener mensaje de estado - SIN CAMBIOS
  String obtenerMensajeEstado() {
    if (_isAnalyzing) {
      return 'Lumi está revisando tu reporte...';
    } else if (_analysisFailed) {
      return 'Algo salió mal. Inténtalo nuevamente.';
    } else if (!_isCategoryMatch) {
      return 'La foto no parece coincidir con el reporte.';
    } else if (_canSubmitReport) {
      return 'Todo listo. Puedes enviar el reporte.';
    } else {
      return 'Verificando reporte...';
    }
  }

  // Obtener estadísticas de las imágenes Base64 - SIN CAMBIOS
  Map<String, dynamic> obtenerEstadisticasImagenes() {
    if (_imagenesBase64.isEmpty) {
      return {
        'total_imagenes': 0,
        'tamaño_total_kb': 0,
        'tamaño_promedio_kb': 0,
      };
    }

    int totalSize = 0;
    for (final imagen in _imagenesBase64) {
      totalSize += (imagen.length * 3 / 4).round();
    }

    return {
      'total_imagenes': _imagenesBase64.length,
      'tamaño_total_kb': (totalSize / 1024).toStringAsFixed(1),
      'tamaño_promedio_kb': (totalSize / _imagenesBase64.length / 1024).toStringAsFixed(1),
      'tamaño_total_mb': (totalSize / 1024 / 1024).toStringAsFixed(2),
    };
  }

  // Validar integridad de las imágenes Base64 - SIN CAMBIOS
  bool validarIntegridadImagenes() {
    if (_imagenesBase64.isEmpty) return false;

    for (final imagen in _imagenesBase64) {
      if (!OpenAIService.isValidBase64Image(imagen)) {
        return false;
      }
    }

    return true;
  }

  // Limpiar datos - SIN CAMBIOS
  void limpiar() {
    _isAnalyzing = false;
    _isLocationVerified = false;
    _isCategoryMatch = false;
    _detectedCategory = '';
    _analysisMessage = '';
    _locationVerificationMessage = '';
    _analysisFailed = false;
    _canSubmitReport = false;
    _categoria = '';
    _opcionSeleccionada = '';
    _comentario = '';
    _ubicacion = null;
    _direccion = '';
    _imagenes.clear();
    _imagenesBase64.clear();
    notifyListeners();
  }
}