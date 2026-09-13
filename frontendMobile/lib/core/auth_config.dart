import 'package:flutter_dotenv/flutter_dotenv.dart';

/// AuthConfig: Sentrale konfigurasie vir Microsoft OAuth integrasie.
///
/// Alle sensitiewe waardes word UITSLUITEND vanaf die .env gelaai.
/// Geen hardgekodeerde valsbaie nie — as die .env nie gestel is nie,
/// moet die app nie probeer om met Azure te skakel nie.
class AuthConfig {
  static String get tenantId =>
      dotenv.env['AZURE_TENANT_ID'] ?? '';
  static String get clientId =>
      dotenv.env['AZURE_CLIENT_ID'] ?? '';
  static String get redirectUri =>
      dotenv.env['AZURE_REDIRECT_URI'] ?? '';
  static String get scopesString =>
      dotenv.env['AZURE_SCOPES'] ?? 'openid,profile,email,User.Read,Calendars.ReadWrite,offline_access';

  static List<String> get scopes => scopesString.split(',');
}