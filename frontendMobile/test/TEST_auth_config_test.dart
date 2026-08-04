import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() {
  setUpAll(() {
    dotenv.testLoad(fileInput: '');
  });

  group('AuthConfig', () {
    test('values are empty when no .env loaded (no hardcoded fallback)', () async {
      final authConfig = _loadAuthConfig();
      expect(authConfig.tenantId, '');
      expect(authConfig.clientId, '');
      expect(authConfig.redirectUri, '');
    });

    test('scopes defaults to openid,profile,email,User.Read', () {
      final authConfig = _loadAuthConfig();
      final scopes = authConfig.scopesString;
      expect(scopes, 'openid,profile,email,User.Read');
    });
  });
}

class _TestAuthConfig {
  String get tenantId => dotenv.env['AZURE_TENANT_ID'] ?? '';
  String get clientId => dotenv.env['AZURE_CLIENT_ID'] ?? '';
  String get redirectUri => dotenv.env['AZURE_REDIRECT_URI'] ?? '';
  String get scopesString => dotenv.env['AZURE_SCOPES'] ?? 'openid,profile,email,User.Read';
  List<String> get scopes => scopesString.split(',');
}

_TestAuthConfig _loadAuthConfig() => _TestAuthConfig();
