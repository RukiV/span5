import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ApiClient: Centralized network handler for the application using the Dio library.
class ApiClient {
  // CONFIGURATION: Set your server's IP address here.
  // Use '10.0.2.2' for Android Emulator or your laptop's local IP (e.g., 192.168.1.95) for physical devices.
  static const String laptopIp = '192.168.1.95';
  static const String serverBaseUrl = 'http://$laptopIp:8000';
  static final Dio _dio = _initDio();

  static Dio _initDio() {
    final dio = Dio(
      BaseOptions(
        baseUrl: '$serverBaseUrl/api/v1',
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'X-Client-Type': 'mobile', // Helps backend distinguish between web and mobile clients
        },
      ),
    );

    // INTERCEPTORS: Global logic for every request/response
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        debugPrint("🚀 API REQUEST[${options.method}] => ${options.baseUrl}${options.path}");
        
        // Automatically attach the Auth Token if it exists in local storage
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('auth_token');
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
        
        // Helpful debugging for network connectivity issues
        if (e.type == DioExceptionType.connectionError) {
          debugPrint("🚨 NETWORK ERROR: Make sure the phone and laptop are on the same WiFi.");
        }
        return handler.next(e);
      },
    ));

    return dio;
  }

  static Dio get dio => _dio;

  static void setBaseUrl(String url) {
    _dio.options.baseUrl = url;
  }
}
