import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../models/quote.dart';
import '../core/api_client.dart';
import '../core/idempotency.dart';

class QuoteService {
  static final List<Quote> _quotes = [];
  static final ValueNotifier<List<Quote>> quotesNotifier = ValueNotifier(_quotes);

  // Pending X-Idempotency-Key; reused until the create succeeds, then cleared.
  static String? _pendingKey;

  static Future<void> fetchQuotes() async {
    try {
      final response = await ApiClient().client.get('/quotes');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        _quotes.clear();
        _quotes.addAll(data.map((json) => Quote.fromJson(json)).toList());
        quotesNotifier.value = List.from(_quotes);
      }
    } catch (e) {
      debugPrint("Error fetching quotes: $e");
    }
  }

  static Future<bool> addQuote(Quote quote) async {
    try {
      _pendingKey ??= Idempotency.generate();
      final response = await ApiClient().client.post(
        '/quotes',
        data: quote.toJson(),
        options: Options(headers: {'X-Idempotency-Key': _pendingKey!}),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        _pendingKey = null;
        await fetchQuotes();
        return true;
      }
    } catch (e) {
      debugPrint("Error adding quote: $e");
    }
    return false;
  }

  static Future<bool> updateQuote(Quote quote) async {
    try {
      final response = await ApiClient().client.patch('/quotes/${quote.id}', data: quote.toJson());
      if (response.statusCode == 200) {
        await fetchQuotes();
        return true;
      }
    } catch (e) {
      debugPrint("Error updating quote: $e");
    }
    return false;
  }

  static Future<bool> deleteQuote(int id) async {
    try {
      final response = await ApiClient().client.delete('/quotes/$id');
      if (response.statusCode == 200 || response.statusCode == 204) {
        await fetchQuotes();
        return true;
      }
    } catch (e) {
      debugPrint("Error deleting quote: $e");
    }
    return false;
  }

  static List<Quote> getQuotesForJob(int jobId) {
    return _quotes.where((q) => q.jobId == jobId).toList();
  }
}
