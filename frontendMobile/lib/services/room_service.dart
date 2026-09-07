import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../models/room.dart';

// RoomService: lookup of rooms by their scannable code.
class RoomService {
  // Used by the "scan a room" flow to resolve a scanned QR/barcode to a room,
  // including its building and campus path.
  static Future<Room?> getRoomByCode(String code) async {
    try {
      final response = await ApiClient().client.get('/rooms/code/$code');
      if (response.statusCode == 200) {
        return Room.fromJson(response.data);
      }
    } catch (e) {
      debugPrint("Error loading room by code: $e");
    }
    return null;
  }

  // Ensures a room has a scannable code, generating one if missing. Returns the
  // updated room (with its roomCode) or null on failure.
  static Future<Room?> ensureRoomCode(int roomId) async {
    try {
      final response = await ApiClient().client.post('/rooms/$roomId/code');
      if (response.statusCode == 200) {
        return Room.fromJson(response.data);
      }
    } catch (e) {
      debugPrint("Error ensuring room code: $e");
    }
    return null;
  }
}
