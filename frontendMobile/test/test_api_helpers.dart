import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:fbs/core/api_client.dart';
import 'package:fbs/services/quote_service.dart';
import 'package:fbs/services/report_service.dart';
import 'package:fbs/services/ai_service.dart';
import 'package:fbs/services/user_service.dart';
import 'package:fbs/services/room_check_session_service.dart';
import 'package:fbs/services/jobcard_service.dart';

late DioAdapter mockAdapter;

void _resetAllServices() {
  QuoteService.resetForTest();
  ReportService.resetForTest();
  AiService.resetForTest();
  UserService.resetForTest();
  RoomCheckSessionService.resetForTest();
  JobcardService.resetForTest();
}

void initTestApi() {
  setUpAll(() {
    dotenv.testLoad();
  });

  setUp(() {
    _resetAllServices();
    final client = ApiClient().client;
    client.interceptors.clear();
    mockAdapter = DioAdapter(
      dio: client,
      matcher: const UrlRequestMatcher(matchMethod: true),
    );
  });

  tearDown(() {
    mockAdapter.close();
  });
}
