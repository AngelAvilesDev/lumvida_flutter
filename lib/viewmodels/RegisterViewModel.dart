import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/GoogleSignInService.dart';

class RegisterViewModel extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Estados
  bool _isLoading = false;
  bool _isProcessingGoogle = false;
  String? _errorMessage;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  // Getters
  bool get isLoading => _isLoading;
  bool get isProcessingGoogle => _isProcessingGoogle;
  String? get errorMessage => _errorMessage;
  bool get obscurePassword => _obscurePassword;
  bool get obscureConfirmPassword => _obscureConfirmPassword;

  // Alternar visibilidad de contraseña
  void togglePasswordVisibility() {
    _obscurePassword = !_obscurePassword;
    notifyListeners();
  }

  void toggleConfirmPasswordVisibility() {
    _obscureConfirmPassword = !_obscureConfirmPassword;
    notifyListeners();
  }

  // Registrar nuevo usuario con email y contraseña
  Future<bool> registerWithEmailAndPassword({
    required String email,
    required String password,
    required String name,
    required String phone,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null) {
        // Crear el perfil de usuario en Firestore
        await _firestore.collection("usuarios").doc(userCredential.user!.uid).set({
          "uid": userCredential.user!.uid,
          "email": email,
          "nombre": name,
          "telefono": phone,
          "provider": "EMAIL",
          "createdAt": Timestamp.now().millisecondsSinceEpoch
        });

        // Actualizar el perfil de Firebase Auth
        await userCredential.user!.updateDisplayName(name);

        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _isLoading = false;
        _errorMessage = "No se pudo crear el usuario";
        notifyListeners();
        return false;
      }
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

  // Registrar con Google
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

  // Validaciones
  String? validateName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Por favor ingrese su nombre';
    }
    if (value.length < 2) {
      return 'El nombre debe tener al menos 2 caracteres';
    }
    return null;
  }

  String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Por favor ingrese su correo electrónico';
    }
    if (!RegExp(r'^[\w-.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
      return 'Ingrese un correo electrónico válido';
    }
    return null;
  }

  String? validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Por favor ingrese su teléfono';
    }
    if (value.length != 10) {
      return 'El teléfono debe tener exactamente 10 dígitos';
    }
    return null;
  }

  String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Por favor ingrese una contraseña';
    }
    if (value.length < 6) {
      return 'La contraseña debe tener al menos 6 caracteres';
    }
    return null;
  }

  String? validateConfirmPassword(String? value, String password) {
    if (value == null || value.isEmpty) {
      return 'Por favor confirme su contraseña';
    }
    if (value != password) {
      return 'Las contraseñas no coinciden';
    }
    return null;
  }

  // Formatear teléfono (limitar a 10 dígitos)
  String formatPhone(String value) {
    if (value.length > 10) {
      return value.substring(0, 10);
    }
    return value;
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
    _obscureConfirmPassword = true;
    notifyListeners();
  }

  // Obtener mensaje de error en español
  String _getMessageFromErrorCode(String errorCode) {
    switch (errorCode) {
      case "invalid-email":
        return "El correo electrónico no es válido";
      case "user-disabled":
        return "Esta cuenta de usuario ha sido deshabilitada";
      case "email-already-in-use":
        return "Ya existe una cuenta con este correo electrónico";
      case "operation-not-allowed":
        return "Operación no permitida";
      case "weak-password":
        return "La contraseña es demasiado débil";
      case "too-many-requests":
        return "Demasiados intentos fallidos. Inténtalo más tarde";
      case "network-request-failed":
        return "Error de conexión. Verifica tu internet";
      default:
        return "Ha ocurrido un error. Inténtalo de nuevo";
    }
  }
}