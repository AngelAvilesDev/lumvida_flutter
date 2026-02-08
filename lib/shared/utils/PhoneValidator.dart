
import 'package:flutter/foundation.dart';

class PhoneValidator {
  // LADAs permitidas para escalabilidad
  static const List<String> validLadas = ['998', '984', '983'];

  // Secuencias no permitidas
  static const List<String> _invalidSequences = [
    '0123456789',
    '1234567890',
    '0987654321',
    '9876543210'
  ];

  static bool isValid(String phone) {
    if (phone.isEmpty) return false;

    // 1. Longitud básica y solo dígitos. Permitimos que el input venga con formato
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d]'), '');
    
    // Debe tener exactamente 10 dígitos.
    final phoneRegex = RegExp(r'^\d{10}$');
    if (!phoneRegex.hasMatch(cleanPhone)) {
      if (kDebugMode) print('Phone validation failed: Invalid length or characters ($cleanPhone)');
      return false;
    }

    // 2. Verificar LADA válida
    final lada = cleanPhone.substring(0, 3);
    if (!validLadas.contains(lada)) {
      if (kDebugMode) print('Phone validation failed: Invalid LADA ($lada)');
      return false;
    }
    
    // 3. No iniciar con 0 o 1 (redundante si validamos LADA, pero buena práctica)
    if (cleanPhone.startsWith('0') || cleanPhone.startsWith('1')) {
       if (kDebugMode) print('Phone validation failed: Starts with 0 or 1');
      return false;
    }

    // 4. No todos los dígitos iguales
    if (RegExp(r'^(.)\1*$').hasMatch(cleanPhone)) {
       if (kDebugMode) print('Phone validation failed: All digits are the same');
      return false;
    }

    // 5. No secuencias ascendentes o descendentes
    if (_invalidSequences.contains(cleanPhone)) {
       if (kDebugMode) print('Phone validation failed: Invalid sequence');
      return false;
    }

    return true;
  }
}
