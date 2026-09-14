import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../core/api_client.dart';

class AssetState {
  final String state;
  final String? foundRoomId;
  final String? foundRoomName;
  final String? faultId;
  final String? originalFaultId;

  const AssetState({
    required this.state,
    this.foundRoomId,
    this.foundRoomName,
    this.faultId,
    this.originalFaultId,
  });

  bool get isMissing => state == 'missing';
  bool get isWrongRoom => state == 'wrong_room';
  bool get isClear => state == 'clear' || state.isEmpty;

  factory AssetState.fromJson(Map<String, dynamic> json) {
    return AssetState(
      state: json['state'] ?? 'clear',
      foundRoomId: json['found_room_id']?.toString(),
      foundRoomName: json['found_room_name'],
      faultId: json['fault_id']?.toString(),
      originalFaultId: json['original_fault_id']?.toString(),
    );
  }
}

class WrongRoomService {
  static Future<AssetState?> getAssetState(String assetId) async {
    try {
      final response = await ApiClient().client.get('/room-checks/asset-state/$assetId');
      if (response.statusCode == 200) {
        return AssetState.fromJson(response.data as Map<String, dynamic>);
      }
    } on DioException catch (e) {
      debugPrint("Error loading asset state: ${e.response?.statusCode} ${e.response?.data}");
    } catch (e) {
      debugPrint("Error loading asset state: $e");
    }
    return null;
  }

  /// Meld 'n bate as gevind in `roomId`. Gee die sulke foutkaartjie-ID terug.
  static Future<int?> markFoundInRoom(String assetId, int roomId, {int? originalFaultId}) async {
    try {
      final response = await ApiClient().client.post(
        '/room-checks/missing-found',
        data: {
          'asset_id': int.tryParse(assetId),
          'room_id': roomId,
          'original_fault_id': originalFaultId,
        },
      );
      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        return data['fault_id'] as int?;
      }
    } on DioException catch (e) {
      debugPrint("Error marking found: ${e.response?.statusCode} ${e.response?.data}");
    } catch (e) {
      debugPrint("Error marking found: $e");
    }
    return null;
  }
}