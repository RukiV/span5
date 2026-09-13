import 'package:flutter_test/flutter_test.dart';
import 'package:fbs/services/ai_service.dart';

import 'test_api_helpers.dart';

void main() {
  initTestApi();

  group('AiService', () {
    test('fetchDrafts laai konsepte suksesvol', () async {
      mockAdapter.onGet('/ai', (server) {
        server.reply(200, [
          {
            'draft_id': 1,
            'description': 'Kraan lek',
            'status': 'draft',
            'user_id': 10,
          },
          {
            'draft_id': 2,
            'description': 'Venster stukkend',
            'status': 'approved',
            'user_id': 11,
          },
        ]);
      });

      await AiService.fetchDrafts();

      expect(AiService.draftsNotifier.value.length, 2);
      expect(AiService.isLoadingNotifier.value, isFalse);
    });

    test('fetchDrafts skakel isLoading af selfs op fout', () async {
      mockAdapter.onGet('/ai', (server) {
        server.reply(500, {'detail': 'error'});
      });

      await AiService.fetchDrafts();

      expect(AiService.isLoadingNotifier.value, isFalse);
      expect(AiService.lastError, isNotNull);
    });

    test('draftsRaw gee rou lys sonder notifier', () async {
      mockAdapter.onGet('/ai', (server) {
        server.reply(200, [
          {
            'draft_id': 1,
            'description': 'Test',
            'status': 'draft',
            'user_id': 10,
          },
        ]);
      });

      final result = await AiService.draftsRaw();
      expect(result.length, 1);
    });

    test('createDraft skep konsep', () async {
      mockAdapter.onPost('/ai', (server) {
        server.reply(201, {
          'draft_id': 50,
          'description': 'Nuwe konsep',
          'status': 'draft',
          'user_id': 10,
        });
      });

      final result = await AiService.createDraft('Nuwe konsep');
      expect(result, isNotNull);
      expect(result!.draftId, 50);
    });
  });
}
