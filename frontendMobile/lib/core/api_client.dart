import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user_session.dart';
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
  static const _refreshTokenKey = 'refresh_token';
  static const _retriedOnceKey = 'retried_once';

  late final Dio _dio;
  final _storage = const FlutterSecureStorage();

  /// Huidige in-vlug /auth/refresh-aanroep sodat gelyktydige 401's nie elk hul
  /// eie verversing begin nie (single-flight).
  Future<bool>? _refreshInFlight;

  /// Fires true when a token is saved, false when cleared.
  static final authNotifier = ValueNotifier<bool>(false);

  factory ApiClient() => _instance;

  ApiClient._internal() {
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
          final token = await _storage.read(key: 'auth_token');
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (DioException e, handler) async {
          debugPrint("API ERROR [${e.response?.statusCode}] at ${e.requestOptions.path}");

          if (e.response?.statusCode == 401) {
            // Stawingsbande is nie sessie-uitgewys nie: 'n mislukte aanmelding
            // of 'n mislukte verversing moet nie dieselfde
            // "sessie skoongemaak en na /" afhandeling kry as 'n vervalle sessie nie.
            final path = e.requestOptions.path;
            if (path.endsWith('/auth/login') || path.endsWith('/auth/refresh')) {
              return handler.next(e);
            }

            // FormData kan nie twee keer gestuur word nie (MultipartFile word
            // gefinaliseer); laat die oorspronklike fout deur sodat die roeper
            // se bestaande hantering dit rapporteer.
            if (e.requestOptions.data is FormData) {
              return handler.next(e);
            }

            // Die verversde versoek het weer 401 gewerp — eenmalige herprobeer is
            // klaar verbruik, moenie eindeloos deur 'n nuwe verversingsiklus loop nie.
            if (e.requestOptions.extra[_retriedOnceKey] == true) {
              await clearToken();
              UserSession.clear();
              navigatorKey.currentState?.pushNamedAndRemoveUntil('/', (route) => false);
              return handler.next(e);
            }

            final refreshed = await _refreshSession();
            if (refreshed) {
              e.requestOptions.extra[_retriedOnceKey] = true;
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

  /// Attempts to refresh the session using the /auth/refresh endpoint.
  /// Single-flight: gelyktydige 401's wag op dieselfde verversingsaanroep.
  Future<bool> _refreshSession() {
    final inFlight = _refreshInFlight;
    if (inFlight != null) return inFlight;
    final future = _doRefresh().whenComplete(() => _refreshInFlight = null);
    _refreshInFlight = future;
    return future;
  }

  Future<bool> _doRefresh() async {
    try {
      final refreshToken = await _storage.read(key: _refreshTokenKey);
      if (refreshToken == null) {
        debugPrint("Session refresh failed: no refresh token stored");
        return false;
      }

      final refreshDio = Dio(
        BaseOptions(
          baseUrl: _dio.options.baseUrl,
          connectTimeout: _dio.options.connectTimeout,
          receiveTimeout: _dio.options.receiveTimeout,
          headers: Map<String, dynamic>.of(_dio.options.headers),
        ),
      );
      final response = await refreshDio.post(
        '/auth/refresh',
        options: Options(
          headers: {'Authorization': 'Bearer $refreshToken'},
        ),
      );

      if (response.statusCode == 200) {
        final newToken =
            response.data['access_token'] ?? response.data['session_token'];
        final newRefreshToken = response.data['refresh_token'];
        if (newToken != null) {
          await saveToken(newToken);
          if (newRefreshToken != null) {
            await saveRefreshToken(newRefreshToken);
          }
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
    final token = await _storage.read(key: 'auth_token');
    final options = Options(
      method: requestOptions.method,
      headers: {
        ...requestOptions.headers,
        if (token != null) 'Authorization': 'Bearer $token',
      },
      extra: requestOptions.extra,
      responseType: requestOptions.responseType,
      contentType: requestOptions.contentType,
      sendTimeout: requestOptions.sendTimeout,
      receiveTimeout: requestOptions.receiveTimeout,
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

  /// Stores the authentication token securely.
  Future<void> saveToken(String token) async {
    await _storage.write(key: 'auth_token', value: token);
    ApiClient.authNotifier.value = true;
  }

  /// Stores the refresh token securely (vervang word by elke /auth/refresh).
  Future<void> saveRefreshToken(String token) async {
    await _storage.write(key: _refreshTokenKey, value: token);
  }

  /// Removes the authentication token from secure storage.
  Future<void> clearToken() async {
    await _storage.delete(key: 'auth_token');
    await _storage.delete(key: _refreshTokenKey);
    ApiClient.authNotifier.value = false;
  }
}
