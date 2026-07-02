import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// ApiClient: Centralized network handler for the application using the Dio library.
/// It manages base configuration, timeouts, and secure token injection.
class ApiClient {
  // CONFIGURATION: Set your server's IP address here.
  // Use '10.0.2.2' for Android Emulator or your laptop's local IP for physical devices.
  static const String laptopIp = '10.0.2.2'; 
  static const String serverBaseUrl = 'http://$laptopIp:8000';
  
  // Secure storage for sensitive data like Auth Tokens
  static const _storage = FlutterSecureStorage();
  
  static final Dio _dio = _initDio();

  /// Initializes the Dio instance with default options and interceptors.
  static Dio _initDio() {
    final dio = Dio(
      BaseOptions(
        baseUrl: '$serverBaseUrl/api/v1',
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'X-Client-Type': 'mobile', // Essential for the backend's platform gatekeeper
        },
      ),
    );

    // INTERCEPTORS: Global logic for every request/response
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        debugPrint("🚀 API REQUEST[${options.method}] => ${options.baseUrl}${options.path}");
        
        // SECURE STORAGE: Retrieve the token safely using AES encryption (Android) / Keychain (iOS)
        final token = await _storage.read(key: 'auth_token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onResponse: (response, handler) {
        debugPrint("✅ API RESPONSE[${response.statusCode}] from ${response.requestOptions.path}");
        return handler.next(response);
      },
      onError: (DioException e, handler) {
        debugPrint("❌ API ERROR[${e.response?.statusCode}] at ${e.requestOptions.path}");
        
        // Handle specific network-level errors for better developer/user feedback
        if (e.type == DioExceptionType.connectionError) {
          debugPrint("🚨 CONNECTION ERROR: The backend is unreachable. Check your IP and WiFi.");
        } else if (e.type == DioExceptionType.connectionTimeout) {
          debugPrint("🕒 TIMEOUT ERROR: The server took too long to respond.");
        }
        
        return handler.next(e);
      },
    ));

    return dio;
  }

  /// Provides the singleton Dio instance.
  static Dio get dio => _dio;

  /// Helper to store tokens securely after successful login.
  static Future<void> saveToken(String token) async {
    await _storage.write(key: 'auth_token', value: token);
  }

  /// Helper to clear tokens on logout.
  static Future<void> clearToken() async {
    await _storage.delete(key: 'auth_token');
  }
}
