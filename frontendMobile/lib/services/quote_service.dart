import 'package:flutter/material.dart';
import '../models/quote.dart';
import '../core/api_client.dart';

class QuoteService {
  static final List<Quote> _quotes = [];
  static final ValueNotifier<List<Quote>> quotesNotifier = ValueNotifier(_quotes);

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

  static Future<Quote?> addQuote(Quote quote) async {
    try {
      final response = await ApiClient().client.post('/quotes', data: quote.toJson());
      if (response.statusCode == 200 || response.statusCode == 201) {
        final created = Quote.fromJson(response.data);
        _quotes.add(created);
        quotesNotifier.value = List.from(_quotes);
        return created;
      }
    } catch (e) {
      debugPrint("Error adding quote: $e");
    }
    return null;
  }

  static Future<Quote?> updateQuote(int id, Quote quote) async {
    try {
      final response = await ApiClient().client.patch('/quotes/$id', data: quote.toJson());
      if (response.statusCode == 200) {
        final updated = Quote.fromJson(response.data);
        final index = _quotes.indexWhere((q) => q.id == id);
        if (index != -1) {
          _quotes[index] = updated;
          quotesNotifier.value = List.from(_quotes);
        }
        return updated;
      }
    } catch (e) {
      debugPrint("Error updating quote: $e");
    }
    return null;
  }

  static Future<bool> deleteQuote(int id) async {
    try {
      final response = await ApiClient().client.delete('/quotes/$id');
      if (response.statusCode == 200 || response.statusCode == 204) {
        _quotes.removeWhere((q) => q.id == id);
        quotesNotifier.value = List.from(_quotes);
        return true;
      }
    } catch (e) {
      debugPrint("Error deleting quote: $e");
    }
    return false;
  }
}
