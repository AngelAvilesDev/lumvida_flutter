// viewmodels/RegisterViewModel.dart
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/error_messages.dart';

class RegisterViewModel extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = false;
  bool _isProcessingGoogle = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _errorMessage;

  // Getters
  bool get isLoading => _isLoading;
  bool get isProcessingGoogle => _isProcessingGoogle;
  bool get obscurePassword => _obscurePassword;
  bool get obscureConfirmPassword => _obscureConfirmPassword;
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

  void toggleConfirmPasswordVisibility() {
    _obscureConfirmPassword = !_obscureConfirmPassword;
    notifyListeners();
  }

  void clearError() {
    if (_errorMessage != null) {
      _setError(null);
    }
  }

  // Validadores usando AuthErrorMessages
  String? validateName(String? value) {
    return AuthErrorMessages.validateName(value);
  }

  String? validateEmail(String? value) {
    return AuthErrorMessages.validateEmail(value);
  }

  String? validatePhone(String? value) {
    return AuthErrorMessages.validatePhone(value);
  }

  String? validatePassword(String? value) {
    // Para registro, usar validación estricta
    return AuthErrorMessages.validatePassword(value);
  }

  String? validateConfirmPassword(String? value, String password) {
    return AuthErrorMessages.validateConfirmPassword(value, password);
  }

  // Método para formatear teléfono
  String formatPhone(String value) {
    return AuthErrorMessages.formatPhone(value);
  }

  // Método para obtener fortaleza de contraseña
  PasswordStrength getPasswordStrength(String password) {
    return AuthErrorMessages.getPasswordStrength(password);
  }

  // Método para obtener consejos de contraseña
  List<String> getPasswordTips(String password) {
    return AuthErrorMessages.getPasswordTips(password);
  }

  // Método para registrar con email y contraseña
  Future<bool> registerWithEmailAndPassword({
    required String email,
    required String password,
    required String name,
    required String phone,
  }) async {
    try {
      _setLoading(true);
      _setError(null);

      // Validar todos los campos antes de proceder
      final nameError = validateName(name);
      if (nameError != null) {
        _setError(nameError);
        return false;
      }

      final emailError = validateEmail(email);
      if (emailError != null) {
        _setError(emailError);
        return false;
      }

      final phoneError = validatePhone(phone);
      if (phoneError != null) {
        _setError(phoneError);
        return false;
      }

      final passwordError = validatePassword(password);
      if (passwordError != null) {
        _setError(passwordError);
        return false;
      }

      // Verificar que la contraseña sea al menos de seguridad media
      final passwordStrength = getPasswordStrength(password);
      if (passwordStrength == PasswordStrength.veryWeak) {
        _setError('La contraseña es demasiado débil. Por favor, elige una más segura.');
        return false;
      }

      // Crear usuario en Firebase Auth
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null) {
        // Actualizar el perfil del usuario
        await userCredential.user!.updateDisplayName(name);

        // Guardar información adicional en Firestore
        await _saveUserToFirestore(
          user: userCredential.user!,
          name: name,
          phone: phone,
          registrationMethod: 'email',
        );

        return true;
      } else {
        _setError(AuthErrorMessages.getRegisterError('unknown-error'));
        return false;
      }

    } on FirebaseAuthException catch (e) {
      _setError(AuthErrorMessages.getRegisterError(e.code));
      return false;
    } catch (e) {
      _setError(AuthErrorMessages.getRegisterError(e.toString()));
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Método para registrar con Google
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
        // Verificar si es un usuario nuevo
        final isNewUser = userCredential.additionalUserInfo?.isNewUser ?? false;

        if (isNewUser) {
          // Guardar información del usuario en Firestore
          await _saveUserToFirestore(
            user: userCredential.user!,
            name: userCredential.user!.displayName ?? 'Usuario',
            phone: '', // Google no proporciona teléfono por defecto
            registrationMethod: 'google',
          );
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

  // Método privado para guardar usuario en Firestore
  Future<void> _saveUserToFirestore({
    required User user,
    required String name,
    required String phone,
    required String registrationMethod,
  }) async {
    try {
      final userData = {
        'uid': user.uid,
        'name': name,
        'email': user.email ?? '',
        'phone': phone,
        'photoURL': user.photoURL,
        'registrationMethod': registrationMethod,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isActive': true,
      };

      await _firestore.collection('users').doc(user.uid).set(userData);

    } catch (e) {
      // Log el error pero no fallar el registro
      if (kDebugMode) {
        print('Error al guardar usuario en Firestore: $e');
      }
    }
  }

  // Método para actualizar información del usuario
  Future<bool> updateUserProfile({
    String? name,
    String? phone,
  }) async {
    try {
      _setLoading(true);
      _setError(null);

      final user = _auth.currentUser;
      if (user == null) {
        _setError('No hay usuario autenticado');
        return false;
      }

      // Validar campos si se proporcionan
      if (name != null) {
        final nameError = validateName(name);
        if (nameError != null) {
          _setError(nameError);
          return false;
        }
      }

      if (phone != null) {
        final phoneError = validatePhone(phone);
        if (phoneError != null) {
          _setError(phoneError);
          return false;
        }
      }

      // Actualizar en Firebase Auth si se proporciona el nombre
      if (name != null) {
        await user.updateDisplayName(name);
      }

      // Actualizar en Firestore
      final updateData = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (name != null) updateData['name'] = name;
      if (phone != null) updateData['phone'] = phone;

      await _firestore.collection('users').doc(user.uid).update(updateData);

      return true;

    } catch (e) {
      _setError('Error al actualizar el perfil: ${e.toString()}');
      return false;
    } finally {
      _setLoading(false);
    }
  }
}