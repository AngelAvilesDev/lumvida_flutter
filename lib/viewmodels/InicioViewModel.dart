import 'package:flutter/foundation.dart';

class InicioViewModel extends ChangeNotifier {
  // Estados básicos
  bool _isLoading = false;
  String? _error;

  // Getters
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Obtener saludo personalizado
  String obtenerSaludo() {
    final hora = DateTime.now().hour;
    if (hora < 12) {
      return 'Buenos días';
    } else if (hora < 18) {
      return 'Buenas tardes';
    } else {
      return 'Buenas noches';
    }
  }

  // Limpiar datos
  void limpiar() {
    _error = null;
    _isLoading = false;
    notifyListeners();
  }
}