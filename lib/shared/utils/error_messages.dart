// utils/error_messages.dart
class AuthErrorMessages {
  // Errores de autenticación específicos
  static const Map<String, String> _firebaseErrors = {
    // Errores de Login
    'user-not-found': 'El correo electrónico no está registrado.',
    'wrong-password': 'La contraseña ingresada es incorrecta.',
    'invalid-email': 'El formato del correo electrónico no es válido.',
    'user-disabled': 'Esta cuenta ha sido deshabilitada.',
    'too-many-requests': 'Demasiados intentos fallidos. Inténtalo más tarde.',
    'invalid-credential': 'Las credenciales son inválidas. Verifica tu correo y contraseña.',
    'account-exists-with-different-credential': 'Ya existe una cuenta con este correo usando un método de acceso diferente.',

    // Errores de Registro
    'email-already-in-use': 'Este correo electrónico ya está registrado.',
    'weak-password': 'La contraseña es muy débil. Debe tener al menos 8 caracteres.',
    'operation-not-allowed': 'El registro con correo y contraseña no está habilitado.',

    // Errores de Google Sign-In
    'popup-closed-by-user': 'El proceso de autenticación con Google fue cancelado.',
    'popup-blocked': 'El navegador bloqueó la ventana de Google. Permite ventanas emergentes.',
    'cancelled': 'El proceso de autenticación fue cancelado.',
    'network-request-failed': 'Error de conexión. Verifica tu conexión a internet.',

    // Errores de Reset Password - AMPLIADOS
    'user-not-found-reset': 'No existe ninguna cuenta con este correo electrónico.',
    'invalid-action-code': 'El enlace de restablecimiento no es válido o ha expirado.',
    'expired-action-code': 'El enlace de restablecimiento ha expirado.',
    'invalid-continue-uri': 'URL de configuración inválida.',
    'unauthorized-continue-uri': 'URL de configuración no autorizada.',
    'missing-continue-uri': 'Falta la URL de continuación en la configuración.',
    'auth/configuration-not-found': 'Error de configuración del servicio. Contacta al soporte técnico.',
    'auth/user-disabled': 'Esta cuenta ha sido deshabilitada.',
    'missing-email': 'El correo electrónico es requerido.',
    'quota-exceeded': 'Se ha excedido el límite de solicitudes de restablecimiento. Intenta más tarde.',
    'email-not-found': 'No se encontró una cuenta asociada con este correo electrónico.',
    'reset-password-exceed-limit': 'Has excedido el límite de intentos de restablecimiento. Intenta en una hora.',

    // Errores generales
    'network-error': 'Error de conexión. Verifica tu conexión a internet.',
    'internal-error': 'Error interno del servidor. Inténtalo más tarde.',
    'timeout': 'La operación tardó demasiado tiempo. Inténtalo de nuevo.',
  };

  // Errores de validación de formularios
  static const Map<String, String> _validationErrors = {
    'empty-email': 'Por favor ingresa tu correo electrónico',
    'invalid-email': 'Ingresa un correo electrónico válido',
    'empty-password': 'Por favor ingresa tu contraseña',
    'weak-password': 'La contraseña debe tener al menos 8 caracteres',
    'password-no-uppercase': 'La contraseña debe contener al menos una mayúscula',
    'password-no-lowercase': 'La contraseña debe contener al menos una minúscula',
    'password-no-number': 'La contraseña debe contener al menos un número',
    'password-no-special': 'La contraseña debe contener al menos un carácter especial (!@#\$&*~)',
    'password-has-spaces': 'La contraseña no puede contener espacios',
    'password-too-common': 'Esta contraseña es muy común. Elige una más segura',
    'empty-name': 'Por favor ingresa tu nombre completo',
    'short-name': 'El nombre debe tener al menos 2 caracteres',
    'empty-phone': 'Por favor ingresa tu número de teléfono',
    'invalid-phone': 'El teléfono debe tener exactamente 10 dígitos',
    'passwords-not-match': 'Las contraseñas no coinciden',
    'empty-confirm-password': 'Por favor confirma tu contraseña',

    // Errores de reportes
    'empty-title': 'Por favor ingresa un título para el reporte',
    'short-title': 'El título debe tener al menos 5 caracteres',
    'empty-description': 'Por favor describe el problema',
    'short-description': 'La descripción debe tener al menos 10 caracteres',
    'empty-location': 'Por favor selecciona una ubicación',
    'empty-category': 'Por favor selecciona una categoría',
    'no-images': 'Por favor agrega al menos una imagen',
    'too-many-images': 'Máximo 5 imágenes permitidas',
  };

  // Método principal para obtener el mensaje de error
  static String getErrorMessage(String errorCode, {String? defaultMessage}) {
    // Primero buscar en errores de Firebase
    if (_firebaseErrors.containsKey(errorCode)) {
      return _firebaseErrors[errorCode]!;
    }

    // Luego buscar en errores de validación
    if (_validationErrors.containsKey(errorCode)) {
      return _validationErrors[errorCode]!;
    }

    // Intentar extraer el código de error de mensajes más complejos
    String cleanErrorCode = _extractErrorCode(errorCode);
    if (_firebaseErrors.containsKey(cleanErrorCode)) {
      return _firebaseErrors[cleanErrorCode]!;
    }

    // Retornar mensaje por defecto o genérico
    return defaultMessage ?? _getGenericErrorMessage(errorCode);
  }

  // Extraer código de error de mensajes complejos de Firebase
  static String _extractErrorCode(String error) {
    // Patrones comunes de errores de Firebase
    final patterns = [
      RegExp(r'\[firebase_auth/([^\]]+)\]'),
      RegExp(r'firebase_auth/([^\s]+)'),
      RegExp(r'ERROR_([A-Z_]+)'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(error);
      if (match != null && match.groupCount > 0) {
        return match.group(1)!.toLowerCase().replaceAll('_', '-');
      }
    }

    return error.toLowerCase();
  }

  // Mensaje de error genérico basado en el contexto
  static String _getGenericErrorMessage(String error) {
    final errorLower = error.toLowerCase();

    if (errorLower.contains('network') || errorLower.contains('internet')) {
      return 'Error de conexión. Verifica tu conexión a internet.';
    }

    if (errorLower.contains('timeout')) {
      return 'La operación tardó demasiado. Inténtalo de nuevo.';
    }

    if (errorLower.contains('server')) {
      return 'Error del servidor. Inténtalo más tarde.';
    }

    if (errorLower.contains('google')) {
      return 'Error con la autenticación de Google. Inténtalo de nuevo.';
    }

    if (errorLower.contains('reset') || errorLower.contains('password')) {
      return 'Error al procesar el restablecimiento de contraseña. Inténtalo de nuevo.';
    }

    return 'Ha ocurrido un error inesperado. Inténtalo de nuevo.';
  }

  // Métodos específicos para diferentes tipos de errores
  static String getLoginError(String errorCode) {
    return getErrorMessage(errorCode,
        defaultMessage: 'Datos no válidos, verifica tus credenciales.');
  }

  static String getRegisterError(String errorCode) {
    return getErrorMessage(errorCode,
        defaultMessage: 'Error al crear la cuenta. Inténtalo de nuevo.');
  }

  // MÉTODO MEJORADO para errores de restablecimiento de contraseña
  static String getResetPasswordError(String errorCode) {
    // Mapeo específico para reset password con contexto más claro
    final Map<String, String> resetPasswordSpecificErrors = {
      'user-not-found': 'No existe una cuenta registrada con este correo electrónico',
      'invalid-email': 'El formato del correo electrónico no es válido',
      'too-many-requests': 'Demasiados intentos de restablecimiento. Espera unos minutos antes de intentar nuevamente',
      'network-request-failed': 'Error de conexión. Verifica tu conexión a internet e intenta nuevamente',
      'auth/user-disabled': 'Esta cuenta ha sido deshabilitada',
      'auth/configuration-not-found': 'Error de configuración del servicio. Contacta al soporte técnico',
      'missing-email': 'El correo electrónico es requerido',
      'operation-not-allowed': 'El restablecimiento de contraseña no está habilitado',
      'invalid-action-code': 'El enlace de restablecimiento no es válido o ha expirado',
      'expired-action-code': 'El enlace de restablecimiento ha expirado',
      'invalid-continue-uri': 'URL de configuración inválida',
      'unauthorized-continue-uri': 'URL de configuración no autorizada',
      'quota-exceeded': 'Se ha excedido el límite de solicitudes. Intenta más tarde',
    };

    // Buscar primero en errores específicos de reset
    if (resetPasswordSpecificErrors.containsKey(errorCode)) {
      return resetPasswordSpecificErrors[errorCode]!;
    }

    // Luego usar el método general con mensaje por defecto personalizado
    return getErrorMessage(errorCode,
        defaultMessage: 'Error al enviar el correo de restablecimiento. Verifica el correo electrónico e intenta nuevamente');
  }

  static String getGoogleSignInError(String errorCode) {
    return getErrorMessage(errorCode,
        defaultMessage: 'Error con la autenticación de Google.');
  }

  static String getReportError(String errorCode) {
    return getErrorMessage(errorCode,
        defaultMessage: 'Error al crear el reporte. Inténtalo de nuevo.');
  }

  // Validadores con mensajes personalizados
  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return getErrorMessage('empty-email');
    }

    final emailRegex = RegExp(r'^[\w\.-]+@[\w\.-]+\.\w+$');
    if (!emailRegex.hasMatch(value.trim())) {
      return getErrorMessage('invalid-email');
    }

    return null;
  }

  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return getErrorMessage('empty-password');
    }

    // Validar longitud mínima
    if (value.length < 8) {
      return getErrorMessage('weak-password');
    }

    // Validar que no contenga espacios
    if (value.contains(' ')) {
      return getErrorMessage('password-has-spaces');
    }

    // Validar al menos una mayúscula
    if (!RegExp(r'[A-Z]').hasMatch(value)) {
      return getErrorMessage('password-no-uppercase');
    }

    // Validar al menos una minúscula
    if (!RegExp(r'[a-z]').hasMatch(value)) {
      return getErrorMessage('password-no-lowercase');
    }

    // Validar al menos un número
    if (!RegExp(r'\d').hasMatch(value)) {
      return getErrorMessage('password-no-number');
    }

    // Validar al menos un carácter especial
    if (!RegExp(r'[!@#\$&*~]').hasMatch(value)) {
      return getErrorMessage('password-no-special');
    }

    // Validar que no sea una contraseña común
    if (_isCommonPassword(value)) {
      return getErrorMessage('password-too-common');
    }

    return null;
  }

  // Validador más permisivo para login (solo longitud)
  static String? validateLoginPassword(String? value) {
    if (value == null || value.isEmpty) {
      return getErrorMessage('empty-password');
    }

    if (value.length < 8) {
      return 'La contraseña debe tener al menos 8 caracteres';
    }

    return null;
  }

  static String? validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return getErrorMessage('empty-name');
    }

    if (value.trim().length < 2) {
      return getErrorMessage('short-name');
    }

    return null;
  }

  static String? validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return getErrorMessage('empty-phone');
    }

    final phoneRegex = RegExp(r'^\d{10}$');
    final cleanPhone = value.replaceAll(RegExp(r'[^\d]'), '');

    if (!phoneRegex.hasMatch(cleanPhone)) {
      return getErrorMessage('invalid-phone');
    }

    return null;
  }

  static String? validateConfirmPassword(String? value, String password) {
    if (value == null || value.isEmpty) {
      return getErrorMessage('empty-confirm-password');
    }

    if (value != password) {
      return getErrorMessage('passwords-not-match');
    }

    return null;
  }

  // Validadores para reportes
  static String? validateReportTitle(String? value) {
    if (value == null || value.trim().isEmpty) {
      return getErrorMessage('empty-title');
    }

    if (value.trim().length < 5) {
      return getErrorMessage('short-title');
    }

    return null;
  }

  static String? validateReportDescription(String? value) {
    if (value == null || value.trim().isEmpty) {
      return getErrorMessage('empty-description');
    }

    if (value.trim().length < 10) {
      return getErrorMessage('short-description');
    }

    return null;
  }

  static String? validateReportLocation(String? value) {
    if (value == null || value.trim().isEmpty) {
      return getErrorMessage('empty-location');
    }

    return null;
  }

  static String? validateReportCategory(String? value) {
    if (value == null || value.trim().isEmpty) {
      return getErrorMessage('empty-category');
    }

    return null;
  }

  static String? validateReportImages(List<dynamic>? images) {
    if (images == null || images.isEmpty) {
      return getErrorMessage('no-images');
    }

    if (images.length > 5) {
      return getErrorMessage('too-many-images');
    }

    return null;
  }

  // Método para formatear teléfono
  static String formatPhone(String value) {
    final digitsOnly = value.replaceAll(RegExp(r'[^\d]'), '');
    if (digitsOnly.length > 10) {
      return digitsOnly.substring(0, 10);
    }
    return digitsOnly;
  }

  // Lista de contraseñas comunes a evitar
  static const List<String> _commonPasswords = [
    '12345678',
    'password',
    'password123',
    'qwerty123',
    'abc123456',
    '123456789',
    'password1',
    '12345abc',
    'qwerty12',
    'admin123',
    'letmein123',
    'welcome123',
    'monkey123',
    'dragon123',
    'master123',
    'shadow123',
  ];

  // Verificar si una contraseña es muy común
  static bool _isCommonPassword(String password) {
    final lowerPassword = password.toLowerCase();
    return _commonPasswords.any((common) =>
    lowerPassword.contains(common) ||
        lowerPassword == common ||
        _calculateSimilarity(lowerPassword, common) > 0.8
    );
  }

  // Calcular similitud entre strings (algoritmo simple)
  static double _calculateSimilarity(String s1, String s2) {
    if (s1 == s2) return 1.0;
    if (s1.isEmpty || s2.isEmpty) return 0.0;

    int matches = 0;
    int minLength = s1.length < s2.length ? s1.length : s2.length;

    for (int i = 0; i < minLength; i++) {
      if (s1[i] == s2[i]) matches++;
    }

    return matches / minLength;
  }

  // Obtener nivel de seguridad de la contraseña
  static PasswordStrength getPasswordStrength(String password) {
    if (password.isEmpty) {
      return PasswordStrength.veryWeak;
    }

    int score = 0;

    // Longitud
    if (password.length >= 8) score++;
    if (password.length >= 12) score++;

    // Mayúsculas
    if (RegExp(r'[A-Z]').hasMatch(password)) score++;

    // Minúsculas
    if (RegExp(r'[a-z]').hasMatch(password)) score++;

    // Números
    if (RegExp(r'\d').hasMatch(password)) score++;

    // Caracteres especiales
    if (RegExp(r'[!@#\$&*~]').hasMatch(password)) score++;

    // No contiene espacios
    if (!password.contains(' ')) score++;

    // No es común
    if (!_isCommonPassword(password)) score++;

    // Evaluar puntaje
    if (score <= 2) return PasswordStrength.veryWeak;
    if (score <= 4) return PasswordStrength.weak;
    if (score <= 6) return PasswordStrength.medium;
    if (score <= 7) return PasswordStrength.strong;
    return PasswordStrength.veryStrong;
  }

  // Obtener consejos para mejorar la contraseña
  static List<String> getPasswordTips(String password) {
    List<String> tips = [];

    if (password.length < 8) {
      tips.add('• Debe tener al menos 8 caracteres');
    }

    if (!RegExp(r'[A-Z]').hasMatch(password)) {
      tips.add('• Agrega al menos una letra mayúscula');
    }

    if (!RegExp(r'[a-z]').hasMatch(password)) {
      tips.add('• Agrega al menos una letra minúscula');
    }

    if (!RegExp(r'\d').hasMatch(password)) {
      tips.add('• Agrega al menos un número');
    }

    if (!RegExp(r'[!@#\$&*~]').hasMatch(password)) {
      tips.add('• Agrega un carácter especial (!@#\$&*~)');
    }

    if (password.contains(' ')) {
      tips.add('• No debe contener espacios');
    }

    if (_isCommonPassword(password)) {
      tips.add('• Evita contraseñas comunes');
    }

    return tips;
  }
}

// Enum para niveles de seguridad de contraseña
enum PasswordStrength {
  veryWeak,
  weak,
  medium,
  strong,
  veryStrong,
}

// Extensión para obtener color y texto del nivel de seguridad
extension PasswordStrengthExtension on PasswordStrength {
  String get text {
    switch (this) {
      case PasswordStrength.veryWeak:
        return 'Muy débil';
      case PasswordStrength.weak:
        return 'Débil';
      case PasswordStrength.medium:
        return 'Regular';
      case PasswordStrength.strong:
        return 'Fuerte';
      case PasswordStrength.veryStrong:
        return 'Muy fuerte';
    }
  }

  int get colorValue {
    switch (this) {
      case PasswordStrength.veryWeak:
        return 0xFFE53E3E; // Rojo
      case PasswordStrength.weak:
        return 0xFFDD6B20; // Naranja
      case PasswordStrength.medium:
        return 0xFFD69E2E; // Amarillo
      case PasswordStrength.strong:
        return 0xFF38A169; // Verde claro
      case PasswordStrength.veryStrong:
        return 0xFF2F855A; // Verde oscuro
    }
  }
}