import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../models/quote.dart';
import '../core/api_client.dart';
import '../core/idempotency.dart';
import 'cached_list_manager.dart';

class QuoteService {
  static final CachedListManager<Quote> _manager = CachedListManager(
    load: _load,
  );

  static Future<List<Quote>> _load() async {
    final response = await ApiClient().client.get('/quotes');
    if (response.statusCode == 200) {
      final List<dynamic> data = response.data;
      return data.map((json) => Quote.fromJson(json)).toList();
    }
    throw Exception('Unexpected quotes response (${response.statusCode})');
  }

  static ValueNotifier<List<Quote>> get quotesNotifier => _manager.notifier;

  @visibleForTesting
  static void resetForTest() =>
      _manager.reset();

  static Future<void> fetchQuotes() => _manager.fetch();

  static Future<Quote?> fetchQuoteById(int id) async {
    try {
      final response = await ApiClient().client.get('/quotes/$id');
      if (response.statusCode == 200) {
        return Quote.fromJson(response.data);
      }
    } catch (e) {
      debugPrint("Error fetching quote $id: $e");
    }
    return null;
  }

  static Future<Quote?> addQuote(Quote quote, {String? idempotencyKey}) async {
    try {
      final key = idempotencyKey ?? Idempotency.generate();
      final response = await ApiClient().client.post(
            '/quotes',
            data: quote.toJson(),
            options: Options(headers: {'X-Idempotency-Key': key}),
          );
      if (response.statusCode == 200 || response.statusCode == 201) {
        final created = Quote.fromJson(response.data);
        await _manager.fetch();
        return created;
      }
    } catch (e) {
      debugPrint("Error adding quote: $e");
    }
    return null;
  }

  static Future<Quote?> updateQuote(int id, Quote quote) async {
    try {
      final response =
          await ApiClient().client.patch('/quotes/$id', data: quote.toJson());
      if (response.statusCode == 200) {
        final updated = Quote.fromJson(response.data);
        await _manager.fetch();
        return updated;
      }
    } catch (e) {
      debugPrint("Error updating quote: $e");
    }
    return null;
  }
}
}