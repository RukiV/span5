import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// ApiClient: Die sentrale netwerk-enjin.
class ApiClient {
  // VIR EMULATOR: Gebruik '10.0.2.2'
  // VIR FISIESE FOON: Verander na jou rekenaar se IP (bv. '192.168.x.x')
  static const String laptopIp = '192.168.1.95';
  static const String serverBaseUrl = 'http://$laptopIp:8000';
  
  static const _storage = FlutterSecureStorage();
  
  static final Dio _dio = Dio(
    BaseOptions(
      baseUrl: '$serverBaseUrl/api/v1',
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'X-Client-Type': 'mobile', // KRITIES: Laat die backend weet dit is die mobiele app
      },
    ),
  )..interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: 'auth_token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (DioException e, handler) {
        debugPrint("❌ API FOUT: ${e.response?.statusCode} by ${e.requestOptions.path}");
        return handler.next(e);
      },
    ));

  static Dio get dio => _dio;

  static Future<void> saveToken(String token) async {
    await _storage.write(key: 'auth_token', value: token);
  }

  static Future<void> clearToken() async {
    await _storage.delete(key: 'auth_token');
  }
}
