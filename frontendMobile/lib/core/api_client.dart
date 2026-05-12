import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class ApiClient {
  static final Dio _dio = _initDio();

  static Dio _initDio() {
    final dio = Dio(
      BaseOptions(
        baseUrl: 'http://10.0.2.2:8000', // Verstek vir Android Emulator na localhost
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    dio.interceptors.add(InterceptorsWrapper(
      onError: (DioException e, handler) {
        if (e.type == DioExceptionType.connectionError) {
          debugPrint("Fout: Kon nie aan die bediener verbind nie. Is die FastAPI backend aan?");
        } else if (e.type == DioExceptionType.connectionTimeout) {
          debugPrint("Fout: Konneksie het uitgetel.");
        }
        return handler.next(e);
      },
    ));

    return dio;
  }

  static Dio get dio => _dio;

  // Hulpmetode om die base URL te verander indien nodig (bv. vir produksie)
  static void setBaseUrl(String url) {
    _dio.options.baseUrl = url;
  }
}
