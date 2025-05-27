import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/GoogleSignInService.dart';

class LoginViewModel extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Estados
  bool _isLoading = false;
  bool _isProcessingGoogle = false;
  String? _errorMessage;
  bool _obscurePassword = true;

  // Getters
  bool get isLoading => _isLoading;
  bool get isProcessingGoogle => _isProcessingGoogle;
  String? get errorMessage => _errorMessage;
  bool get obscurePassword => _obscurePassword;

  // Alternar visibilidad de contraseña
  void togglePasswordVisibility() {
    _obscurePassword = !_obscurePassword;
    notifyListeners();
  }

  // Iniciar sesión con email y contraseña
  Future<bool> signInWithEmailAndPassword(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      _isLoading = false;
      notifyListeners();

      return userCredential.user != null;
    } on FirebaseAuthException catch (e) {
      _isLoading = false;
      _errorMessage = _getMessageFromErrorCode(e.code);
      notifyListeners();
      return false;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Error inesperado: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  // Iniciar sesión con Google
  Future<bool> signInWithGoogle() async {
    _isProcessingGoogle = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final User? user = await GoogleSignInService.signInWithGoogle();

      _isProcessingGoogle = false;
      notifyListeners();

      return user != null;
    } catch (e) {
      if (kDebugMode) {
        print("Error en signInWithGoogle: $e");
      }
      _isProcessingGoogle = false;
      _errorMessage = "Error técnico al iniciar sesión: ${e.toString()}";
      notifyListeners();
      return false;
    }
  }

  // Restablecer contraseña
  Future<bool> resetPassword(String email) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _auth.sendPasswordResetEmail(email: email);
      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _isLoading = false;
      _errorMessage = _getMessageFromErrorCode(e.code);
      notifyListeners();
      return false;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Error inesperado: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  // Validar email
  String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Por favor ingrese su correo electrónico';
    }
    if (!RegExp(r'^[\w-.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
      return 'Ingrese un correo electrónico válido';
    }
    return null;
  }

  // Validar contraseña
  String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Por favor ingrese su contraseña';
    }
    return null;
  }

  // Limpiar errores
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // Limpiar estados
  void clear() {
    _isLoading = false;
    _isProcessingGoogle = false;
    _errorMessage = null;
    _obscurePassword = true;
    notifyListeners();
  }

  // Obtener mensaje de error en español
  String _getMessageFromErrorCode(String errorCode) {
    switch (errorCode) {
      case "invalid-email":
        return "El correo electrónico no es válido";
      case "user-disabled":
        return "Esta cuenta de usuario ha sido deshabilitada";
      case "user-not-found":
        return "No existe un usuario con este correo electrónico";
      case "wrong-password":
        return "La contraseña es incorrecta";
      case "invalid-credential":
        return "Las credenciales no son válidas";
      case "too-many-requests":
        return "Demasiados intentos fallidos. Inténtalo más tarde";
      case "network-request-failed":
        return "Error de conexión. Verifica tu internet";
      case "operation-not-allowed":
        return "Operación no permitida";
      default:
        return "Ha ocurrido un error. Inténtalo de nuevo";
    }
  }
}