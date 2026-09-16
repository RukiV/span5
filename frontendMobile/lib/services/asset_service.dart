import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/asset.dart';
import '../core/api_client.dart';
import 'crud_service.dart';

// AssetService: Manages the lifecycle and state of assets (equipment/hardware) in the app.
class AssetService {
  static final CrudService<Asset> _crud = CrudService<Asset>(
    basePath: '/assets',
    fromJson: (j) => Asset.fromJson(j),
    toJson: (a) => a.toJson(),
  );

  static ValueNotifier<List<Asset>> get assetsNotifier => _crud.itemsNotifier;

  static ValueNotifier<bool> get isLoadingNotifier => _crud.isLoadingNotifier;

  // Fetches all assets from the backend.
  static Future<void> fetchAssets() => _crud.fetch();

  // Used by the reporting system to identify an asset from a scanned QR or barcode.
  static Future<Asset?> getAssetBySerialCode(String serialCode) async {
    try {
      final response =
          await ApiClient().client.get('/assets/serial/$serialCode');
      if (response.statusCode == 200) {
        return Asset.fromJson(response.data);
      }
    } catch (e) {
      debugPrint("Error loading asset by serial: $e");
    }
    return null;
  }

  // Adds a new asset to the backend and refreshes the local list.
  static String generateUniqueId(String category, String campus) {
    final prefix = category.substring(0, min(3, category.length)).toUpperCase();
    final campusPrefix = campus
        .substring(0, min(3, campus.length))
        .toUpperCase();
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString().substring(7);
    return "$prefix-$campusPrefix-$timestamp";
  }

  static Future<bool> addAsset(Asset asset, {String? idempotencyKey}) =>
      _crud.add(asset, idempotencyKey: idempotencyKey);

  static Future<bool> updateAsset(Asset updatedAsset) =>
      _crud.update(updatedAsset, updatedAsset.id);

  static Future<bool> deleteAsset(String id) => _crud.delete(id);
}