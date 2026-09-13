import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../core/api_client.dart';
import '../core/idempotency.dart';
import 'cached_list_manager.dart';

/// Generiese CRUD-agterlaag vir enige diens wat op 'n `CachedListManager`
/// met standaard GET/POST/PATCH/DELETE'-patroon steun.
///
/// Die diens (@AssetService, @StockService, ens.) bly 'n statiese facade wat
/// na 'n private [CrudService]-instantie delegeer, sodat die publieke API
/// onveranderd bly. `T` is die model-tipe.
class CrudService<T> {
  final String basePath;
  final T Function(Map<String, dynamic>) fromJson;
  final Map<String, dynamic> Function(T) toJson;

  late final CachedListManager<T> _manager;

  CrudService({
    required this.basePath,
    required this.fromJson,
    required this.toJson,
  }) {
    _manager = CachedListManager(load: _load);
  }

  Future<List<T>> _load() async {
    final response = await ApiClient().client.get(basePath);
    if (response.statusCode == 200) {
      final List<dynamic> data = response.data;
      return data
          .map((json) => fromJson(json as Map<String, dynamic>))
          .toList();
    }
    throw Exception('Unexpected $basePath response (${response.statusCode})');
  }

  ValueNotifier<List<T>> get itemsNotifier => _manager.notifier;

  Future<void> fetch() => _manager.fetch();

  Future<bool> add(T item, {String? idempotencyKey}) async {
    try {
      final key = idempotencyKey ?? Idempotency.generate();
      final response = await ApiClient().client.post(
            basePath,
            data: toJson(item),
            options: Options(headers: {'X-Idempotency-Key': key}),
          );
      if (response.statusCode == 200 || response.statusCode == 201) {
        await fetch();
        return true;
      }
    } catch (e) {
      debugPrint("Error adding $basePath: $e");
    }
    return false;
  }

  Future<bool> update(T item, dynamic id) async {
    try {
      final response =
          await ApiClient().client.patch('$basePath/$id', data: toJson(item));
      if (response.statusCode == 200) {
        await fetch();
        return true;
      }
    } catch (e) {
      debugPrint("Error updating $basePath: $e");
    }
    return false;
  }

  Future<bool> delete(dynamic id) async {
    try {
      final response = await ApiClient().client.delete('$basePath/$id');
      if (response.statusCode == 204 || response.statusCode == 200) {
        await fetch();
        return true;
      }
    } catch (e) {
      debugPrint("Error deleting $basePath: $e");
    }
    return false;
  }
}
