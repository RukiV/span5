import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user_session.dart';
import '../widgets/filter_utils.dart';
import '../widgets/sort_utils.dart';
import 'navigation.dart';

/// API-pad wat agter die bediener-oorsprong aangeheg word (bv. /api/v1).
const apiPath = '/api/v1';

/// ApiClient: Centralized network engine for the Akademia Facility Management System.
///
/// Enforces HTTPS and prevents common security pitfalls:
/// - All traffic is encrypted in transit (HTTPS enforced in base URL).
/// - Session tokens are stored in the platform's secure enclave (Keychain/Keystore).
/// - HTTP client is a singleton so there is exactly one point of configuration.
class ApiClient {
  static final ApiClient _instance = ApiClient._internal();

  static const _authTokenKey = 'auth_token';
  static const _refreshTokenKey = 'refresh_token';

  late final Dio _dio;
  final FlutterSecureStorage _storage;

  /// Fires true when a token is saved, false when cleared.
  static final authNotifier = ValueNotifier<bool>(false);

  factory ApiClient() => _instance;

  /// Toetse-slegs konstruktor: laat 'n fake secure-kas en/of 'n gemokte Dio
  /// inspuit sodat die token- en sessie-logika sonder 'n toestel getoets kan word.
  @visibleForTesting
  ApiClient.forTesting({FlutterSecureStorage? storage, Dio? dio})
      : _storage = storage ?? const FlutterSecureStorage() {
    if (dio != null) {
      _dio = dio;
    } else {
      _baseUrlFromDefaults();
    }
  }

  ApiClient._internal()
      : _storage = const FlutterSecureStorage() {
    _baseUrlFromDefaults();
  }

  void _baseUrlFromDefaults() {
    // Valbak-URL. Opstart lees die gestoorde bediener-URL (eerste-launch/
    // instellings) en pas dit asynchronies toe via setBaseUrl() sodat 'n enkele
    // APK met enige bediener (LAN-IP, tunnel-URL of domein) kan verbind.
    // Precedence op opstart: --dart-define=API_URL=... > .env API_URL > gestoorde URL > hardcoded.
    const dartDefineUrl = String.fromEnvironment('API_URL');
    final baseUrl = dartDefineUrl.isNotEmpty
        ? dartDefineUrl
        : dotenv.get('API_URL', fallback: 'http://10.12.0.128:8000/api/v1');
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'X-Client-Type': 'mobile',
        },
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _storage.read(key: _authTokenKey);
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (DioException e, handler) async {
          debugPrint("API ERROR [${e.response?.statusCode}] at ${e.requestOptions.path}");

          if (e.response?.statusCode == 401) {
            final refreshed = await _refreshSession();
            if (refreshed) {
              try {
                final response = await _retry(e.requestOptions);
                return handler.resolve(response);
              } catch (retryError) {
                return handler.next(retryError is DioException ? retryError : e);
              }
            } else {
              await clearToken();
              UserSession.clear();
              navigatorKey.currentState?.pushNamedAndRemoveUntil('/', (route) => false);
            }
          }
          return handler.next(e);
        },
      ),
    );
  }

  /// 'n Kaal Dio sonder interseptors en sonder outomatiese Authorization-kop,
  /// sodat sessie-herstel/-verfrissing nie dubbel-refresh of na-login-navigasie
  /// veroorsaak nie. Dit deel die adapter van [_dio] sodat toetse (en alternatiewe
  /// netwerk-aanpassings) dieselfde vervoerlaag gebruik.
  Dio _bareDio() => Dio(
        BaseOptions(
          baseUrl: _dio.options.baseUrl,
          connectTimeout: _dio.options.connectTimeout,
          receiveTimeout: _dio.options.receiveTimeout,
        ),
      )..httpClientAdapter = _dio.httpClientAdapter;

  /// Probeer die gestoorde sessie op app-opstart herstel:
  /// - geen gestoorde token -> geen sessie om te herstel nie;
  /// - geldige token -> laai die profiel en stel die [UserSession];
  /// - verstreke access-token -> verfris eers met die refresh_token.
  /// 'n Netwerkfout (bediener onbereikbaar) keer [false] terug sonder om die
  /// sessie uit te vee — die gebruiker verloor nie sy aanmelding omdat hy
  /// buite bereik is nie.
  Future<bool> restoreSession() async {
    final token = await _storage.read(key: _authTokenKey);
    if (token == null || token.isEmpty) return false;

    final restoreDio = _bareDio();

    Future<bool> fetchProfile(String tk) async {
      try {
        final response = await restoreDio.get(
          '/auth/me',
          options: Options(headers: {'Authorization': 'Bearer $tk'}),
        );
        if (response.statusCode != 200) return false;
        UserSession.initialize(response.data);
        ApiClient.authNotifier.value = true;
        return true;
      } on DioException catch (e) {
        if (e.response?.statusCode == 401) return false;
        rethrow;
      }
    }

    try {
      if (await fetchProfile(token)) return true;

      // Token is verstreke/ongeldig — probeer een keer met die refresh_token.
      if (await _refreshSession()) {
        final newToken = await _storage.read(key: _authTokenKey);
        if (newToken != null && await fetchProfile(newToken)) return true;
      }
      return false;
    } catch (e) {
      debugPrint("Session restore failed: $e");
      return false;
    }
  }

  /// Attempts to refresh the session using the /auth/refresh endpoint.
  /// Die backend roteer die refresh_token, so beide die nuwe access- én
  /// refresh-token word terug gestoor.
  Future<bool> _refreshSession() async {
    try {
      final refreshToken = await _storage.read(key: _refreshTokenKey);
      if (refreshToken == null || refreshToken.isEmpty) return false;

      final refreshDio = _bareDio();
      final response = await refreshDio.post(
        '/auth/refresh',
        options: Options(headers: {'Authorization': 'Bearer $refreshToken'}),
      );

      if (response.statusCode == 200) {
        final newToken = response.data['access_token'] ?? response.data['session_token'];
        final newRefresh = response.data['refresh_token'];
        if (newToken != null) {
          await saveToken(newToken, refreshToken: newRefresh);
          return true;
        }
      }
    } catch (e) {
      debugPrint("Session refresh failed: $e");
    }
    return false;
  }

  /// Retries a request with the latest authorization token.
  Future<Response> _retry(RequestOptions requestOptions) async {
    final token = await _storage.read(key: _authTokenKey);
    final options = Options(
      method: requestOptions.method,
      headers: {
        ...requestOptions.headers,
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    return _dio.request(
      requestOptions.path,
      data: requestOptions.data,
      queryParameters: requestOptions.queryParameters,
      options: options,
    );
  }

  /// Returns the configured Dio instance.
  Dio get client => _dio;

  /// Current base URL (server origin + API path).
  String get baseUrl => _dio.options.baseUrl;

  /// Updates the server base URL and persists it in secure storage so the
  /// app connects to whichever server the user configured (LAN IP, tunnel URL,
  /// or domain) on the next launch too.
  Future<void> setBaseUrl(String url) async {
    final normalized = url.trim().replaceAll(RegExp(r'/+$'), '');
    if (normalized.isEmpty) return;
    _dio.options.baseUrl = normalized.endsWith(apiPath)
        ? normalized
        : '$normalized$apiPath';
    await _storage.write(key: 'server_url', value: _dio.options.baseUrl);
  }

  /// Reads the stored server URL (set via the first-launch / settings screen).
  static Future<String?> getStoredServerUrl() async {
    return const FlutterSecureStorage().read(key: 'server_url');
  }

  /// Stores the authentication token securely (en die refresh-token, indien
  /// deur die backend verskaf) sodat die sessie oor app-herlaaie behoue bly.
  Future<void> saveToken(String token, {String? refreshToken}) async {
    if (token.isNotEmpty) {
      await _storage.write(key: _authTokenKey, value: token);
    }
    if (refreshToken != null && refreshToken.isNotEmpty) {
      await _storage.write(key: _refreshTokenKey, value: refreshToken);
    }
    ApiClient.authNotifier.value = true;
  }

  /// Removes the authentication token from secure storage.
  Future<void> clearToken() async {
    await _storage.delete(key: _authTokenKey);
    await _storage.delete(key: _refreshTokenKey);
    // Gebruikersspesifieke voorkeure (sorteervoorkeure) saam uitvee sodat die
    // volgende gebruiker nie die vorige s'n oorerf nie.
    await MultiSortController.clearAll();
    await FilterController.clearAll();
    ApiClient.authNotifier.value = false;
  }
}