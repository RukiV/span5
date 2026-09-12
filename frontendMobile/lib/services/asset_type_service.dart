import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../core/api_client.dart';
import '../core/idempotency.dart';
import '../models/asset_type.dart';
import 'cached_list_manager.dart';

class AssetTypeService {
  static final CachedListManager<AssetType> _manager = CachedListManager(
    load: _load,
  );

  static Future<List<AssetType>> _load() async {
    final response = await ApiClient().client.get('/assettypes');
    if (response.statusCode == 200 && response.data is List) {
      final types = <AssetType>[];
      for (final json in response.data) {
        types.add(AssetType.fromJson(json));
      }
      return types;
    }
    throw Exception('Unexpected assettypes response (${response.statusCode})');
  }

  static ValueNotifier<List<AssetType>> get typesNotifier => _manager.notifier;

  static Future<void> fetchTypes() => _manager.fetch();

  static String getTypeName(int id) {
    try {
      return _manager.values.firstWhere((t) => t.id == id).name;
    } catch (_) {
      return "Algemeen";
    }
  }

  static Future<bool> addType(String name,
    {int? avgLifespan, int? minLifespan, int? maxLifespan, String? idempotencyKey}) async {
    try {
      final data = <String, dynamic>{'assettype_name': name};
      if (avgLifespan != null) data['assettype_avg_lifespan'] = avgLifespan;
      if (minLifespan != null) data['assettype_min_lifespan'] = minLifespan;
      if (maxLifespan != null) data['assettype_max_lifespan'] = maxLifespan;
      final key = idempotencyKey ?? Idempotency.generate();
      final response = await ApiClient().client.post(
            '/assettypes',
            data: data,
            options: Options(headers: {'X-Idempotency-Key': key}),
          );
      if (response.statusCode == 200 || response.statusCode == 201) {
        await fetchTypes();
        return true;
      }
    } catch (e) {
      debugPrint("Error adding asset type: $e");
    }
    return false;
  }

  static Future<bool> deleteType(int id) async {
    try {
      final response = await ApiClient().client.delete('/assettypes/$id');
      if (response.statusCode == 200 || response.statusCode == 204) {
        await fetchTypes();
        return true;
      }
    } catch (e) {
      debugPrint("Error deleting asset type: $e");
    }
    return false;
  }
}
