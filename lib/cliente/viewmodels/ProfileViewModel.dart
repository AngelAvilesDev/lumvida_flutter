import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileViewModel extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ImagePicker _imagePicker = ImagePicker();

  // Estados
  bool _isLoading = false;
  bool _isUpdating = false;
  bool _isEditing = false;
  String? _errorMessage;
  String? _successMessage;

  // Datos del usuario
  String _nombre = '';
  String _telefono = '';
  String _email = '';
  String? _photoUrl;
  String? _localPhotoPath; // Ruta local persistente ex: /data/user/0/.../profile.jpg
  File? _selectedImage;

  // Estadísticas actualizadas con colores correctos
  int _totalReportes = 0;
  int _reportesResueltos = 0;     // Verde
  int _reportesPendientes = 0;    // Gris
  int _reportesEnRevision = 0;    // Naranja
  int _reportesAsignados = 0;     // Azul
  int _reportesEnProceso = 0;     // Amarillo

  // Getters
  bool get isLoading => _isLoading;
  bool get isUpdating => _isUpdating;
  bool get isEditing => _isEditing;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;

  String get nombre => _nombre;
  String get telefono => _telefono;
  String get email => _email;
  String? get photoUrl => _photoUrl;
  String? get localPhotoPath => _localPhotoPath;
  File? get selectedImage => _selectedImage;

  int get totalReportes => _totalReportes;
  int get reportesResueltos => _reportesResueltos;       // Verde
  int get reportesPendientes => _reportesPendientes;     // Gris
  int get reportesEnRevision => _reportesEnRevision;     // Naranja
  int get reportesAsignados => _reportesAsignados;       // Azul
  int get reportesEnProceso => _reportesEnProceso;       // Amarillo

  // Alternar modo de edición
  void toggleEditMode() {
    _isEditing = !_isEditing;
    _clearMessages();
    notifyListeners();
  }

  // Inicializar con datos en caché para carga instantánea - RESTAURADO
  void setInitialData({
    required String nombre,
    required String telefono,
    required String email,
    String? photoUrl,
  }) {
    _nombre = nombre;
    _telefono = telefono;
    _email = email;
    _photoUrl = photoUrl;
    // No notificamos aquí porque se llamará antes de que la vista se construya o justo en initState
  }

  // Verificar si hay imagen local guardada
  Future<void> _checkLocalProfileImage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final path = prefs.getString('local_profile_image_path');
      if (path != null && await File(path).exists()) {
        _localPhotoPath = path;
        notifyListeners();
      }
    } catch (e) {
      if (kDebugMode) print('Error checking local image: $e');
    }
  }

  // Descargar y guardar imagen localmente
  Future<void> _downloadAndSaveProfileImage(String url) async {
    try {
      // Si ya tenemos una ruta local y parece válida, podríamos verificar si la URL cambió,
      // pero por simplicidad asumimos que si tenemos URL de red, intentamos actualizar el local.
      
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/profile_image.jpg';
      
      // Descargar bytes
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);
        
        _localPhotoPath = filePath;
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('local_profile_image_path', filePath);
        
        notifyListeners(); // Actualizar UI con la nueva imagen local
      }
    } catch (e) {
      if (kDebugMode) print('Error saving local image: $e');
    }
  }

  // Cargar datos del usuario
  Future<void> loadUserData() async {
    final user = _auth.currentUser;
    if (user == null) return;

    // Cargar imagen local PRIMERO para respuesta inmediata
    _checkLocalProfileImage();

    // Solo mostramos loading si no tenemos datos previos NI imagen local
    if (_nombre.isEmpty && _localPhotoPath == null) {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
    }

    try {
      // Cargar datos básicos (siempre actualizamos email/foto de auth)
      _email = user.email ?? '';
      if (user.photoURL != null) {
        _photoUrl = user.photoURL;
        // Intentar guardar localmente para la próxima vez
        _downloadAndSaveProfileImage(_photoUrl!); 
      }
      
      // ... resto del método igual ...
      final userDoc = await _firestore.collection('usuarios').doc(user.uid).get();
      if (userDoc.exists) {
        final data = userDoc.data()!;
        _nombre = data['nombre'] ?? user.displayName ?? '';
        _telefono = data['telefono'] ?? '';
      } else if (_nombre.isEmpty) {
        _nombre = user.displayName ?? '';
        _telefono = '';
      }

      await _loadReportStatistics(user.uid);

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
       if (_nombre.isEmpty && _localPhotoPath == null) {
        _errorMessage = 'Error al cargar datos del usuario: $e';
      }
      notifyListeners();
    }
  }

  // Cargar estadísticas de reportes - CORREGIDO CON ESTADOS Y COLORES EXACTOS
  Future<void> _loadReportStatistics(String userId) async {
    try {
      final reportesSnapshot = await _firestore
          .collection('reportes')
          .where('userId', isEqualTo: userId)
          .get();

      _totalReportes = reportesSnapshot.docs.length;
      _reportesResueltos = 0;     // Verde
      _reportesPendientes = 0;    // Gris
      _reportesEnRevision = 0;    // Naranja
      _reportesAsignados = 0;     // Azul
      _reportesEnProceso = 0;     // Amarillo

      for (final doc in reportesSnapshot.docs) {
        final estado = _normalizeEstado(doc.data()['estado']?.toString() ?? '');

        switch (estado) {
          case 'resuelto':
            _reportesResueltos++;        // Verde
            break;
          case 'en revisión':
            _reportesEnRevision++;       // Naranja
            break;
          case 'asignado':
            _reportesAsignados++;        // Azul
            break;
          case 'en proceso':
            _reportesEnProceso++;        // Amarillo
            break;
          case 'pendiente':
          default:
            _reportesPendientes++;       // Gris
            break;
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading report statistics: $e');
      }
    }
  }

  // NORMALIZAR ESTADO PARA COMPARACIÓN - IGUAL QUE EN MisReportesScreen
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

  // Actualizar datos del usuario
  Future<bool> updateUserData({
    required String nombre,
    required String telefono,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      _errorMessage = 'No hay usuario autenticado';
      notifyListeners();
      return false;
    }

    // Validaciones
    if (nombre.trim().isEmpty) {
      _errorMessage = 'El nombre no puede estar vacío';
      notifyListeners();
      return false;
    }

    if (telefono.trim().isNotEmpty && !_isValidPhone(telefono.trim())) {
      _errorMessage = 'El teléfono debe tener 10 dígitos';
      notifyListeners();
      return false;
    }

    _isUpdating = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      // Actualizar en Firestore
      await _firestore.collection('usuarios').doc(user.uid).set({
        'nombre': nombre.trim(),
        'telefono': telefono.trim(),
        'email': user.email,
        'uid': user.uid,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Actualizar displayName en FirebaseAuth si es diferente
      if (user.displayName != nombre.trim()) {
        await user.updateDisplayName(nombre.trim());
      }

      // Actualizar datos locales
      _nombre = nombre.trim();
      _telefono = telefono.trim();
      _isUpdating = false;
      _isEditing = false;
      _successMessage = 'Perfil actualizado correctamente';

      notifyListeners();
      return true;
    } catch (e) {
      _isUpdating = false;
      _errorMessage = 'Error al actualizar el perfil: $e';
      notifyListeners();
      if (kDebugMode) {
        print('Error updating user data: $e');
      }
      return false;
    }
  }

  // Seleccionar imagen de perfil
  Future<void> selectProfileImage({ImageSource source = ImageSource.gallery}) async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: source,
        imageQuality: 50,
        maxWidth: 800,
        maxHeight: 800,
      );

      if (pickedFile != null) {
        _selectedImage = File(pickedFile.path);
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = 'Error al seleccionar imagen: $e';
      notifyListeners();
    }
  }

  // Subir imagen de perfil (simulado - necesitarías Firebase Storage para implementación real)
  Future<bool> uploadProfileImage() async {
    if (_selectedImage == null) return false;

    final user = _auth.currentUser;
    if (user == null) return false;

    _isUpdating = true;
    notifyListeners();

    try {
      // Aquí iría la lógica para subir a Firebase Storage
      // Por ahora simularemos que se sube correctamente

      await Future.delayed(const Duration(seconds: 2)); // Simular delay

      // En implementación real, obtendrías la URL de Firebase Storage
      // final downloadUrl = await uploadToFirebaseStorage(_selectedImage!);
      // await user.updatePhotoURL(downloadUrl);
      // _photoUrl = downloadUrl;

      _isUpdating = false;
      _selectedImage = null;
      _successMessage = 'Imagen de perfil actualizada';
      notifyListeners();
      return true;
    } catch (e) {
      _isUpdating = false;
      _errorMessage = 'Error al subir imagen: $e';
      notifyListeners();
      return false;
    }
  }

  // Recargar estadísticas
  Future<void> refreshStatistics() async {
    final user = _auth.currentUser;
    if (user != null) {
      await _loadReportStatistics(user.uid);
      notifyListeners();
    }
  }

  // Validar teléfono
  bool _isValidPhone(String phone) {
    final phoneRegex = RegExp(r'^\d{10}$');
    return phoneRegex.hasMatch(phone);
  }

  // Limpiar mensajes
  void _clearMessages() {
    _errorMessage = null;
    _successMessage = null;
  }

  // Validaciones para formularios
  String? validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'El nombre no puede estar vacío';
    }
    if (value.trim().length < 2) {
      return 'El nombre debe tener al menos 2 caracteres';
    }
    return null;
  }

  String? validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // Teléfono es opcional
    }
    if (!_isValidPhone(value.trim())) {
      return 'El teléfono debe tener exactamente 10 dígitos';
    }
    return null;
  }

  String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'La contraseña no puede estar vacía';
    }
    if (value.length < 6) {
      return 'La contraseña debe tener al menos 6 caracteres';
    }
    return null;
  }

  // Limpiar datos al cerrar
  void clearData() {
    _nombre = '';
    _telefono = '';
    _email = '';
    _photoUrl = null;
    _selectedImage = null;
    _totalReportes = 0;
    _reportesResueltos = 0;
    _reportesPendientes = 0;
    _reportesEnRevision = 0;
    _reportesAsignados = 0;
    _reportesEnProceso = 0;
    _isEditing = false;
    _isLoading = false;
    _isUpdating = false;
    _clearMessages();
    notifyListeners();
  }

  // Formatear teléfono automáticamente
  String formatPhone(String value) {
    // Remover todo lo que no sea dígito
    final digitsOnly = value.replaceAll(RegExp(r'[^\d]'), '');

    // Limitar a 10 dígitos
    if (digitsOnly.length > 10) {
      return digitsOnly.substring(0, 10);
    }

    return digitsOnly;
  }
}