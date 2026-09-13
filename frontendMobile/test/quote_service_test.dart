import 'package:flutter_test/flutter_test.dart';
import 'package:fbs/models/quote.dart';
import 'package:fbs/services/quote_service.dart';

import 'test_api_helpers.dart';

void main() {
  initTestApi();

  group('QuoteService', () {
    test('fetchQuotes laai kwotasies suksesvol', () async {
      mockAdapter.onGet('/quotes', (server) {
        server.reply(200, [
          {
            'quote_id': 1,
            'quote_date': '2025-06-15',
            'quote_status': 'pending'
          },
          {
            'quote_id': 2,
            'quote_date': '2025-06-20',
            'quote_status': 'accepted'
          },
        ]);
      });

      await QuoteService.fetchQuotes();

      expect(QuoteService.quotesNotifier.value.length, 2);
      expect(QuoteService.quotesNotifier.value[0].id, 1);
    });

    test('fetchQuotes handhaaf cache op fout', () async {
      mockAdapter.onGet('/quotes', (server) {
        server.reply(500, {'detail': 'Internal Server Error'});
      });

      await QuoteService.fetchQuotes();
      expect(QuoteService.quotesNotifier.value, isEmpty);
    });

    test('addQuote skep kwotasie en refetch', () async {
      mockAdapter.onGet('/quotes', (server) {
        server.reply(200, [
          {
            'quote_id': 1,
            'quote_date': '2025-06-15',
            'quote_status': 'pending'
          },
        ]);
      });
      mockAdapter.onPost('/quotes', (server) {
        server.reply(201, {
          'quote_id': 99,
          'quote_date': '2025-07-01',
          'quote_status': 'pending',
        });
      });

      await QuoteService.fetchQuotes();
      final result = await QuoteService.addQuote(Quote(
        date: DateTime(2025, 7, 1),
        status: 'pending',
      ));

      expect(result, isNotNull);
      expect(result!.id, 99);
      expect(QuoteService.quotesNotifier.value.length, 1);
    });

    test('updateQuote dateer op en refetch', () async {
      mockAdapter.onGet('/quotes', (server) {
        server.reply(200, [
          {
            'quote_id': 1,
            'quote_date': '2025-06-15',
            'quote_status': 'rejected'
          },
        ]);
      });
      mockAdapter.onPatch('/quotes/1', (server) {
        server.reply(200, {
          'quote_id': 1,
          'quote_date': '2025-06-15',
          'quote_status': 'rejected',
        });
      });

      final result = await QuoteService.updateQuote(
        1,
        Quote(id: 1, date: DateTime(2025, 6, 15), status: 'rejected'),
      );

      expect(result, isNotNull);
      expect(QuoteService.quotesNotifier.value[0].status, 'rejected');
    });
  });
}
