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
    'Calendars.ReadWrite',
  ];
}
