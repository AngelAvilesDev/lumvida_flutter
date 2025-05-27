import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';

import '../utils/constants.dart';
import '../viewmodels/AuthViewModel.dart';
import '../viewmodels/LoginViewModel.dart';
import 'InicioScreen.dart';
import 'RegisterScreen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  late LoginViewModel _loginViewModel;

  @override
  void initState() {
    super.initState();
    _loginViewModel = LoginViewModel();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _loginViewModel.dispose();
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
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Consumer<LoginViewModel>(
                  builder: (context, loginVM, child) {
                    return Form(
                      key: _formKey,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Logo
                          Align(
                            alignment: Alignment.center,
                            child: Image.asset(
                              'assets/images/Logo blanco.png',
                              height: 120,
                            ),
                          ),
                          const SizedBox(height: 30),

                          // Título
                          const Text(
                            'Iniciar Sesión',
                            style: kTitleStyle,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 10),

                          const Text(
                            'Ingresa tus datos para acceder',
                            style: kSubtitleStyle,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 40),

                          // Campo de correo electrónico
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: Colors.white,
                              labelText: 'Correo electrónico',
                              labelStyle: TextStyle(color: Colors.grey.shade700),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none,
                              ),
                              prefixIcon: const Icon(Icons.email, color: kPrimaryColor),
                            ),
                            validator: loginVM.validateEmail,
                            onChanged: (value) {
                              if (loginVM.errorMessage != null) {
                                loginVM.clearError();
                              }
                            },
                          ),
                          const SizedBox(height: 16),

                          // Campo de contraseña
                          TextFormField(
                            controller: _passwordController,
                            obscureText: loginVM.obscurePassword,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: Colors.white,
                              labelText: 'Contraseña',
                              labelStyle: TextStyle(color: Colors.grey.shade700),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none,
                              ),
                              prefixIcon: const Icon(Icons.lock, color: kPrimaryColor),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  loginVM.obscurePassword ? Icons.visibility_off : Icons.visibility,
                                  color: Colors.grey.shade600,
                                ),
                                onPressed: loginVM.togglePasswordVisibility,
                              ),
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
                              onPressed: () => _showForgotPasswordDialog(context, loginVM),
                              style: TextButton.styleFrom(
                                foregroundColor: kPrimaryColor,
                              ),
                              child: const Text('¿Olvidaste tu contraseña?'),
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Mensaje de error
                          if (loginVM.errorMessage != null)
                            Container(
                              padding: const EdgeInsets.all(10),
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: Colors.red.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                loginVM.errorMessage!,
                                style: TextStyle(color: Colors.red.shade800),
                                textAlign: TextAlign.center,
                              ),
                            ),

                          // Botón de inicio de sesión
                          ElevatedButton.icon(
                            onPressed: loginVM.isLoading
                                ? null
                                : () => _handleEmailPasswordLogin(context, authViewModel, loginVM),
                            style: kPrimaryButtonStyle,
                            icon: const Icon(Icons.email),
                            label: loginVM.isLoading
                                ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                                : const Text(
                              'Iniciar sesión con Email',
                              style: kButtonTextStyle,
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Separador
                          const Row(
                            children: [
                              Expanded(
                                child: Divider(color: Colors.grey, thickness: 1),
                              ),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16),
                                child: Text(
                                  'O',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ),
                              Expanded(
                                child: Divider(color: Colors.grey, thickness: 1),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // Botón de Google
                          OutlinedButton.icon(
                            onPressed: (loginVM.isLoading || loginVM.isProcessingGoogle)
                                ? null
                                : () => _handleGoogleLogin(context, authViewModel, loginVM),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: kPrimaryColor,
                              side: const BorderSide(color: kPrimaryColor),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            icon: loginVM.isProcessingGoogle
                                ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: kPrimaryColor,
                                strokeWidth: 2,
                              ),
                            )
                                : const Icon(Icons.g_mobiledata, size: 28),
                            label: const Text(
                              'Iniciar sesión con Google',
                              style: kButtonTextStyle,
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Registro
                          Center(
                            child: RichText(
                              textAlign: TextAlign.center,
                              text: TextSpan(
                                text: '¿No tienes una cuenta? ',
                                style: TextStyle(color: Colors.grey.shade700),
                                children: [
                                  TextSpan(
                                    text: 'Regístrate',
                                    style: const TextStyle(
                                      color: kPrimaryColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    recognizer: TapGestureRecognizer()
                                      ..onTap = () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (context) => const RegisterScreen(),
                                          ),
                                        );
                                      },
                                  ),
                                ],
                              ),
                            ),
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
      // Actualizar el AuthViewModel
      await authViewModel.checkAuthState();

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const InicioScreen()),
      );
    }
  }

  // Método para manejar el inicio de sesión con Google
  void _handleGoogleLogin(
      BuildContext context,
      AuthViewModel authViewModel,
      LoginViewModel loginVM) async {

    final success = await loginVM.signInWithGoogle();

    if (success && mounted) {
      // Actualizar el AuthViewModel
      await authViewModel.checkAuthState();

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const InicioScreen()),
      );
    } else if (mounted && loginVM.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loginVM.errorMessage!),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Método para mostrar el diálogo de olvidar contraseña
  void _showForgotPasswordDialog(BuildContext context, LoginViewModel loginVM) {
    final formKey = GlobalKey<FormState>();
    final emailController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Restablecer contraseña', style: TextStyle(color: kPrimaryColor)),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'Correo electrónico',
                hintText: 'Ingrese su correo electrónico',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                prefixIcon: const Icon(Icons.email),
              ),
              validator: loginVM.validateEmail,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancelar', style: TextStyle(color: kPrimaryColor)),
            ),
            Consumer<LoginViewModel>(
              builder: (context, loginVM, child) {
                return ElevatedButton(
                  onPressed: loginVM.isLoading ? null : () => _handleForgotPassword(
                      context, formKey, emailController, loginVM),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimaryColor,
                  ),
                  child: loginVM.isLoading
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                      : const Text('Enviar'),
                );
              },
            ),
          ],
        );
      },
    );
  }

  // Método para manejar el proceso de olvidar contraseña
  void _handleForgotPassword(
      BuildContext context,
      GlobalKey<FormState> formKey,
      TextEditingController emailController,
      LoginViewModel loginVM) async {

    if (!formKey.currentState!.validate()) return;

    final success = await loginVM.resetPassword(
      emailController.text.trim(),
    );

    if (context.mounted) {
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Se ha enviado un correo para restablecer su contraseña'
                : loginVM.errorMessage ?? 'Error al enviar el correo',
          ),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }
}