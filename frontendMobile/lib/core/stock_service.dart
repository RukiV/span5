import 'package:flutter/material.dart';
import '../models/stock.dart';
import 'api_client.dart';

class StockService {
  static final List<Stock> _stocks = [];
  static final ValueNotifier<List<Stock>> stocksNotifier = ValueNotifier(_stocks);

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
      debugPrint("Fout met laai van voorraad: $e");
    }
  }

  static Future<bool> addStock(Stock stock) async {
    try {
      final response = await ApiClient.dio.post('/stock', data: stock.toJson());
      if (response.statusCode == 200 || response.statusCode == 201) {
        await fetchStocks();
        return true;
      }
    } catch (e) {
      debugPrint("Fout met byvoeg van voorraad: $e");
    }
    return false;
  }
}
