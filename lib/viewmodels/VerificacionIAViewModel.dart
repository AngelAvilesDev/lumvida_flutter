import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart' as osm;
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
  osm.GeoPoint? _ubicacion;
  String _direccion = '';
  List<File> _imagenes = [];

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
  osm.GeoPoint? get ubicacion => _ubicacion;
  String get direccion => _direccion;
  List<File> get imagenes => _imagenes;

  // Inicializar con datos del reporte
  void inicializarDatos({
    required String categoria,
    required String opcionSeleccionada,
    required String comentario,
    required osm.GeoPoint ubicacion,
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

    notifyListeners();
  }

  // Analizar imágenes con IA
  Future<void> analizarImagenes() async {
    _isAnalyzing = true;
    _analysisFailed = false;
    _canSubmitReport = false;
    notifyListeners();

    try {
      // Validar que hay imágenes
      if (_imagenes.isEmpty) {
        _finalizarAnalisisConError(
            'No se encontraron imágenes para analizar. Por favor adjunta imágenes del problema para poder verificar la categoría.'
        );
        return;
      }

      // Analizar la primera imagen con OpenAI
      final Map<String, dynamic> imageAnalysis = await OpenAIService.analyzeImage(
          _imagenes[0],
          _categoria,
          "Analiza esta imagen y determina si muestra un problema de '$_categoria' como se ha reportado. "
              "Responde ÚNICAMENTE si la imagen coincide EXACTAMENTE con la categoría reportada. "
              "Si coincide, confirma que sí. Si NO coincide, indica qué tipo de problema se muestra realmente en la imagen, "
              "eligiendo ÚNICAMENTE entre: 'Bacheo', 'Alumbrado Público', 'Basura Acumulada' o 'Drenajes Obstruidos'. "
              "Si la imagen no muestra ninguno de estos problemas urbanos, indica que no es un problema válido para reportar."
      );

      // Verificar metadatos de ubicación
      Map<String, dynamic> locationVerification = {'isLocationVerified': false, 'message': ''};
      if (_ubicacion != null) {
        locationVerification = await OpenAIService.verifyLocationMetadata(
          _imagenes[0],
          _ubicacion!.latitude,
          _ubicacion!.longitude,
        );
      }

      // Actualizar estados con los resultados
      _isAnalyzing = false;
      _isCategoryMatch = imageAnalysis['isMatch'] ?? false;
      _detectedCategory = imageAnalysis['detectedCategory'] ?? _categoria;
      _analysisMessage = imageAnalysis['message'] ?? 'No se pudo analizar la imagen';
      _isLocationVerified = locationVerification['isLocationVerified'] ?? false;
      _locationVerificationMessage = locationVerification['message'] ?? 'No se pudieron verificar los metadatos de ubicación.';

      // LÓGICA CRÍTICA: Solo permitir envío si la categoría coincide EXACTAMENTE
      _canSubmitReport = _isCategoryMatch;

      notifyListeners();
    } catch (e) {
      _finalizarAnalisisConError('Error al analizar las imágenes: $e');
    }
  }

  // Finalizar análisis con error
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

  // Reintentar análisis
  Future<void> reintentarAnalisis() async {
    await analizarImagenes();
  }

  // Obtener resumen del análisis
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
    };
  }

  // Validar si se puede proceder
  bool puedeProcedera() {
    return !_isAnalyzing && !_analysisFailed && _canSubmitReport;
  }

  // Obtener mensaje de estado
  String obtenerMensajeEstado() {
    if (_isAnalyzing) {
      return 'Analizando imágenes con IA...';
    } else if (_analysisFailed) {
      return 'Error en el análisis. Inténtalo nuevamente.';
    } else if (!_isCategoryMatch) {
      return 'La imagen no coincide con la categoría reportada.';
    } else if (_canSubmitReport) {
      return 'Verificación completada. Puedes enviar el reporte.';
    } else {
      return 'Verificando reporte...';
    }
  }

  // Limpiar datos
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
    notifyListeners();
  }
}