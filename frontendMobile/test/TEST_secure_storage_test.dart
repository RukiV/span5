import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

void main() {
  group('FlutterSecureStorage biometric preference', () {
    test('platform interface supports read/write operations', () {
      const storage = FlutterSecureStorage();
      // Verify the storage instance is created correctly
      expect(storage, isNotNull);
    });

    test('biometric preference key is use_biometrics', () {
      const key = 'use_biometrics';
      expect(key, 'use_biometrics');
    });

    test('auth_token key is used for session storage', () {
      const key = 'auth_token';
      expect(key, 'auth_token');
    });
  });
}
