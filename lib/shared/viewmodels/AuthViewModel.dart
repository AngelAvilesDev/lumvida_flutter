import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/GoogleSignInService.dart';

class AuthViewModel extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  User? _user;
  bool _isLoading = false;
  String? _errorMessage;
  String? _nombreUsuario;
  String? _telefono;
  String? _photoUrl;
  String? _role;
  bool _isCheckingAuth = true;

  bool get isAuthenticated => _user != null;
  User? get user => _user;
  bool get isLoading => _isLoading;
  bool get isCheckingAuth => _isCheckingAuth;
  String? get errorMessage => _errorMessage;
  String? get nombreUsuario => _nombreUsuario;
  String? get telefono => _telefono;
  String? get photoUrl => _photoUrl;
  String? get role => _role;

  bool get esBrigadista {
    final r = _role?.trim().toLowerCase() ?? '';
    return r == 'brigadista';
  }

  AuthViewModel() {
    _loadCache();
    _checkInitialAuth();
  }

  // Cargar datos cacheados al iniciar
  Future<void> _loadCache() async {
    final prefs = await SharedPreferences.getInstance();
    _nombreUsuario = prefs.getString('user_name');
    _telefono = prefs.getString('user_phone');
    _role = prefs.getString('user_role');
    _photoUrl = prefs.getString('user_photo'); // Recuperar foto del cache
    
    if (_nombreUsuario != null) {
      notifyListeners(); // Mostrar datos cacheados inmediatamente
    }
  }

  Future<void> _saveCache(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    if (data['nombre'] != null) await prefs.setString('user_name', data['nombre']);
    if (data['telefono'] != null) await prefs.setString('user_phone', data['telefono']);
    
    final role = data['role']?.toString() ?? data['rol']?.toString();
    if (role != null) await prefs.setString('user_role', role);
    
    if (data['photoUrl'] != null) await prefs.setString('user_photo', data['photoUrl']);
  }

  void _checkInitialAuth() {
    // Escuchar cambios de autenticación
    _auth.authStateChanges().listen((User? user) async {
      _user = user;
      
      if (user != null) {
        await _cargarDatosUsuario(user.uid);
      } else {
        _limpiarDatosUsuario();
      }
      
      _isCheckingAuth = false;
      notifyListeners();
    });
  }

  Future<void> _limpiarDatosUsuario() async {
    _nombreUsuario = null;
    _telefono = null;
    _role = null;
    _photoUrl = null;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_name');
    await prefs.remove('user_phone');
    await prefs.remove('user_role');
    await prefs.remove('user_photo');
  }

  Future<void> _cargarDatosUsuario(String uid) async {
    try {
      final doc = await _firestore.collection('usuarios').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        final datos = doc.data()!;
        _nombreUsuario = datos['nombre'];
        _telefono = datos['telefono'];
        _photoUrl = datos['photoUrl']; // Cargar URL de foto
        // Manejar role/rol por compatibilidad
        _role = datos['role']?.toString() ?? datos['rol']?.toString();
        
        // Guardar en caché para la próxima vez
        _saveCache(datos);
        
        notifyListeners(); 
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error al cargar datos del usuario: $e');
      }
    }
  }

  Future<void> checkAuthState() async {
    _user = _auth.currentUser;
    if (_user != null) {
      await _cargarDatosUsuario(_user!.uid);
    }
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

      if (userCredential.user != null) {
        await _cargarDatosUsuario(userCredential.user!.uid);
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _isLoading = false;
      _errorMessage = _getMessageFromErrorCode(e.code);
      notifyListeners();
      return false;
    }
  }

  // Registrar nuevo usuario
  Future<bool> registerWithEmailAndPassword(String email, String password, String name, String phone) async {
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

        _nombreUsuario = name;
        _telefono = phone;  // Guardamos el teléfono
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
    }
  }

  // Método autenticación con Google
  Future<bool> signInWithGoogle() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final User? user = await GoogleSignInService.signInWithGoogle();

      if (user != null) {
        // Verificar si el usuario ya existe en Firestore
        if (kDebugMode) print("GOOGLE AUTH: Checking if user ${user.uid} exists in Firestore...");
        final userDoc = await _firestore.collection('usuarios').doc(user.uid).get();

        if (!userDoc.exists) {
          if (kDebugMode) print("GOOGLE AUTH: User does not exist. Creating new document...");
          // Si no existe, crearlo (como en el registro por correo)
          await _firestore.collection("usuarios").doc(user.uid).set({
            "uid": user.uid,
            "email": user.email,
            "nombre": user.displayName ?? "Usuario",
            "telefono": "", // Google no siempre retorna teléfono
            "photoUrl": user.photoURL,
            "provider": "GOOGLE",
            "createdAt": Timestamp.now(),
            "updatedAt": Timestamp.now(),
            "lastLogin": Timestamp.now(),
            "role": "ciudadano" // Rol por defecto
          });
          if (kDebugMode) print("GOOGLE AUTH: User document created successfully.");
        } else {
          if (kDebugMode) print("GOOGLE AUTH: User exists. Updating lastLogin...");
          await _firestore.collection("usuarios").doc(user.uid).update({
            "lastLogin": Timestamp.now(),
          });
        }
        
        _user = user;
        await _cargarDatosUsuario(user.uid);
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _isLoading = false;
        _errorMessage = "No se pudo iniciar sesión con Google";
        notifyListeners();
        return false;
      }
    } catch (e) {
      if (kDebugMode) {
        print("Error en signInWithGoogle: $e");
      }
      _isLoading = false;
      _errorMessage = "Error técnico al iniciar sesión: ${e.toString()}";
      notifyListeners();
      return false;
    }
  }

  // Actualizar el teléfono del usuario
  Future<bool> updateUserPhone(String phone) async {
    if (_user == null) {
      _errorMessage = "No hay usuario autenticado";
      notifyListeners();
      return false;
    }

    try {
      _isLoading = true;
      notifyListeners();

      await _firestore.collection("usuarios").doc(_user!.uid).update({
        "telefono": phone
      });

      _telefono = phone;  // Actualizamos el teléfono localmente
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = "Error al actualizar el teléfono: ${e.toString()}";
      notifyListeners();
      return false;
    }
  }

  // Cerrar sesión
  Future<void> signOut() async {
    try {
      _isLoading = true;
      notifyListeners();

      await _googleSignIn.signOut();
      await _auth.signOut();
      _nombreUsuario = null;
      _telefono = null;  // Limpiamos el teléfono

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = "Error al cerrar sesión: ${e.toString()}";
      notifyListeners();
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
    }
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
      case "email-already-in-use":
        return "Ya existe una cuenta con este correo electrónico";
      case "operation-not-allowed":
        return "Operación no permitida";
      case "weak-password":
        return "La contraseña es demasiado débil";
      case "too-many-requests":
        return "Demasiados intentos fallidos. Inténtalo más tarde";
      default:
        return "Ha ocurrido un error. Inténtalo de nuevo";
    }
  }
}