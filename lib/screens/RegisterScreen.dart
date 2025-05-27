import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/gestures.dart';
import '../utils/constants.dart';
import '../viewmodels/AuthViewModel.dart';
import '../viewmodels/RegisterViewModel.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({Key? key}) : super(key: key);

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  late RegisterViewModel _registerViewModel;

  @override
  void initState() {
    super.initState();
    _registerViewModel = RegisterViewModel();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _registerViewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authViewModel = Provider.of<AuthViewModel>(context);

    return ChangeNotifierProvider.value(
      value: _registerViewModel,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: kPrimaryColor),
          title: const Text(
            'Crear Cuenta',
            style: TextStyle(color: kPrimaryColor),
          ),
        ),
        body: Container(
          decoration: backgroundDecoration,
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Consumer<RegisterViewModel>(
                  builder: (context, registerVM, child) {
                    return Form(
                      key: _formKey,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Logo o título
                          const Center(
                            child: Text(
                              "LumVida",
                              style: TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.bold,
                                color: kPrimaryColor,
                              ),
                            ),
                          ),
                          const SizedBox(height: 30),

                          // Título
                          const Text(
                            'Regístrate',
                            style: kTitleStyle,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 10),

                          const Text(
                            'Crea una cuenta para reportar problemas urbanos',
                            style: kSubtitleStyle,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 30),

                          // Campo de nombre
                          TextFormField(
                            controller: _nameController,
                            keyboardType: TextInputType.text,
                            textCapitalization: TextCapitalization.words,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: Colors.white,
                              labelText: 'Nombre completo',
                              labelStyle: TextStyle(color: Colors.grey.shade700),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none,
                              ),
                              prefixIcon: const Icon(Icons.person, color: kPrimaryColor),
                            ),
                            validator: registerVM.validateName,
                            onChanged: (value) {
                              if (registerVM.errorMessage != null) {
                                registerVM.clearError();
                              }
                            },
                          ),

                          const SizedBox(height: 16),

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
                            validator: registerVM.validateEmail,
                            onChanged: (value) {
                              if (registerVM.errorMessage != null) {
                                registerVM.clearError();
                              }
                            },
                          ),

                          const SizedBox(height: 16),

                          // Campo de teléfono
                          TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: Colors.white,
                              labelText: 'Teléfono (10 dígitos)',
                              labelStyle: TextStyle(color: Colors.grey.shade700),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none,
                              ),
                              prefixIcon: const Icon(Icons.phone, color: kPrimaryColor),
                              helperText: 'Ejemplo: 5512345678',
                            ),
                            validator: registerVM.validatePhone,
                            onChanged: (value) {
                              // Formatear teléfono usando el ViewModel
                              final formattedValue = registerVM.formatPhone(value);
                              if (formattedValue != value) {
                                _phoneController.text = formattedValue;
                                _phoneController.selection = TextSelection.fromPosition(
                                  TextPosition(offset: formattedValue.length),
                                );
                              }

                              if (registerVM.errorMessage != null) {
                                registerVM.clearError();
                              }
                            },
                          ),

                          const SizedBox(height: 16),

                          // Campo de contraseña
                          TextFormField(
                            controller: _passwordController,
                            obscureText: registerVM.obscurePassword,
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
                                  registerVM.obscurePassword ? Icons.visibility_off : Icons.visibility,
                                  color: Colors.grey.shade600,
                                ),
                                onPressed: registerVM.togglePasswordVisibility,
                              ),
                              helperText: 'Mínimo 6 caracteres',
                            ),
                            validator: registerVM.validatePassword,
                            onChanged: (value) {
                              if (registerVM.errorMessage != null) {
                                registerVM.clearError();
                              }
                            },
                          ),

                          const SizedBox(height: 16),

                          // Campo de confirmar contraseña
                          TextFormField(
                            controller: _confirmPasswordController,
                            obscureText: registerVM.obscureConfirmPassword,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: Colors.white,
                              labelText: 'Confirmar contraseña',
                              labelStyle: TextStyle(color: Colors.grey.shade700),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none,
                              ),
                              prefixIcon: const Icon(Icons.lock_outline, color: kPrimaryColor),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  registerVM.obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                                  color: Colors.grey.shade600,
                                ),
                                onPressed: registerVM.toggleConfirmPasswordVisibility,
                              ),
                            ),
                            validator: (value) => registerVM.validateConfirmPassword(value, _passwordController.text),
                            onChanged: (value) {
                              if (registerVM.errorMessage != null) {
                                registerVM.clearError();
                              }
                            },
                          ),

                          const SizedBox(height: 24),

                          // Mensaje de error
                          if (registerVM.errorMessage != null)
                            Container(
                              padding: const EdgeInsets.all(10),
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: Colors.red.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                registerVM.errorMessage!,
                                style: TextStyle(color: Colors.red.shade800),
                                textAlign: TextAlign.center,
                              ),
                            ),

                          // Botón de registro
                          ElevatedButton(
                            onPressed: (registerVM.isLoading || registerVM.isProcessingGoogle)
                                ? null
                                : () => _handleEmailPasswordRegister(context, authViewModel, registerVM),
                            style: kPrimaryButtonStyle,
                            child: registerVM.isLoading
                                ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                                : const Text(
                              'Crear cuenta',
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
                            onPressed: (registerVM.isLoading || registerVM.isProcessingGoogle)
                                ? null
                                : () => _handleGoogleRegister(context, authViewModel, registerVM),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: kPrimaryColor,
                              side: const BorderSide(color: kPrimaryColor),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            icon: registerVM.isProcessingGoogle
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
                              'Registrarse con Google',
                              style: kButtonTextStyle,
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Ya tienes cuenta
                          Center(
                            child: RichText(
                              text: TextSpan(
                                text: '¿Ya tienes una cuenta? ',
                                style: TextStyle(color: Colors.grey.shade700),
                                children: [
                                  TextSpan(
                                    text: 'Inicia sesión',
                                    style: const TextStyle(
                                      color: kPrimaryColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    recognizer: TapGestureRecognizer()
                                      ..onTap = () {
                                        Navigator.of(context).pop();
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

  // Método para manejar el registro con email y contraseña
  void _handleEmailPasswordRegister(
      BuildContext context,
      AuthViewModel authViewModel,
      RegisterViewModel registerVM) async {

    if (!_formKey.currentState!.validate()) return;

    final success = await registerVM.registerWithEmailAndPassword(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      name: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
    );

    if (success && mounted) {
      // Actualizar el AuthViewModel
      await authViewModel.checkAuthState();

      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Cuenta creada exitosamente!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  // Método para manejar el registro con Google
  void _handleGoogleRegister(
      BuildContext context,
      AuthViewModel authViewModel,
      RegisterViewModel registerVM) async {

    final success = await registerVM.signInWithGoogle();

    if (success && mounted) {
      // Actualizar el AuthViewModel
      await authViewModel.checkAuthState();

      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ingreso con Google exitoso'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    } else if (mounted && registerVM.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(registerVM.errorMessage!),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}