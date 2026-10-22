import 'package:flutter_test/flutter_test.dart';

import '../lib/features/auth/validators/auth_validators.dart';

void main() {
  group('AuthValidators.phone', () {
    test('accepts a local Yemeni phone number', () {
      expect(AuthValidators.phone('777123456'), isNull);
    });

    test('accepts a formatted international phone number', () {
      expect(AuthValidators.phone('+967 (777) 123-456'), isNull);
    });

    test('rejects too-short, alphabetic, and empty values', () {
      expect(AuthValidators.phone('12345'), isNotNull);
      expect(AuthValidators.phone('phone777123456'), isNotNull);
      expect(AuthValidators.phone('   '), isNotNull);
    });
  });
}
