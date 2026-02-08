import 'package:flutter_test/flutter_test.dart';
import 'package:lumvida_app/shared/utils/PhoneValidator.dart';

void main() {
  group('PhoneValidator Tests', () {
    test('Valid phones should pass', () {
      expect(PhoneValidator.isValid('9981234567'), true, reason: 'Cancún LADA');
      expect(PhoneValidator.isValid('9841234567'), true, reason: 'Playa del Carmen LADA');
      expect(PhoneValidator.isValid('9831234567'), true, reason: 'Chetumal LADA');
    });

    test('Phones with formatting should pass', () {
      expect(PhoneValidator.isValid('(998) 123-4567'), true);
      expect(PhoneValidator.isValid('998-123-4567'), true);
      expect(PhoneValidator.isValid('998 123 4567'), true);
    });

    test('Invalid length should fail', () {
      expect(PhoneValidator.isValid('998'), false);
      expect(PhoneValidator.isValid('998123456'), false); // 9 digits
      expect(PhoneValidator.isValid('99812345678'), false); // 11 digits
    });

    test('Invalid LADA should fail', () {
      expect(PhoneValidator.isValid('5512345678'), false, reason: 'CDMX LADA not in list');
      expect(PhoneValidator.isValid('9991234567'), false, reason: 'Mérida LADA not in list');
    });

    test('Repeated digits should fail', () {
      expect(PhoneValidator.isValid('0000000000'), false);
      expect(PhoneValidator.isValid('1111111111'), false);
      expect(PhoneValidator.isValid('9999999999'), false);
    });

    test('Sequential digits should fail', () {
      expect(PhoneValidator.isValid('1234567890'), false);
      expect(PhoneValidator.isValid('0123456789'), false);
      expect(PhoneValidator.isValid('0987654321'), false);
      expect(PhoneValidator.isValid('9876543210'), false);
    });
    
    test('Starts with 0 or 1 should fail (redundant check but good coverage)', () {
       // These might fail LADA check first, but good to test specifically if logic changes
       // 098... would fail LADA and Sequence
       expect(PhoneValidator.isValid('0081234567'), false);
       expect(PhoneValidator.isValid('1981234567'), false);
    });
  });
}
