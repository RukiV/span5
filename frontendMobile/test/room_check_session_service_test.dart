import 'package:flutter_test/flutter_test.dart';
import 'package:fbs/services/room_check_session_service.dart';

import 'test_api_helpers.dart';

void main() {
  initTestApi();

  group('RoomCheckSessionService', () {
    test('fetchSessions laai sessies suksesvol', () async {
      mockAdapter.onGet('/room-checks/sessions', (server) {
        server.reply(200, [
          {
            'session_id': 1,
            'room_id': 10,
            'assigned_user_id': 5,
            'status': 'scheduled',
          },
          {
            'session_id': 2,
            'room_id': 11,
            'assigned_user_id': 6,
            'status': 'completed',
          },
        ]);
      });

      await RoomCheckSessionService.fetchSessions();

      expect(RoomCheckSessionService.sessionsNotifier.value.length, 2);
      expect(RoomCheckSessionService.loadingNotifier.value, isFalse);
    });

    test('fetchSessions skakel loading af selfs op fout', () async {
      mockAdapter.onGet('/room-checks/sessions', (server) {
        server.reply(500, {'detail': 'error'});
      });

      await RoomCheckSessionService.fetchSessions();

      expect(RoomCheckSessionService.loadingNotifier.value, isFalse);
    });

    test('createSession skep sessie en refetch', () async {
      mockAdapter.onGet('/room-checks/sessions', (server) {
        server.reply(200, [
          {
            'session_id': 1,
            'room_id': 10,
            'assigned_user_id': 5,
            'status': 'scheduled',
          },
        ]);
      });
      mockAdapter.onPost('/room-checks/sessions', (server) {
        server.reply(201, {
          'session_id': 99,
          'room_id': 10,
          'assigned_user_id': 5,
          'status': 'scheduled',
        });
      });

      final result = await RoomCheckSessionService.createSession(
        roomId: 10,
        assignedUserId: 5,
      );

      expect(result, isNotNull);
      expect(result!.sessionId, 99);
      expect(RoomCheckSessionService.sessionsNotifier.value.length, 1);
    });

    test('deleteSession verwyder sessie en refetch', () async {
      mockAdapter.onGet('/room-checks/sessions', (server) {
        server.reply(200, <dynamic>[]);
      });
      mockAdapter.onDelete('/room-checks/sessions/1', (server) {
        server.reply(204, null);
      });

      final result = await RoomCheckSessionService.deleteSession(1);

      expect(result, isTrue);
      expect(RoomCheckSessionService.sessionsNotifier.value, isEmpty);
    });

    test('deleteSession gooi fout deur (rethrow)', () async {
      mockAdapter.onGet('/room-checks/sessions', (server) {
        server.reply(200, <dynamic>[]);
      });
      mockAdapter.onDelete('/room-checks/sessions/1', (server) {
        server.reply(500, {'detail': 'error'});
      });

      expect(
        () => RoomCheckSessionService.deleteSession(1),
        throwsA(isA<Exception>()),
      );
    });
  });
}
