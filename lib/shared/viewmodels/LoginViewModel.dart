// viewmodels/LoginViewModel.dart
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/error_messages.dart';

class LoginViewModel extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  bool _isLoading = false;
  bool _isProcessingGoogle = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  // Getters
  bool get isLoading => _isLoading;
  bool get isProcessingGoogle => _isProcessingGoogle;
  bool get obscurePassword => _obscurePassword;
  String? get errorMessage => _errorMessage;

  // Setters privados
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setGoogleProcessing(bool value) {
    _isProcessingGoogle = value;
    notifyListeners();
  }

  void _setError(String? message) {
    _errorMessage = message;
    notifyListeners();
  }

  // Métodos públicos
  void togglePasswordVisibility() {
    _obscurePassword = !_obscurePassword;
    notifyListeners();
  }

  void clearError() {
    if (_errorMessage != null) {
      _setError(null);
    }
  }

  // Validadores usando AuthErrorMessages
  String? validateEmail(String? value) {
    return AuthErrorMessages.validateEmail(value);
  }

  String? validatePassword(String? value) {
    // Para login, usar validación más permisiva
    return AuthErrorMessages.validateLoginPassword(value);
  }

  // Método para iniciar sesión con email y contraseña
  Future<bool> signInWithEmailAndPassword(String email, String password) async {
    try {
      _setLoading(true);
      _setError(null);

      // Validar campos antes de enviar
      final emailError = validateEmail(email);
      if (emailError != null) {
        _setError(emailError);
        return false;
      }

      final passwordError = validatePassword(password);
      if (passwordError != null) {
        _setError(passwordError);
        return false;
      }

      // Intentar iniciar sesión
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null) {
        return true;
      } else {
        _setError(AuthErrorMessages.getLoginError('unknown-error'));
        return false;
      }

    } on FirebaseAuthException catch (e) {
      _setError(AuthErrorMessages.getLoginError(e.code));
      return false;
    } catch (e) {
      _setError(AuthErrorMessages.getLoginError(e.toString()));
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Método para iniciar sesión con Google
  Future<bool> signInWithGoogle() async {
    try {
      _setGoogleProcessing(true);
      _setError(null);

      // Iniciar el proceso de autenticación de Google
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        // El usuario canceló el proceso
        _setError(AuthErrorMessages.getGoogleSignInError('cancelled'));
        return false;
      }

      // Obtener los detalles de autenticación de Google
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Crear una nueva credencial
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Iniciar sesión con Firebase usando las credenciales de Google
      final userCredential = await _auth.signInWithCredential(credential);

      if (userCredential.user != null) {
        final user = userCredential.user!;
        
        // Verificar si el usuario ya existe en Firestore
        // NOTA: Esto es crítico para que LoginScreen.dart no falle al verificar rol
        if (kDebugMode) print("GOOGLE LOGIN VM: Checking user ${user.uid} in Firestore...");
        
        final userDoc = await FirebaseFirestore.instance.collection('usuarios').doc(user.uid).get();

        if (!userDoc.exists) {
          if (kDebugMode) print("GOOGLE LOGIN VM: Creating new user document...");
          
          await FirebaseFirestore.instance.collection("usuarios").doc(user.uid).set({
            "uid": user.uid,
            "email": user.email,
            "nombre": user.displayName ?? "Usuario",
            "telefono": "", 
            "photoUrl": user.photoURL,
            "provider": "GOOGLE",
            "createdAt": Timestamp.now(),
            "updatedAt": Timestamp.now(),
            "lastLogin": Timestamp.now(),
            "role": "ciudadano" 
          });
          
          if (kDebugMode) print("GOOGLE LOGIN VM: User document created.");
        } else {
          if (kDebugMode) print("GOOGLE LOGIN VM: Updating lastLogin...");
          await FirebaseFirestore.instance.collection("usuarios").doc(user.uid).update({
            "lastLogin": Timestamp.now(),
          });
        }
        
        return true;
      } else {
        _setError(AuthErrorMessages.getGoogleSignInError('unknown-error'));
        return false;
      }

    } on FirebaseAuthException catch (e) {
      _setError(AuthErrorMessages.getGoogleSignInError(e.code));
      return false;
    } catch (e) {
      // Manejar errores específicos de Google Sign-In
      String errorCode;
      if (e.toString().contains('popup_closed_by_user')) {
        errorCode = 'popup-closed-by-user';
      } else if (e.toString().contains('popup_blocked')) {
        errorCode = 'popup-blocked';
      } else if (e.toString().contains('network')) {
        errorCode = 'network-request-failed';
      } else {
        errorCode = e.toString();
      }

      _setError(AuthErrorMessages.getGoogleSignInError(errorCode));
      return false;
    } finally {
      _setGoogleProcessing(false);
    }
  }

  // Método para restablecer contraseña
  Future<void> resetPassword(String email) async {
    try {
      // Validar email antes de enviar
      final emailError = validateEmail(email);
      if (emailError != null) {
        throw Exception(emailError);
      }

      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw Exception(AuthErrorMessages.getResetPasswordError(e.code));
    } catch (e) {
      if (e is Exception && e.toString().contains('Exception:')) {
        rethrow;
      }
      throw Exception(AuthErrorMessages.getResetPasswordError(e.toString()));
    }
  }

  // Método para cerrar sesión
  Future<void> signOut() async {
    try {
      await Future.wait([
        _auth.signOut(),
        _googleSignIn.signOut(),
      ]);
    } catch (e) {
      // Manejar errores de cierre de sesión si es necesario
      if (kDebugMode) {
        print('Error al cerrar sesión: $e');
      }
    }
  }
}