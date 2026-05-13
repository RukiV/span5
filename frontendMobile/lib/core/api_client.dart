import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class ApiClient {
  static final Dio _dio = _initDio();

  static Dio _initDio() {
    // VIR WERKLIKE FOON: Vervang met jou laptop se IP (bv. '192.168.1.100')
    // Jy kan dit kry deur 'ipconfig' in cmd te hardloop op Windows.
    const String laptopIp = '192.168.1.95'; // Jou laptop se IP-adres vanaf die foto

    final dio = Dio(
      BaseOptions(
        baseUrl: 'http://$laptopIp:8000/api/v1',
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    dio.interceptors.add(InterceptorsWrapper(
      onError: (DioException e, handler) {
        if (e.type == DioExceptionType.connectionError) {
          debugPrint("Fout: Kon nie aan $laptopIp verbind nie. Maak seker die backend hardloop en jou foon is op dieselfde WiFi.");
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
