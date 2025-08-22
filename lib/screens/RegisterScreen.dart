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

class _RegisterScreenState extends State<RegisterScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  late RegisterViewModel _registerViewModel;
  late AnimationController _animationController;
  late AnimationController _logoAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;
  late Animation<double> _logoAnimation;

  @override
  void initState() {
    super.initState();
    _registerViewModel = RegisterViewModel();

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
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _registerViewModel.dispose();
    _animationController.dispose();
    _logoAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authViewModel = Provider.of<AuthViewModel>(context);

    return ChangeNotifierProvider.value(
        value: _registerViewModel,
        child: Scaffold(
        body: Container(
        decoration: backgroundDecoration, // Usando el fondo blanco de constants.dart
        child: Container(
        decoration: BoxDecoration(
        gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
        Colors.white.withOpacity(0.8),
    Colors.white.withOpacity(0.9),
    kPrimaryColor.withOpacity(0.05),
    ],
    ),
    ),
    child: SafeArea(
    child: Column(
    children: [
    // Header con botón de regreso
    Padding(
    padding: const EdgeInsets.all(16.0),
    child: Row(
    children: [
    Container(
    decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(12),
    boxShadow: [
    BoxShadow(
    color: Colors.black.withOpacity(0.1),
    blurRadius: 8,
    offset: const Offset(0, 2),
    ),
    ],
    ),
    child: IconButton(
    onPressed: () => Navigator.of(context).pop(),
    icon: const Icon(Icons.arrow_back_ios_new, color: kPrimaryColor),
    ),
    ),
    const Expanded(
    child: Text(
    'Crear Cuenta',
    style: TextStyle(
    color: kPrimaryColor,
    fontSize: 18,
    fontWeight: FontWeight.bold,
    ),
    textAlign: TextAlign.center,
    ),
    ),
    const SizedBox(width: 48), // Para centrar el título
    ],
    ),
    ),

    // Contenido principal
    Expanded(
    child: SingleChildScrollView(
    padding: const EdgeInsets.symmetric(horizontal: 32.0),
    child: Consumer<RegisterViewModel>(
    builder: (context, registerVM, child) {
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
    height: 100,
    margin: const EdgeInsets.only(bottom: 30),
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
    'Únete a LumVida',
    style: TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: kPrimaryColor,
    letterSpacing: 1.2,
    ),
    textAlign: TextAlign.center,
    ),
    const SizedBox(height: 8),
    Text(
    'Crea tu cuenta para reportar problemas urbanos',
    style: TextStyle(
    fontSize: 14,
    color: Colors.grey.shade600,
    fontWeight: FontWeight.w400,
    ),
    textAlign: TextAlign.center,
    ),
    const SizedBox(height: 30),
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
    // Campo de nombre
    _buildModernTextField(
    controller: _nameController,
    label: 'Nombre completo',
    icon: Icons.person_outlined,
    textCapitalization: TextCapitalization.words,
    validator: registerVM.validateName,
    onChanged: (value) {
    if (registerVM.errorMessage != null) {
    registerVM.clearError();
    }
    },
    ),

    const SizedBox(height: 16),

    // Campo de email
    _buildModernTextField(
    controller: _emailController,
    label: 'Correo electrónico',
    icon: Icons.email_outlined,
    keyboardType: TextInputType.emailAddress,
    validator: registerVM.validateEmail,
    onChanged: (value) {
    if (registerVM.errorMessage != null) {
    registerVM.clearError();
    }
    },
    ),

    const SizedBox(height: 16),

    // Campo de teléfono
    _buildModernTextField(
    controller: _phoneController,
    label: 'Teléfono (10 dígitos)',
    icon: Icons.phone_outlined,
    keyboardType: TextInputType.phone,
    validator: registerVM.validatePhone,
    onChanged: (value) {
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
    _buildModernTextField(
    controller: _passwordController,
    label: 'Contraseña',
    icon: Icons.lock_outlined,
    isPassword: true,
    obscureText: registerVM.obscurePassword,
    suffixIcon: IconButton(
    icon: Icon(
    registerVM.obscurePassword
    ? Icons.visibility_off_outlined
        : Icons.visibility_outlined,
    color: Colors.grey.shade600,
    ),
    onPressed: registerVM.togglePasswordVisibility,
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
    _buildModernTextField(
    controller: _confirmPasswordController,
    label: 'Confirmar contraseña',
    icon: Icons.lock_outline,
    isPassword: true,
    obscureText: registerVM.obscureConfirmPassword,
    suffixIcon: IconButton(
    icon: Icon(
    registerVM.obscureConfirmPassword
    ? Icons.visibility_off_outlined
        : Icons.visibility_outlined,
    color: Colors.grey.shade600,
    ),
    onPressed: registerVM.toggleConfirmPasswordVisibility,
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
    registerVM.errorMessage!,
    style: TextStyle(
    color: Colors.red.shade700,
    fontSize: 14,
    ),
    ),
    ),
    ],
    ),
    ),

    // Botón de registro
    _buildModernButton(
    onPressed: (registerVM.isLoading || registerVM.isProcessingGoogle)
    ? null
        : () => _handleEmailPasswordRegister(context, authViewModel, registerVM),
    isLoading: registerVM.isLoading,
    child: const Text(
    'Crear Cuenta',
    style: TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: Colors.white,
    ),
    ),
    ),

    const SizedBox(height: 20),

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
    'O regístrate con',
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

    const SizedBox(height: 20),

    // Botón de Google
    _buildGoogleButton(
    onPressed: (registerVM.isLoading || registerVM.isProcessingGoogle)
    ? null
        : () => _handleGoogleRegister(context, authViewModel, registerVM),
    isLoading: registerVM.isProcessingGoogle,
    ),

    const SizedBox(height: 24),

    // Ya tienes cuenta
    RichText(
    textAlign: TextAlign.center,
    text: TextSpan(
    text: '¿Ya tienes una cuenta? ',
    style: TextStyle(
    color: Colors.grey.shade700,
    fontSize: 14,
    ),
    children: [
    TextSpan(
    text: 'Inicia sesión',
    style: const TextStyle(
    color: kPrimaryColor,
    fontWeight: FontWeight.w600,
    ),
    recognizer: TapGestureRecognizer()
    ..onTap = () {
    Navigator.of(context).pop();
    },
    ),
    ],
    ),
    ),

    const SizedBox(height: 20),
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
    ],
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
    TextCapitalization? textCapitalization,
    String? Function(String?)? validator,
    Function(String)? onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        textCapitalization: textCapitalization ?? TextCapitalization.none,
        obscureText: obscureText,
        validator: validator,
        onChanged: onChanged,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: kPrimaryColor.withOpacity(0.7)),
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
            borderSide: BorderSide(color: kPrimaryColor, width: 2),
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
            color: kPrimaryColor.withOpacity(0.3),
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
            color: Colors.black.withOpacity(0.04),
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
      await authViewModel.checkAuthState();
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Text(
                '¡Cuenta creada exitosamente!',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 3),
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
      await authViewModel.checkAuthState();
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Text(
                'Registro con Google exitoso',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 3),
        ),
      );
    } else if (mounted && registerVM.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(registerVM.errorMessage!),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }
}