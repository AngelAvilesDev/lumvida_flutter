import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class GoogleSignInService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Método limpio para iniciar sesión con Google
  static Future<User?> signInWithGoogle() async {
    try {
      // 1. Forzar logout previo para limpiar cualquier estado
      await _googleSignIn.signOut();

      // 2. Intentar login con Google
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      // 3. Obtener credenciales de autenticación
      final GoogleSignInAuthentication googleAuth =
      await googleUser.authentication;

      // 4. Crear credencial para Firebase
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // 5. Autenticar con Firebase
      final UserCredential authResult =
      await _auth.signInWithCredential(credential);

      final User? user = authResult.user;
      if (user == null) return null;

      // 6. Guardar datos en Firestore
      await _saveUserData(user);

      return user;
    } catch (e) {
      print('Error en GoogleSignInService: $e');
      // Asegurar limpieza en caso de error
      await _googleSignIn.signOut();
      await _auth.signOut();
      return null;
    }
  }

  // Método auxiliar para guardar datos de usuario
  static Future<void> _saveUserData(User user) async {
    try {
      await _firestore.collection('usuarios').doc(user.uid).set({
        'uid': user.uid,
        'email': user.email,
        'nombre': user.displayName ?? 'Usuario',
        'provider': 'GOOGLE',
        'createdAt': FieldValue.serverTimestamp(),
        'lastLogin': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error guardando datos: $e');
      // No lanzamos excepción, permitimos que continúe el flujo
    }
  }
}