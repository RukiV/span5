<<<<<<< HEAD
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
=======
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// AuthConfig: Sentrale konfigurasie vir Microsoft OAuth integrasie.
class AuthConfig {
  // Gebruik jou spesifieke Tenant ID en Client ID vanaf .env, of die hardgekodeerde valsbaie
  static String get tenantId => dotenv.env['AZURE_TENANT_ID'] ?? '49c8f005-73ef-462e-99e7-7be3a22980eb';
  static String get clientId => dotenv.env['AZURE_CLIENT_ID'] ?? 'ee909cd4-2fae-4cd2-8d7e-da7e8508d772';
  
  // Hierdie MOET presies ooreenstem met die Azure Portal en AndroidManifest.xml
  // Ons gebruik die hash-weergawe as die absolute verstek.
  static String get redirectUri => dotenv.env['AZURE_REDIRECT_URI'] ?? 'msauth://com.example.untitled/xc13Rb9XZfaL0EqEJWzx78ijaeM%3D';
  
  static const List<String> scopes = [
    'openid',
    'profile',
    'email',
    'User.Read',
  ];
}
>>>>>>> 3080162a6b51675de2ce74fa53f3bd629f39db17
