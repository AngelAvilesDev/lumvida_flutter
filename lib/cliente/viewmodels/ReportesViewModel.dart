import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/ReporteService.dart';
import '../services/OpenAIService.dart';

class ReportesViewModel extends ChangeNotifier {
  final ReporteService _reporteService = ReporteService();

  // Estados
  bool _isSubmitting = false;
  bool _isAnalyzing = false;
  String? _errorMessage;
  String? _selectedOption;
  LatLng? _selectedLocation;
  String _addressText = "Selecciona una ubicación en el mapa";
  final List<File> _selectedPhotos = [];

  // Flag para controlar si el ViewModel ha sido disposed
  bool _disposed = false;

  // Getters
  bool get isSubmitting => _isSubmitting;
  bool get isAnalyzing => _isAnalyzing;
  String? get errorMessage => _errorMessage;
  String? get selectedOption => _selectedOption;
  LatLng? get selectedLocation => _selectedLocation;
  String get addressText => _addressText;
  List<File> get selectedPhotos => _selectedPhotos;

  // Setters con notificación
  void setSelectedOption(String? option) {
    if (_disposed) return;
    _selectedOption = option;
    notifyListeners();
  }

  void setSelectedLocation(LatLng location) {
    if (_disposed) return;
    _selectedLocation = location;

    // CAMBIAR: Mensaje discreto
    _addressText = 'Procesando ubicación...';
    notifyListeners();

    // Obtener la dirección real inmediatamente
    _obtenerDireccionInmediata(location);
  }

  // NUEVO MÉTODO: Obtener dirección inmediatamente cuando se selecciona ubicación
  Future<void> _obtenerDireccionInmediata(LatLng location) async {
    if (_disposed) return;

    try {
      final direccion = await _reporteService.obtenerDireccionFromLatLng(location);

      if (!_disposed && direccion.isNotEmpty && !direccion.contains('Error')) {
        _addressText = direccion;
        notifyListeners();
      } else {
        // Solo como último recurso mostrar coordenadas
        _addressText = 'Ubicación seleccionada (${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)})';
        notifyListeners();
      }
    } catch (e) {
      if (!_disposed) {
        _addressText = 'Error al obtener dirección';
        notifyListeners();
      }
    }
  }

  void updateAddressText(String address) {
    if (_disposed) return;
    _addressText = address;
    notifyListeners();
  }

  // Manejo de fotos
  void addPhoto(File photo) {
    if (_disposed) return;
    _selectedPhotos.add(photo);
    notifyListeners();
  }

  void updatePhoto(int index, File photo) {
    if (_disposed) return;
    if (index < _selectedPhotos.length) {
      _selectedPhotos[index] = photo;
    } else {
      _selectedPhotos.add(photo);
    }
    notifyListeners();
  }

  void removePhoto(int index) {
    if (_disposed) return;
    if (index < _selectedPhotos.length) {
      _selectedPhotos.removeAt(index);
      notifyListeners();
    }
  }

  // Validaciones
  bool validateForm(String comentario) {
    if (_disposed) return false;

    _errorMessage = null;

    if (_selectedOption == null) {
      _errorMessage = 'Por favor selecciona una opción';
      notifyListeners();
      return false;
    }

    if (_selectedLocation == null) {
      _errorMessage = 'Por favor selecciona una ubicación en el mapa';
      notifyListeners();
      return false;
    }

    if (_selectedPhotos.isEmpty) {
      _errorMessage = 'Se requiere al menos una imagen para verificación';
      notifyListeners();
      return false;
    }

    if (_selectedOption == 'Otro (especificar)' && comentario.trim().isEmpty) {
      _errorMessage = 'Por favor describe el problema específico';
      notifyListeners();
      return false;
    }

    return true;
  }

  // Análisis con IA
  Future<Map<String, dynamic>> analizarImagenesConIA(String categoria) async {
    if (_disposed) {
      return {
        'success': false,
        'message': 'ViewModel was disposed',
        'isMatch': false,
        'detectedCategory': categoria,
      };
    }

    if (_selectedPhotos.isEmpty) {
      return {
        'success': false,
        'message': 'No hay imágenes para analizar',
        'isMatch': false,
        'detectedCategory': categoria,
      };
    }

    _isAnalyzing = true;
    _errorMessage = null;
    if (!_disposed) notifyListeners();

    try {
      final resultado = await OpenAIService.analyzeImage(
        _selectedPhotos[0],
        categoria,
        "Analiza esta imagen y determina si muestra un problema de '$categoria' como se ha reportado.",
      );

      if (!_disposed) {
        _isAnalyzing = false;
        notifyListeners();
      }

      return resultado;
    } catch (e) {
      if (!_disposed) {
        _isAnalyzing = false;
        _errorMessage = 'Error al analizar imágenes: $e';
        notifyListeners();
      }

      return {
        'success': false,
        'message': 'Error al analizar imágenes: $e',
        'isMatch': false,
        'detectedCategory': categoria,
      };
    }
  }

  // Crear reporte - ACTUALIZADO PARA GOOGLE MAPS
  Future<Map<String, dynamic>> crearReporte({
    required String userId,
    required String categoria,
    required String descripcion,
    required String nombreCompleto,
    required String telefono,
    required bool isAnonymous,
  }) async {
    if (_disposed) {
      return {
        'success': false,
        'message': 'ViewModel was disposed',
      };
    }

    if (_selectedLocation == null) {
      return {
        'success': false,
        'message': 'Ubicación no seleccionada',
      };
    }

    _isSubmitting = true;
    _errorMessage = null;
    if (!_disposed) notifyListeners();

    try {
      // Obtener dirección real si es necesario
      String direccion = _addressText;
      if (direccion.contains('Lat:') || direccion.contains('Lon:') || direccion.contains('Obteniendo') || direccion.contains('Error')) {
        direccion = await _reporteService.obtenerDireccionFromLatLng(_selectedLocation!);
      }

      // Crear el reporte - USANDO EL MÉTODO ACTUALIZADO
      final reporteId = await _reporteService.crearReporteFromLatLng(
        userId: userId,
        categoria: categoria,
        descripcion: descripcion,
        direccion: direccion,
        ubicacion: _selectedLocation!,
        nombreCompleto: nombreCompleto,
        telefono: telefono,
        isAnonymous: isAnonymous,
        imagenes: _selectedPhotos,
      );

      if (reporteId != null) {
        // Obtener el reporte completo para extraer el folio
        final reporteCompleto = await _reporteService.getReporteById(reporteId);
        final folio = reporteCompleto?['folio'] ?? 'Sin folio';

        if (!_disposed) {
          _isSubmitting = false;
          notifyListeners();
        }

        return {
          'success': true,
          'reporteId': reporteId,
          'folio': folio,
          'message': 'Reporte creado exitosamente',
        };
      } else {
        if (!_disposed) {
          _isSubmitting = false;
          _errorMessage = 'Error al crear el reporte';
          notifyListeners();
        }

        return {
          'success': false,
          'message': 'Error al crear el reporte',
        };
      }
    } on Exception catch (e) {
      if (!_disposed) {
        _isSubmitting = false;

        // Manejar errores específicos
        String userFriendlyMessage;
        if (e.toString().contains('permission') || e.toString().contains('unauthorized')) {
          userFriendlyMessage = 'Error de permisos: No se pueden subir las imágenes. Contacta al administrador.';
        } else if (e.toString().contains('network') || e.toString().contains('connection')) {
          userFriendlyMessage = 'Error de conexión: Verifica tu conexión a internet e inténtalo de nuevo.';
        } else if (e.toString().contains('storage') || e.toString().contains('upload')) {
          userFriendlyMessage = 'Error al subir imágenes: Intenta con imágenes más pequeñas o menos imágenes.';
        } else {
          userFriendlyMessage = 'Error inesperado: ${e.toString()}';
        }

        _errorMessage = userFriendlyMessage;
        notifyListeners();
      }

      return {
        'success': false,
        'message': 'Error: ${e.toString()}',
        'originalError': e.toString(),
      };
    } catch (e) {
      if (!_disposed) {
        _isSubmitting = false;
        _errorMessage = 'Error: $e';
        notifyListeners();
      }

      return {
        'success': false,
        'message': 'Error: $e',
      };
    }
  }

  // Limpiar formulario
  void limpiarFormulario() {
    if (_disposed) return;

    _selectedOption = null;
    _selectedLocation = null;
    _addressText = "Selecciona una ubicación en el mapa";
    _selectedPhotos.clear();
    _errorMessage = null;
    _isSubmitting = false;
    _isAnalyzing = false;
    notifyListeners();
  }

  // Obtener dirección de coordenadas - ACTUALIZADO
  Future<void> obtenerDireccionDeUbicacion() async {
    if (_disposed || _selectedLocation == null) return;

    try {
      final direccion = await _reporteService.obtenerDireccionFromLatLng(_selectedLocation!);
      if (!_disposed && direccion.isNotEmpty && !direccion.contains('Error')) {
        _addressText = direccion;
        notifyListeners();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error al obtener dirección: $e');
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}