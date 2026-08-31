<<<<<<< HEAD
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../models/stock.dart';
import '../core/api_client.dart';
import '../core/idempotency.dart';

// StockService: Manages the inventory levels and stock items available in the system.
class StockService {
  // Notifier to alert UI components when the stock list is updated.
  static final List<Stock> _stocks = [];
  static final ValueNotifier<List<Stock>> stocksNotifier = ValueNotifier(_stocks);

  // Pending X-Idempotency-Key; reused until the create succeeds, then cleared.
  static String? _pendingKey;

  // Fetches current stock levels from the backend.
  static Future<void> fetchStocks() async {
    try {
      final response = await ApiClient().client.get('/stock');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        _stocks.clear();
        _stocks.addAll(data.map((j) => Stock.fromJson(j)).toList());
        stocksNotifier.value = List.from(_stocks);
      }
    } catch (e) {
      debugPrint("Error loading stock: $e");
    }
  }

  // Adds a new stock item to the database.
  static Future<bool> addStock(Stock stock) async {
    try {
      _pendingKey ??= Idempotency.generate();
      final response = await ApiClient().client.post(
        '/stock',
        data: stock.toJson(),
        options: Options(headers: {'X-Idempotency-Key': _pendingKey!}),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        _pendingKey = null;
        await fetchStocks();
        return true;
      }
    } catch (e) {
      debugPrint("Error adding stock: $e");
    }
    return false;
  }

  static Future<bool> updateStock(Stock updatedStock) async {
    try {
      final response = await ApiClient().client.patch('/stock/${updatedStock.id}', data: updatedStock.toJson());
      if (response.statusCode == 200) {
        await fetchStocks();
        return true;
      }
    } catch (e) {
      debugPrint("Error updating stock: $e");
    }
    return false;
  }

  static Future<bool> deleteStock(int id) async {
    try {
      final response = await ApiClient().client.delete('/stock/$id');
      if (response.statusCode == 204 || response.statusCode == 200) {
        await fetchStocks();
        return true;
      }
    } catch (e) {
      debugPrint("Error deleting stock: $e");
    }
    return false;
  }
}
=======
import 'package:flutter/material.dart';
import '../models/stock.dart';
import '../core/api_client.dart';

// StockService: Manages the inventory levels and stock items available in the system.
class StockService {
  // Notifier to alert UI components when the stock list is updated.
  static final List<Stock> _stocks = [];
  static final ValueNotifier<List<Stock>> stocksNotifier = ValueNotifier(_stocks);

  // Fetches current stock levels from the backend.
  static Future<void> fetchStocks() async {
    try {
      final response = await ApiClient().client.get('/stock');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        _stocks.clear();
        _stocks.addAll(data.map((j) => Stock.fromJson(j)).toList());
        stocksNotifier.value = List.from(_stocks);
      }
    } catch (e) {
      debugPrint("Error loading stock: $e");
    }
  }

  // Adds a new stock item to the database.
  static Future<bool> addStock(Stock stock) async {
    try {
      final response = await ApiClient().client.post('/stock', data: stock.toJson());
      if (response.statusCode == 200 || response.statusCode == 201) {
        await fetchStocks();
        return true;
      }
    } catch (e) {
      debugPrint("Error adding stock: $e");
    }
    return false;
  }

  static Future<bool> updateStock(Stock updatedStock) async {
    try {
      final response = await ApiClient().client.patch('/stock/${updatedStock.id}', data: updatedStock.toJson());
      if (response.statusCode == 200) {
        await fetchStocks();
        return true;
      }
    } catch (e) {
      debugPrint("Error updating stock: $e");
    }
    return false;
  }

  static Future<bool> deleteStock(int id) async {
    try {
      final response = await ApiClient().client.delete('/stock/$id');
      if (response.statusCode == 204 || response.statusCode == 200) {
        await fetchStocks();
        return true;
      }
    } catch (e) {
      debugPrint("Error deleting stock: $e");
    }
    return false;
  }
}
>>>>>>> a6cc9b7400a2a627147078aeed60cfe907bbb8c3
