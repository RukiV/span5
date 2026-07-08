import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'dart:math';
import '../models/asset.dart';
import '../core/api_client.dart';

// AssetService: Manages the lifecycle and state of assets (equipment/hardware) in the app.
class AssetService {
  // Static list to store assets and a notifier to trigger UI updates when the list changes.
  static final List<Asset> _assets = [];
  static final ValueNotifier<List<Asset>> assetsNotifier = ValueNotifier(_assets);

  // Fetches all assets from the backend.
  static Future<void> fetchAssets() async {
    try {
      final response = await ApiClient().client.get('/assets');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        _assets.clear();
        _assets.addAll(data.map((json) => Asset.fromJson(json)).toList());
        assetsNotifier.value = List.from(_assets);
      }
    } catch (e) {
      debugPrint("Error loading assets: $e");
    }
  }

  // Used by the reporting system to identify an asset from a scanned QR or barcode.
  static Future<Asset?> getAssetBySerialCode(String serialCode) async {
    try {
      final response = await ApiClient().client.get('/assets/serial/$serialCode');
      if (response.statusCode == 200) {
        return Asset.fromJson(response.data);
      }
    } catch (e) {
      debugPrint("Error loading asset by serial: $e");
    }
    return null;
  }

  // Generates a human-readable unique ID for new assets.
  static String generateUniqueId(String category, String campus) {
    final prefix = category.substring(0, min(3, category.length)).toUpperCase();
    final campusPrefix = campus.substring(0, min(3, campus.length)).toUpperCase();
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString().substring(7);
    return "$prefix-$campusPrefix-$timestamp";
  }

  // Adds a new asset to the backend and refreshes the local list.
  static Future<bool> addAsset(Asset asset) async {
    try {
      final payload = asset.toJson();
      debugPrint("📤 POST /assets payload: $payload");
      final response = await ApiClient().client.post('/assets', data: payload);
      if (response.statusCode == 200 || response.statusCode == 201) {
        await fetchAssets();
        return true;
      }
    } on DioException catch (e) {
      debugPrint("❌ Error adding asset: ${e.response?.statusCode} ${e.response?.data}");
    } catch (e) {
      debugPrint("❌ Error adding asset: $e");
    }
    return false;
  }

  static Future<bool> updateAsset(Asset updatedAsset) async {
    try {
      final payload = updatedAsset.toJson();
      debugPrint("📤 PATCH /assets/${updatedAsset.id} payload: $payload");
      final response = await ApiClient().client.patch('/assets/${updatedAsset.id}', data: payload);
      if (response.statusCode == 200) {
        await fetchAssets();
        return true;
      }
    } on DioException catch (e) {
      debugPrint("❌ Error updating asset: ${e.response?.statusCode} ${e.response?.data}");
    } catch (e) {
      debugPrint("❌ Error updating asset: $e");
    }
    return false;
  }

  static Future<bool> deleteAsset(String id) async {
    try {
      final response = await ApiClient().client.delete('/assets/$id');
      if (response.statusCode == 204 || response.statusCode == 200) {
        await fetchAssets();
        return true;
      }
    } catch (e) {
      debugPrint("Error deleting asset: $e");
    }
    return false;
  }
}
