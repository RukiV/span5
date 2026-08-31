import 'dart:math';
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';
import '../core/auth_config.dart';

/// OutlookTokenManager: Hou die Microsoft/Outlook (MS Graph) token vir die
/// mobiele app, dieselfde rol as `sessionStorage.ms_access_token` in die web.
///
/// Die web-frontend stoor die Graph-token na 'n Outlook-aanmelding en gebruik
/// dit vir direkte MS Graph-kalenderoproepe. Hier doen ons dieselfde met
/// FlutterSecureStorage: die access token word gebêre en outomaties verfris
/// met die refresh token wanneer dit verval.
class OutlookTokenManager {
  OutlookTokenManager._();

  static final OutlookTokenManager instance = OutlookTokenManager._();

  static const _storage = FlutterSecureStorage();
  static const _keyAccessToken = 'ms_access_token';
  static const _keyRefreshToken = 'ms_refresh_token';
  static const _keyExpiry = 'ms_access_token_expiry';

  static const _authorizationEndpoint =
      'https://login.microsoftonline.com/common/oauth2/v2.0/authorize';
  static const _tokenEndpoint =
      'https://login.microsoftonline.com/common/oauth2/v2.0/token';
  static const _endSessionEndpoint =
      'https://login.microsoftonline.com/common/oauth2/v2.0/logout';

  final FlutterAppAuth _appAuth = const FlutterAppAuth();

  AuthorizationServiceConfiguration get _serviceConfiguration =>
      const AuthorizationServiceConfiguration(
        authorizationEndpoint: _authorizationEndpoint,
        tokenEndpoint: _tokenEndpoint,
        endSessionEndpoint: _endSessionEndpoint,
      );

  /// Hou die gefetchedte Graph-token in geheue om herhaalde secure-storage
  /// lees oor dieselfde sessie te vermy.
  String? _cachedAccessToken;

  /// Lê 'n volledige Outlook/Graph-aanmelding via die stelsel-webblaaier
  /// (ASWebAuthenticationSession / Custom Tabs) af en bêre die tokens.
  Future<bool> signIn() async {
    try {
      final result = await _appAuth.authorizeAndExchangeCode(
        AuthorizationTokenRequest(
          AuthConfig.clientId,
          AuthConfig.redirectUri,
          serviceConfiguration: _serviceConfiguration,
          scopes: AuthConfig.scopes,
          nonce: _generateNonce(),
        ),
      );
      await _persistTokens(result);
      return result.accessToken != null;
    } catch (e) {
      debugPrint('Outlook aanmelding misluk: $e');
      return false;
    }
  }

  /// Gee 'n geldige Graph-access token terug (verfris indien nodig),
  /// of null as die gebruiker nie via Outlook aangemeld is nie.
  Future<String?> getGraphAccessToken() async {
    if (_cachedAccessToken != null) return _cachedAccessToken;

    final access = await _storage.read(key: _keyAccessToken);
    if (access == null) return null;

    final refresh = await _storage.read(key: _keyRefreshToken);
    final expiryRaw = await _storage.read(key: _keyExpiry);
    final expiry = expiryRaw == null ? null : DateTime.tryParse(expiryRaw);

    if (expiry != null && expiry.isAfter(DateTime.now())) {
      _cachedAccessToken = access;
      return access;
    }

    if (refresh != null) {
      return _refreshAccessToken(refresh);
    }

    await signOut();
    return null;
  }

  Future<String?> _refreshAccessToken(String refreshToken) async {
    try {
      final result = await _appAuth.token(
        TokenRequest(
          AuthConfig.clientId,
          AuthConfig.redirectUri,
          serviceConfiguration: _serviceConfiguration,
          scopes: AuthConfig.scopes,
          refreshToken: refreshToken,
        ),
      );
      if (result.accessToken == null) return null;
      await _persistTokens(result);
      return result.accessToken;
    } catch (e) {
      debugPrint('Outlook token verfris misluk: $e');
      await signOut();
      return null;
    }
  }

  Future<void> _persistTokens(TokenResponse result) async {
    if (result.accessToken != null) {
      await _storage.write(key: _keyAccessToken, value: result.accessToken!);
      _cachedAccessToken = result.accessToken;
    }
    if (result.refreshToken != null) {
      await _storage.write(key: _keyRefreshToken, value: result.refreshToken!);
    }
    if (result.accessTokenExpirationDateTime != null) {
      await _storage.write(
        key: _keyExpiry,
        value: result.accessTokenExpirationDateTime!.toIso8601String(),
      );
    }
  }

  /// Vee die Outlook-tokens uit (word op uitlog geroep).
  Future<void> signOut() async {
    _cachedAccessToken = null;
    await _storage.delete(key: _keyAccessToken);
    await _storage.delete(key: _keyRefreshToken);
    await _storage.delete(key: _keyExpiry);
  }

  String _generateNonce() {
    final rnd = Random.secure();
    final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}
