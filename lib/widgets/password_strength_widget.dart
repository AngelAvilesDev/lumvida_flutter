// widgets/password_strength_widget.dart
import 'package:flutter/material.dart';
import '../utils/error_messages.dart';

class PasswordStrengthWidget extends StatelessWidget {
  final String password;
  final bool showTips;

  const PasswordStrengthWidget({
    Key? key,
    required this.password,
    this.showTips = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (password.isEmpty) return const SizedBox.shrink();

    final strength = AuthErrorMessages.getPasswordStrength(password);
    final tips = AuthErrorMessages.getPasswordTips(password);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),

        // Indicador visual de fortaleza
        Row(
          children: [
            const Text(
              'Seguridad: ',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
            Text(
              strength.text,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(strength.colorValue),
              ),
            ),
            const Spacer(),
            _buildStrengthBars(strength),
          ],
        ),

        const SizedBox(height: 8),

        // Barra de progreso
        LinearProgressIndicator(
          value: _getProgressValue(strength),
          backgroundColor: Colors.grey.shade200,
          valueColor: AlwaysStoppedAnimation<Color>(
            Color(strength.colorValue),
          ),
          minHeight: 3,
        ),

        // Consejos para mejorar (si hay)
        if (showTips && tips.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.lightbulb_outline,
                      size: 16,
                      color: Colors.blue.shade600,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Para mejorar tu contraseña:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...tips.map((tip) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    tip,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.blue.shade700,
                    ),
                  ),
                )),
              ],
            ),
          ),
        ],

        // Mensaje de contraseña fuerte
        if (strength == PasswordStrength.strong || strength == PasswordStrength.veryStrong) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 16,
                  color: Colors.green.shade600,
                ),
                const SizedBox(width: 8),
                Text(
                  '¡Excelente! Tu contraseña es segura',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.green.shade800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // Construir barras de fortaleza
  Widget _buildStrengthBars(PasswordStrength strength) {
    final strengthLevel = _getStrengthLevel(strength);

    return Row(
      children: List.generate(5, (index) {
        return Container(
          width: 12,
          height: 4,
          margin: const EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(
            color: index < strengthLevel
                ? Color(strength.colorValue)
                : Colors.grey.shade300,
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  }

  // Obtener nivel numérico de fortaleza
  int _getStrengthLevel(PasswordStrength strength) {
    switch (strength) {
      case PasswordStrength.veryWeak:
        return 1;
      case PasswordStrength.weak:
        return 2;
      case PasswordStrength.medium:
        return 3;
      case PasswordStrength.strong:
        return 4;
      case PasswordStrength.veryStrong:
        return 5;
    }
  }

  // Obtener valor de progreso
  double _getProgressValue(PasswordStrength strength) {
    switch (strength) {
      case PasswordStrength.veryWeak:
        return 0.2;
      case PasswordStrength.weak:
        return 0.4;
      case PasswordStrength.medium:
        return 0.6;
      case PasswordStrength.strong:
        return 0.8;
      case PasswordStrength.veryStrong:
        return 1.0;
    }
  }
}

// Widget simplificado para confirmación de contraseña
class PasswordMatchWidget extends StatelessWidget {
  final String password;
  final String confirmPassword;

  const PasswordMatchWidget({
    Key? key,
    required this.password,
    required this.confirmPassword,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (confirmPassword.isEmpty) return const SizedBox.shrink();

    final isMatch = password == confirmPassword;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Icon(
            isMatch ? Icons.check_circle : Icons.cancel,
            size: 16,
            color: isMatch ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 8),
          Text(
            isMatch ? 'Las contraseñas coinciden' : 'Las contraseñas no coinciden',
            style: TextStyle(
              fontSize: 12,
              color: isMatch ? Colors.green.shade700 : Colors.red.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}