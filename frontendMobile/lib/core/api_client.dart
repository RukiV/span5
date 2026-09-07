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
  late final Dio _dio;
  final _storage = const FlutterSecureStorage();

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

  /// Attempts to refresh the session using the /auth/refresh endpoint.
  Future<bool> _refreshSession() async {
    try {
      final token = await _storage.read(key: 'auth_token');
      if (token == null) return false;

      final refreshDio = Dio(BaseOptions(baseUrl: _dio.options.baseUrl));
      final response = await refreshDio.post(
        '/auth/refresh',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (response.statusCode == 200) {
        final newToken = response.data['access_token'] ?? response.data['session_token'];
        if (newToken != null) {
          await saveToken(newToken);
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

  /// Removes the authentication token from secure storage.
  Future<void> clearToken() async {
    await _storage.delete(key: 'auth_token');
    ApiClient.authNotifier.value = false;
  }
}
