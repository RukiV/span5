import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../models/asset_type.dart';

class AssetTypeService {
  static final List<AssetType> _types = [];
  static final ValueNotifier<List<AssetType>> typesNotifier = ValueNotifier(_types);

  static Future<void> fetchTypes() async {
    try {
      final response = await ApiClient().client.get('/assettypes');
      if (response.statusCode == 200 && response.data is List) {
        _types.clear();
        for (final json in response.data) {
          _types.add(AssetType.fromJson(json));
        }
        typesNotifier.value = List.from(_types);
      }
    } catch (e) {
      debugPrint("Error fetching asset types: $e");
    }
  }

  static String getTypeName(int id) {
    try {
      return _types.firstWhere((t) => t.id == id).name;
    } catch (_) {
      return "Algemeen";
    }
  }

  static Future<bool> addType(String name, {int? avgLifespan, int? minLifespan, int? maxLifespan}) async {
    try {
      final data = <String, dynamic>{'assettype_name': name};
      if (avgLifespan != null) data['assettype_avg_lifespan'] = avgLifespan;
      if (minLifespan != null) data['assettype_min_lifespan'] = minLifespan;
      if (maxLifespan != null) data['assettype_max_lifespan'] = maxLifespan;
      final response = await ApiClient().client.post('/assettypes', data: data);
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