import  'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user_session.dart';
import 'navigation.dart';

/// ApiClient: Centralized network engine for the Akademia Facility Management System.
/// 
/// This class implements a Singleton pattern to provide a single point of access 
/// to the Dio client, ensuring consistent configuration, interceptors, and security.
class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  late final Dio _dio;
  final _storage = const FlutterSecureStorage();

  factory ApiClient() => _instance;

  ApiClient._internal() {
    //emulator
    final baseUrl = dotenv.get('API_URL', fallback: 'http://10.12.0.21:8000/api/v1');
    //physical
    //final baseUrl = dotenv.get('API_URL', fallback: 'http://localhost:8000/api/v1');
    
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
          debugPrint("❌ API ERROR [${e.response?.statusCode}] at ${e.requestOptions.path}");
          
          if (e.response?.statusCode == 401) {
            // Token might be expired. Try to refresh.
            final refreshed = await _refreshSession();
            if (refreshed) {
              // Retry the original request with the new token
              try {
                final response = await _retry(e.requestOptions);
                return handler.resolve(response);
              } catch (retryError) {
                return handler.next(retryError is DioException ? retryError : e);
              }
            } else {
              // Refresh failed or no token, logout and redirect to login
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

  /// Attempts to refresh the session using the /refresh endpoint.
  Future<bool> _refreshSession() async {
    try {
      final token = await _storage.read(key: 'auth_token');
      if (token == null) return false;

      // We use a fresh Dio instance to avoid interceptor loops if refresh itself returns 401
      final refreshDio = Dio(BaseOptions(baseUrl: _dio.options.baseUrl));
      final response = await refreshDio.post(
        '/auth/refresh',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (response.statusCode == 200) {
        final newToken = response.data['session_token'];
        await saveToken(newToken);
        return true;
      }
    } catch (e) {
      debugPrint("❌ Session refresh failed: $e");
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

  /// Stores the authentication token securely.
  Future<void> saveToken(String token) async {
    await _storage.write(key: 'auth_token', value: token);
  }

  /// Removes the authentication token from secure storage.
  Future<void> clearToken() async {
    await _storage.delete(key: 'auth_token');
  }
}
