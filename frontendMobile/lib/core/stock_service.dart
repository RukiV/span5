import 'package:flutter/material.dart';
import '../models/stock.dart';
import 'api_client.dart';

// StockService: Manages the inventory levels and stock items available in the system.
class StockService {
  // Notifier to alert UI components when the stock list is updated.
  static final List<Stock> _stocks = [];
  static final ValueNotifier<List<Stock>> stocksNotifier = ValueNotifier(_stocks);

  // Fetches current stock levels from the backend.
  static Future<void> fetchStocks() async {
    try {
      final response = await ApiClient.dio.get('/stock');
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
      final response = await ApiClient.dio.post('/stock', data: stock.toJson());
      if (response.statusCode == 200 || response.statusCode == 201) {
        await fetchStocks();
        return true;
      }
    } catch (e) {
      debugPrint("Error adding stock: $e");
    }
    return false;
  }
  
  // FUTURE IDEA: Implement low-stock alerts that notify managers when items fall below a threshold.
}
