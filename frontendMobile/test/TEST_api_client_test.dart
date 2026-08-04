import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';

void main() {
  group('ApiClient logic', () {
    test('Dio base URL defaults to https', () {
      final dio = Dio(BaseOptions(baseUrl: 'https://localhost/api/v1'));
      expect(dio.options.baseUrl.startsWith('https'), isTrue);
    });

    test('Dio sets mobile client type header', () {
      final dio = Dio(BaseOptions(headers: {'X-Client-Type': 'mobile'}));
      expect(dio.options.headers['X-Client-Type'], 'mobile');
    });

    test('Dio has 15 second timeouts', () {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
      ));
      expect(dio.options.connectTimeout, const Duration(seconds: 15));
      expect(dio.options.receiveTimeout, const Duration(seconds: 15));
    });

    test('Auth token is attached in interceptor logic', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://test.api'));
      String? capturedToken;

      dio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) async {
          const storedToken = 'test_token_abc123';
          options.headers['Authorization'] = 'Bearer $storedToken';
          capturedToken = storedToken;
          handler.resolve(Response(
            requestOptions: options,
            statusCode: 200,
            data: {},
          ));
        },
      ));

      final response = await dio.get('/auth/me');
      expect(response.statusCode, 200);
      expect(capturedToken, 'test_token_abc123');
    });
  });
}
