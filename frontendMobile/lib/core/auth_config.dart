import 'package:flutter_dotenv/flutter_dotenv.dart';

class AuthConfig {
  // Ons verwyder die hardgekodeerde fallbacks. 
  // Die app sal nou slegs werk as die .env lêer korrek opgestel is.
  
  static String get clientId => dotenv.get('AZURE_CLIENT_ID', fallback: '');
  
  static String get tenantId => dotenv.get('AZURE_TENANT_ID', fallback: 'common'); 
  
  static String get redirectUri => dotenv.get('AZURE_REDIRECT_URI', fallback: '');

  static List<String> get scopes {
    final scopesStr = dotenv.get('AZURE_SCOPES', fallback: 'openid,profile,User.Read');
    return scopesStr.split(',');
  }

  // 'n Helper om te kyk of die konfigurasie gelaai is
  static bool get isValid => clientId.isNotEmpty && redirectUri.isNotEmpty;
}
