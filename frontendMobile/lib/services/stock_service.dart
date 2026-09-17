import 'package:flutter/foundation.dart';
import '../models/stock.dart';
import 'crud_service.dart';

// StockService: Manages the inventory levels and stock items available in the system.
class StockService {
  static final CrudService<Stock> _crud = CrudService<Stock>(
    basePath: '/stock',
    fromJson: (j) => Stock.fromJson(j),
    toJson: (s) => s.toJson(),
  );

  static ValueNotifier<List<Stock>> get stocksNotifier => _crud.itemsNotifier;

  static Future<void> fetchStocks() => _crud.fetch();

  static Future<bool> addStock(Stock stock, {String? idempotencyKey}) =>
      _crud.add(stock, idempotencyKey: idempotencyKey);

  static Future<bool> updateStock(Stock updatedStock) =>
      _crud.update(updatedStock, updatedStock.id);

  static Future<bool> deleteStock(int id) => _crud.delete(id);
}