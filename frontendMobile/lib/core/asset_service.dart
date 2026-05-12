import 'package:flutter/material.dart';
import '../models/asset.dart';
import 'api_client.dart';
import 'campus_service.dart';

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

  static String generateUniqueId(String category, String campusName) {
    String campusCode = _getCampusCode(campusName);
    String catCode = _getCategoryCode(category);
    String year = DateTime.now().year.toString().substring(2);
    
    int count = _assets.where((a) => 
      a.id.startsWith("$campusCode-$catCode-$year")
    ).length + 1;
    
    String sequence = count.toString().padLeft(3, '0');
    return "$campusCode-$catCode-$year-$sequence";
  }

  static String _getCampusCode(String name) {
    final campus = CampusService.getCampusByName(name);
    if (campus != null) {
      return campus.code;
    }
    return name.length >= 3 ? name.substring(0, 3).toUpperCase() : name.toUpperCase();
  }

  static String _getCategoryCode(String cat) {
    switch (cat) {
      case "Meubels": return "MEU";
      case "IT Toerusting": return "ITT";
      case "Elektronika": return "ELC";
      case "Kombuis": return "KOM";
      case "Ander": return "AND";
      default: return "GEN";
    }
  }

  static Future<bool> addAsset(Asset asset) async {
    try {
      final response = await ApiClient.dio.post('/assets', data: asset.toJson());
      if (response.statusCode == 200 || response.statusCode == 201) {
        _assets.add(asset);
        assetsNotifier.value = List.from(_assets);
        return true;
      }
    } catch (e) {
      debugPrint("Fout met byvoeg van bate: $e");
    }
    return false;
  }

  static Future<void> updateAsset(Asset updatedAsset) async {
    try {
      final response = await ApiClient.dio.put('/assets/${updatedAsset.id}', data: updatedAsset.toJson());
      if (response.statusCode == 200) {
        int index = _assets.indexWhere((a) => a.id == updatedAsset.id);
        if (index != -1) {
          _assets[index] = updatedAsset;
          assetsNotifier.value = List.from(_assets);
        }
      }
    } catch (e) {
      debugPrint("Fout met opdatering van bate: $e");
    }
  }

  static Future<void> linkReportToAsset(String assetId, String reportId) async {
    Asset? asset = getAssetById(assetId);
    if (asset != null) {
      if (!asset.reportIds.contains(reportId)) {
        final updatedAsset = asset.copyWith(
          reportIds: [...asset.reportIds, reportId]
        );
        await updateAsset(updatedAsset);
      }
    }
  }
}
