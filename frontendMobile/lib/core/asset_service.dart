import 'package:flutter/material.dart';
import 'dart:math';
import '../models/asset.dart';
import 'api_client.dart';

class AssetService {
  static final List<Asset> _assets = [];
  static final ValueNotifier<List<Asset>> assetsNotifier = ValueNotifier(_assets);

  static Future<void> fetchAssets() async {
    try {
      final response = await ApiClient.dio.get('/assets');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        _assets.clear();
        _assets.addAll(data.map((json) => Asset.fromJson(json)).toList());
        assetsNotifier.value = List.from(_assets);
      }
    } catch (e) {
      debugPrint("Fout met laai van bates: $e");
    }
  }

  static List<Asset> getAllAssets() => _assets;

  static Asset? getAssetById(String id) {
    try {
      return _assets.firstWhere((a) => a.id == id);
    } catch (_) {
      return null;
    }
  }

  static String generateUniqueId(String category, String campus) {
    final prefix = category.substring(0, min(3, category.length)).toUpperCase();
    final campusPrefix = campus.substring(0, min(3, campus.length)).toUpperCase();
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString().substring(7);
    return "$prefix-$campusPrefix-$timestamp";
  }

  static Future<bool> addAsset(Asset asset) async {
    try {
      final response = await ApiClient.dio.post('/assets', data: asset.toJson());
      if (response.statusCode == 200 || response.statusCode == 201) {
        // Herlaai bates om seker te maak ons het die nuwe ID vanaf die DB
        await fetchAssets();
        return true;
      }
    } catch (e) {
      debugPrint("Fout met byvoeg van bate: $e");
    }
    return false;
  }

  static Future<void> updateAsset(Asset updatedAsset) async {
    try {
      final response = await ApiClient.dio.patch('/assets/${updatedAsset.id}', data: updatedAsset.toJson());
      if (response.statusCode == 200) {
        await fetchAssets();
      }
    } catch (e) {
      debugPrint("Fout met opdatering van bate: $e");
    }
  }

  static Future<void> linkReportToAsset(String assetId, String reportId) async {
    // Backend hanteer gewoonlik hierdie verwantskap via foreign keys in die Faultcard
    debugPrint("Koppel verslag $reportId aan bate $assetId");
  }
}
