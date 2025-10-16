import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../cliente/screens/InicioScreen.dart';
import '../../brigadistas/screens/BrigadistaInicioScreen.dart';
import '../utils/constants.dart';
import '../viewmodels/AuthViewModel.dart';
import '../viewmodels/LoginViewModel.dart';
import '../components/ForgotPasswordDialog.dart';
import 'RegisterScreen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  late LoginViewModel _loginViewModel;
  late AnimationController _animationController;
  late AnimationController _logoAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;
  late Animation<double> _logoAnimation;

  @override
  void initState() {
    super.initState();
    _loginViewModel = LoginViewModel();

    // Configurar animaciones
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _logoAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
    ));

    _slideAnimation = Tween<double>(
      begin: 50.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
    ));

    _logoAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _logoAnimationController,
      curve: Curves.elasticOut,
    ));

    // Iniciar animaciones
    _logoAnimationController.forward();
    Future.delayed(const Duration(milliseconds: 300), () {
      _animationController.forward();
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _loginViewModel.dispose();
    _animationController.dispose();
    _logoAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authViewModel = Provider.of<AuthViewModel>(context);

    return ChangeNotifierProvider.value(
      value: _loginViewModel,
      child: Scaffold(
        body: Container(
          decoration: backgroundDecoration,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withValues(alpha: .8),
                  Colors.white.withValues(alpha: .9),
                  kPrimaryColor.withValues(alpha: .05),
                ],
              ),
            ),
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 20.0),
                  child: Consumer<LoginViewModel>(
                    builder: (context, loginVM, child) {
                      return Form(
                        key: _formKey,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Logo animado
                            ScaleTransition(
                              scale: _logoAnimation,
                              child: Container(
                                height: 120,
                                margin: const EdgeInsets.only(bottom: 40),
                                child: Image.asset(
                                  'assets/images/Logo blanco.png',
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),

                            // Título y subtítulo con animación
                            AnimatedBuilder(
                              animation: _animationController,
                              builder: (context, child) {
                                return Transform.translate(
                                  offset: Offset(0, _slideAnimation.value),
                                  child: Opacity(
                                    opacity: _fadeAnimation.value,
                                    child: Column(
                                      children: [
                                        const Text(
                                          'Bienvenido',
                                          style: TextStyle(
                                            fontSize: 32,
                                            fontWeight: FontWeight.bold,
                                            color: kPrimaryColor,
                                            letterSpacing: 1.2,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Inicia sesión para continuar',
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: Colors.grey.shade600,
                                            fontWeight: FontWeight.w400,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                        const SizedBox(height: 40),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),

                            // Campos de formulario
                            AnimatedBuilder(
                              animation: _animationController,
                              builder: (context, child) {
                                return Transform.translate(
                                  offset: Offset(0, _slideAnimation.value),
                                  child: Opacity(
                                    opacity: _fadeAnimation.value,
                                    child: Column(
                                      children: [
                                        // Campo de email
                                        _buildModernTextField(
                                          controller: _emailController,
                                          label: 'Correo electrónico',
                                          icon: Icons.email_outlined,
                                          keyboardType: TextInputType.emailAddress,
                                          validator: loginVM.validateEmail,
                                          onChanged: (value) {
                                            if (loginVM.errorMessage != null) {
                                              loginVM.clearError();
                                            }
                                          },
                                        ),

                                        const SizedBox(height: 20),

                                        // Campo de contraseña
                                        _buildModernTextField(
                                          controller: _passwordController,
                                          label: 'Contraseña',
                                          icon: Icons.lock_outlined,
                                          isPassword: true,
                                          obscureText: loginVM.obscurePassword,
                                          suffixIcon: IconButton(
                                            icon: Icon(
                                              loginVM.obscurePassword
                                                  ? Icons.visibility_off_outlined
                                                  : Icons.visibility_outlined,
                                              color: Colors.grey.shade600,
                                            ),
                                            onPressed: loginVM.togglePasswordVisibility,
                                          ),
                                          validator: loginVM.validatePassword,
                                          onChanged: (value) {
                                            if (loginVM.errorMessage != null) {
                                              loginVM.clearError();
                                            }
                                          },
                                        ),

                                        // Olvidaste tu contraseña
                                        Align(
                                          alignment: Alignment.centerRight,
                                          child: TextButton(
                                            onPressed: () => ForgotPasswordDialog.show(context),
                                            style: TextButton.styleFrom(
                                              foregroundColor: kPrimaryColor,
                                              padding: const EdgeInsets.symmetric(vertical: 8),
                                            ),
                                            child: const Text(
                                              '¿Olvidaste tu contraseña?',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ),

                                        const SizedBox(height: 16),

                                        // Mensaje de error
                                        if (loginVM.errorMessage != null)
                                          Container(
                                            padding: const EdgeInsets.all(16),
                                            margin: const EdgeInsets.only(bottom: 20),
                                            decoration: BoxDecoration(
                                              color: Colors.red.shade50,
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(color: Colors.red.shade200),
                                            ),
                                            child: Row(
                                              children: [
                                                Icon(Icons.error_outline,
                                                    color: Colors.red.shade600, size: 20),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Text(
                                                    loginVM.errorMessage!,
                                                    style: TextStyle(
                                                      color: Colors.red.shade700,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),

                                        // Botón de login
                                        _buildModernButton(
                                          onPressed: loginVM.isLoading
                                              ? null
                                              : () => _handleEmailPasswordLogin(context, authViewModel, loginVM),
                                          isLoading: loginVM.isLoading,
                                          child: const Text(
                                            'Iniciar Sesión',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),

                                        const SizedBox(height: 24),

                                        // Separador
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Container(
                                                height: 1,
                                                color: Colors.grey.shade300,
                                              ),
                                            ),
                                            Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 16),
                                              child: Text(
                                                'O continúa con',
                                                style: TextStyle(
                                                  color: Colors.grey.shade600,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              child: Container(
                                                height: 1,
                                                color: Colors.grey.shade300,
                                              ),
                                            ),
                                          ],
                                        ),

                                        const SizedBox(height: 24),

                                        // Botón de Google
                                        _buildGoogleButton(
                                          onPressed: (loginVM.isLoading || loginVM.isProcessingGoogle)
                                              ? null
                                              : () => _handleGoogleLogin(context, authViewModel, loginVM),
                                          isLoading: loginVM.isProcessingGoogle,
                                        ),

                                        const SizedBox(height: 32),

                                        // Registro
                                        RichText(
                                          textAlign: TextAlign.center,
                                          text: TextSpan(
                                            text: '¿No tienes una cuenta? ',
                                            style: TextStyle(
                                              color: Colors.grey.shade700,
                                              fontSize: 14,
                                            ),
                                            children: [
                                              TextSpan(
                                                text: 'Regístrate',
                                                style: const TextStyle(
                                                  color: kPrimaryColor,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                                recognizer: TapGestureRecognizer()
                                                  ..onTap = () {
                                                    Navigator.of(context).push(
                                                      PageRouteBuilder(
                                                        pageBuilder: (context, animation, secondaryAnimation) =>
                                                        const RegisterScreen(),
                                                        transitionDuration: const Duration(milliseconds: 300),
                                                        transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                                          return SlideTransition(
                                                            position: Tween<Offset>(
                                                              begin: const Offset(1.0, 0.0),
                                                              end: Offset.zero,
                                                            ).animate(animation),
                                                            child: child,
                                                          );
                                                        },
                                                      ),
                                                    );
                                                  },
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    Function(String)? onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        validator: validator,
        onChanged: onChanged,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: kPrimaryColor.withValues(alpha: .7)),
          suffixIcon: suffixIcon,
          labelStyle: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 16,
          ),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: kPrimaryColor, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.red.shade300),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        ),
      ),
    );
  }

  Widget _buildModernButton({
    required VoidCallback? onPressed,
    required Widget child,
    bool isLoading = false,
  }) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: onPressed != null ? const LinearGradient(
          colors: [kPrimaryColor, Color(0xFFD32F2F)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ) : null,
        color: onPressed == null ? Colors.grey.shade300 : null,
        boxShadow: onPressed != null ? [
          BoxShadow(
            color: kPrimaryColor.withValues(alpha: .3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ] : null,
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: isLoading
            ? const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            color: Colors.white,
            strokeWidth: 2,
          ),
        )
            : child,
      ),
    );
  }

  Widget _buildGoogleButton({
    required VoidCallback? onPressed,
    bool isLoading = false,
  }) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.grey.shade700,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        icon: isLoading
            ? const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            color: kPrimaryColor,
            strokeWidth: 2,
          ),
        )
            : Container(
          width: 24,
          height: 24,
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: NetworkImage('https://developers.google.com/identity/images/g-logo.png'),
              fit: BoxFit.contain,
            ),
          ),
        ),
        label: const Text(
          'Continuar con Google',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  // Método para manejar el inicio de sesión con email y contraseña
  void _handleEmailPasswordLogin(
      BuildContext context,
      AuthViewModel authViewModel,
      LoginViewModel loginVM) async {

    if (!_formKey.currentState!.validate()) return;

    final success = await loginVM.signInWithEmailAndPassword(
      _emailController.text.trim(),
      _passwordController.text,
    );

    if (success && mounted) {
      await authViewModel.checkAuthState();

      // Verificar si es brigadista y navegar según el rol
      await _navegarSegunRol(context);
    }
  }

  // Método para manejar el inicio de sesión con Google
  void _handleGoogleLogin(
      BuildContext context,
      AuthViewModel authViewModel,
      LoginViewModel loginVM) async {

    final success = await loginVM.signInWithGoogle();

    if (success && mounted) {
      await authViewModel.checkAuthState();

      // Verificar si es brigadista y navegar según el rol
      await _navegarSegunRol(context);
    } else if (mounted && loginVM.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loginVM.errorMessage!),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }
// MÉTODO ACTUALIZADO: Limpia todo el stack de navegación
  Future<void> _navegarSegunRol(BuildContext context) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('❌ No hay usuario autenticado');
        return;
      }

      print('═══════════════════════════════════════');
      print('🔍 VERIFICANDO ROL DEL USUARIO');
      print('═══════════════════════════════════════');
      print('📧 Email: ${user.email}');
      print('🆔 UID del Authentication: ${user.uid}');
      print('🔐 Provider: ${user.providerData.first.providerId}');

      // Mostrar indicador de carga
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
                SizedBox(width: 12),
                Text('Verificando credenciales...'),
              ],
            ),
            duration: Duration(seconds: 2),
          ),
        );
      }

      // Buscar documento del usuario en Firestore
      print('📂 Buscando documento en ruta: usuarios/${user.uid}');

      final userDoc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid)
          .get();

      print('📄 Documento existe: ${userDoc.exists}');

      if (!mounted) return;

      if (userDoc.exists) {
        final userData = userDoc.data();

        print('✅ Documento encontrado');
        print('📊 DATOS COMPLETOS DEL DOCUMENTO:');
        print('   ${userData.toString()}');
        print('');
        print('🔑 Campos disponibles:');
        userData?.forEach((key, value) {
          print('   - $key: $value (tipo: ${value.runtimeType})');
        });
        print('');

        // Buscar el campo role (puede estar como "role" o "rol")
        final role = userData?['role'];
        final rol = userData?['rol'];

        print('🎯 Valor de campo "role": $role (tipo: ${role.runtimeType})');
        print('🎯 Valor de campo "rol": $rol (tipo: ${rol.runtimeType})');

        // Limpiar espacios y convertir a minúsculas para comparación
        final roleNormalizado = (role?.toString().trim().toLowerCase() ?? '');
        final rolNormalizado = (rol?.toString().trim().toLowerCase() ?? '');

        print('🧹 role normalizado: "$roleNormalizado"');
        print('🧹 rol normalizado: "$rolNormalizado"');
        print('');

        // Verificar si es brigadista
        final esBrigadista = roleNormalizado == 'brigadista' || rolNormalizado == 'brigadista';

        print('🤔 ¿Es brigadista?: $esBrigadista');
        print('   roleNormalizado == "brigadista": ${roleNormalizado == "brigadista"}');
        print('   rolNormalizado == "brigadista": ${rolNormalizado == "brigadista"}');
        print('');

        if (esBrigadista) {
          // Es brigadista - ir a pantalla de brigadista
          print('✅ ========================================');
          print('✅ USUARIO ES BRIGADISTA');
          print('✅ ========================================');
          print('   🚒 Brigada: ${userData?['nombreBrigada'] ?? 'Sin brigada'}');
          print('   🆔 BrigadaID: ${userData?['brigadaId'] ?? 'Sin ID'}');
          print('   🔄 Navegando a BrigadistaInicioScreen...');

          // CAMBIADO: pushAndRemoveUntil para limpiar el stack completo
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (context) => const BrigadistaInicioScreen(),
            ),
                (route) => false, // Elimina todas las rutas anteriores
          );
        } else {
          // Es cliente normal - ir a pantalla de cliente
          print('✅ ========================================');
          print('✅ USUARIO ES CLIENTE');
          print('✅ ========================================');
          print('   🔄 Navegando a InicioScreen...');

          // CAMBIADO: pushAndRemoveUntil para limpiar el stack completo
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (context) => const InicioScreen(),
            ),
                (route) => false, // Elimina todas las rutas anteriores
          );
        }
      } else {
        // El documento no existe
        print('⚠️ ========================================');
        print('⚠️ DOCUMENTO NO EXISTE EN FIRESTORE');
        print('⚠️ ========================================');
        print('❌ No se encontró documento con UID: ${user.uid}');
        print('');
        print('💡 POSIBLES CAUSAS:');
        print('   1. El usuario no tiene documento en Firestore');
        print('   2. El UID no coincide');
        print('   3. El documento está en otra colección');
        print('');
        print('🔍 Intentando buscar por email...');

        // Intentar buscar por email
        final querySnapshot = await FirebaseFirestore.instance
            .collection('usuarios')
            .where('email', isEqualTo: user.email)
            .limit(1)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          final doc = querySnapshot.docs.first;
          print('✅ Encontrado documento con email!');
          print('   ID del documento: ${doc.id}');
          print('   UID del usuario: ${user.uid}');
          print('   ⚠️ LOS IDs NO COINCIDEN - Este es el problema!');
          print('');
          print('💡 SOLUCIÓN: El documento debe tener como ID el UID del usuario');
        } else {
          print('❌ No se encontró ningún documento con email: ${user.email}');
        }

        print('✅ Redirigiendo a pantalla de CLIENTE por defecto');

        // CAMBIADO: pushAndRemoveUntil para limpiar el stack completo
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => const InicioScreen(),
          ),
              (route) => false, // Elimina todas las rutas anteriores
        );
      }

      print('═══════════════════════════════════════\n');

    } catch (e, stackTrace) {
      print('❌ ========================================');
      print('❌ ERROR AL VERIFICAR ROL');
      print('❌ ========================================');
      print('Error: $e');
      print('Tipo de error: ${e.runtimeType}');
      print('Stack trace:');
      print(stackTrace);

      // En caso de error, ir a pantalla de cliente por defecto
      if (mounted) {
        // CAMBIADO: pushAndRemoveUntil para limpiar el stack completo
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => const InicioScreen(),
          ),
              (route) => false, // Elimina todas las rutas anteriores
        );
      }
    }
  }
}