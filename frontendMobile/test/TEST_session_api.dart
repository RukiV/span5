import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fbs/core/api_client.dart';
import 'package:fbs/models/user_session.dart';

/// 'n Aangepaste [HttpClientAdapter] wat requests na gelokaliseerde response
/// stuur, sodat die ApiClient se sessie-logika sonder 'n regte bediener getoets
/// kan word.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.onRequest);

  final Response<dynamic> Function(RequestOptions options) onRequest;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final response = onRequest(options);
    return ResponseBody.fromString(
      jsonEncode(response.data),
      response.statusCode ?? 200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

typedef _RouteHandler = Response<dynamic> Function(RequestOptions options);

Response<dynamic> _resp(
  RequestOptions options,
  int statusCode,
  Map<String, dynamic> data,
) {
  return Response<dynamic>(requestOptions: options, statusCode: statusCode, data: data);
}

Dio _buildDio(Map<String, _RouteHandler> routes) {
  final dio = Dio(BaseOptions(baseUrl: 'http://testhost/api/v1'));
  dio.httpClientAdapter = _FakeAdapter((options) {
    final handler = routes[options.path];
    if (handler == null) {
      return _resp(options, 404, {'detail': 'no route in test'});
    }
    return handler(options);
  });
  return dio;
}

Map<String, dynamic> _profile() => {
      'user_id': 7,
      'user_name': 'Test',
      'user_surname': 'User',
      'user_email': 'test@akademia.ac.za',
      'location_name': 'Kampus A',
      'location_id': 1,
      'role_id': 3,
      'rights': ['users.manage'],
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, String> storageData;
  late FlutterSecureStorage storage;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    storageData = {};
    FlutterSecureStoragePlatform.instance = TestFlutterSecureStoragePlatform(storageData);
    storage = const FlutterSecureStorage();
    ApiClient.authNotifier.value = false;
    UserSession.clear();
  });

  group('saveToken / clearToken', () {
    test('saveToken stoor beide tokens en stel authNotifier', () async {
      final api = ApiClient.forTesting(storage: storage, dio: _buildDio({}));

      await api.saveToken('access-123', refreshToken: 'refresh-456');

      expect(storageData['auth_token'], 'access-123');
      expect(storageData['refresh_token'], 'refresh-456');
      expect(ApiClient.authNotifier.value, isTrue);
    });

    test('clearToken vee beide tokens uit en stel authNotifier af', () async {
      final api = ApiClient.forTesting(storage: storage, dio: _buildDio({}));
      await api.saveToken('access-123', refreshToken: 'refresh-456');
      expect(ApiClient.authNotifier.value, isTrue);

      await api.clearToken();

      expect(storageData['auth_token'], isNull);
      expect(storageData['refresh_token'], isNull);
      expect(ApiClient.authNotifier.value, isFalse);
    });
  });

  group('restoreSession', () {
    test('keer false terug wanneer geen token gestoor is nie', () async {
      var meCalled = false;
      final dio = _buildDio({
        '/auth/me': (opts) {
          meCalled = true;
          return _resp(opts, 200, _profile());
        },
      });
      final api = ApiClient.forTesting(storage: storage, dio: dio);

      expect(await api.restoreSession(), isFalse);
      expect(meCalled, isFalse, reason: '/auth/me moet nie geroep word sonder token nie');
      expect(ApiClient.authNotifier.value, isFalse);
    });

    test('herstel met geldige token en laai die UserSession', () async {
      await storage.write(key: 'auth_token', value: 'valid-access');
      String? authHeader;
      final dio = _buildDio({
        '/auth/me': (opts) {
          authHeader = opts.headers['Authorization'] as String?;
          return _resp(opts, 200, _profile());
        },
      });
      final api = ApiClient.forTesting(storage: storage, dio: dio);

      expect(await api.restoreSession(), isTrue);
      expect(authHeader, 'Bearer valid-access');
      expect(UserSession.userId, 7);
      expect(UserSession.isAdmin, isTrue);
      expect(UserSession.rights, contains('users.manage'));
      expect(ApiClient.authNotifier.value, isTrue);
    });

    test('verfris die sessie wanneer die access-token verstreke is', () async {
      await storage.write(key: 'auth_token', value: 'expired-access');
      await storage.write(key: 'refresh_token', value: 'good-refresh');

      String? refreshBearer;
      final meCalls = <String>[];
      final dio = _buildDio({
        '/auth/me': (opts) {
          meCalls.add(opts.headers['Authorization'] as String);
          return meCalls.length == 1
              ? _resp(opts, 401, {'detail': 'Invalid or expired session.'})
              : _resp(opts, 200, _profile());
        },
        '/auth/refresh': (opts) {
          refreshBearer = opts.headers['Authorization'] as String?;
          return _resp(opts, 200, {
            'access_token': 'refreshed-access',
            'refresh_token': 'refreshed-refresh',
            'user_id': 7,
          });
        },
      });
      final api = ApiClient.forTesting(storage: storage, dio: dio);

      expect(await api.restoreSession(), isTrue, reason: 'verfrissing moet slaag');
      expect(refreshBearer, 'Bearer good-refresh',
          reason: 'refresh moet die refresh_token (nie die access-token nie) stuur');
      expect(meCalls, hasLength(2));
      expect(meCalls[1], 'Bearer refreshed-access');
      expect(storageData['auth_token'], 'refreshed-access');
      expect(storageData['refresh_token'], 'refreshed-refresh');
      expect(UserSession.userId, 7);
      expect(ApiClient.authNotifier.value, isTrue);
    });

    test('keer false terug wanneer verfrissing ook misluk', () async {
      await storage.write(key: 'auth_token', value: 'expired-access');
      await storage.write(key: 'refresh_token', value: 'also-expired');

      final dio = _buildDio({
        '/auth/me': (opts) => _resp(opts, 401, {'detail': 'expired'}),
        '/auth/refresh': (opts) => _resp(opts, 401, {'detail': 'Invalid token type for refresh.'}),
      });
      final api = ApiClient.forTesting(storage: storage, dio: dio);

      expect(await api.restoreSession(), isFalse);
      expect(ApiClient.authNotifier.value, isFalse);
    });

    test('veeg die token NIE uit by n 500 (bediener-fout) nie', () async {
      await storage.write(key: 'auth_token', value: 'still-valid');

      final dio = _buildDio({
        '/auth/me': (opts) => _resp(opts, 500, {'detail': 'internal error'}),
      });
      final api = ApiClient.forTesting(storage: storage, dio: dio);

      expect(await api.restoreSession(), isFalse);
      expect(storageData['auth_token'], 'still-valid',
          reason: 'sessie moet nie uitgewis word by n nie-401 fout nie');
      expect(ApiClient.authNotifier.value, isFalse);
    });
  });
}