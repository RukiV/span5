import 'package:flutter/material.dart';
import '../core/api_client.dart';

/// Parse a backend datetime string, treating a naive (no-offset) value as UTC so
/// it is converted to the device's local timezone.
DateTime? sessionFromJsonDatetime(dynamic value) {
  if (value == null) return null;
  final s = value.toString();
  if (s.isEmpty) return null;
  final hasOffset = RegExp(r'[zZ]$|[+-]\d{2}:?\d{2}$').hasMatch(s);
  return DateTime.parse(hasOffset ? s : '${s}Z').toLocal();
}

class RoomCheckSession {
  final int sessionId;
  final int roomId;
  final int assignedUserId;
  final DateTime? scheduledDatetime;
  final String status;
  final int? calendarEventId;
  final int? roomCheckId;
  final String? notes;
  final String? roomName;
  final String? assignedUserName;

  const RoomCheckSession({
    required this.sessionId,
    required this.roomId,
    required this.assignedUserId,
    this.scheduledDatetime,
    this.status = 'scheduled',
    this.calendarEventId,
    this.roomCheckId,
    this.notes,
    this.roomName,
    this.assignedUserName,
  });

  bool get isCompleted => status == 'completed';
  bool get isCancelled => status == 'cancelled';

  factory RoomCheckSession.fromJson(Map<String, dynamic> json) =>
      RoomCheckSession(
        sessionId: json['session_id'] ?? 0,
        roomId: json['room_id'] ?? 0,
        assignedUserId: json['assigned_user_id'] ?? 0,
        scheduledDatetime: sessionFromJsonDatetime(json['scheduled_datetime']),
        status: json['status'] ?? 'scheduled',
        calendarEventId: json['calendar_event_id'],
        roomCheckId: json['room_check_id'],
        notes: json['notes'],
        roomName: json['room_name'],
        assignedUserName: json['assigned_user_name'],
      );
}

class RoomCheckSessionService {
  static final List<RoomCheckSession> _sessions = [];
  static final ValueNotifier<List<RoomCheckSession>> sessionsNotifier =
      ValueNotifier(_sessions);
  static final ValueNotifier<bool> loadingNotifier = ValueNotifier(false);

  static Future<void> fetchSessions({
    int? assignedUserId,
    int? roomId,
    String? status,
  }) async {
    loadingNotifier.value = true;
    try {
      final query = <String, dynamic>{
        if (assignedUserId != null) 'assigned_user_id': assignedUserId,
        if (roomId != null) 'room_id': roomId,
        if (status != null) 'status': status,
      };
      final response = await ApiClient().client
          .get('/room-checks/sessions', queryParameters: query);
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        _sessions
          ..clear()
          ..addAll(data.map((j) => RoomCheckSession.fromJson(j)).toList());
        sessionsNotifier.value = List.from(_sessions);
      }
    } catch (e) {
      debugPrint("Error loading room check sessions: $e");
    } finally {
      loadingNotifier.value = false;
    }
  }

  static Future<RoomCheckSession?> createSession({
    required int roomId,
    required int assignedUserId,
    DateTime? scheduledDatetime,
    String? notes,
  }) async {
    try {
      final payload = <String, dynamic>{
        'room_id': roomId,
        'assigned_user_id': assignedUserId,
        if (scheduledDatetime != null)
          'scheduled_datetime': scheduledDatetime.toUtc().toIso8601String(),
        if (notes != null) 'notes': notes,
      };
      final response = await ApiClient().client
          .post('/room-checks/sessions', data: payload);
      if (response.statusCode == 200 || response.statusCode == 201) {
        await fetchSessions();
        return RoomCheckSession.fromJson(response.data);
      }
    } catch (e) {
      debugPrint("Error creating room check session: $e");
    }
    return null;
  }

  static Future<RoomCheckSession?> updateSession(
    int sessionId, {
    int? assignedUserId,
    DateTime? scheduledDatetime,
    String? status,
  }) async {
    try {
      final payload = <String, dynamic>{
        if (assignedUserId != null) 'assigned_user_id': assignedUserId,
        if (scheduledDatetime != null)
          'scheduled_datetime': scheduledDatetime.toUtc().toIso8601String(),
        if (status != null) 'status': status,
      };
      final response = await ApiClient().client
          .patch('/room-checks/sessions/$sessionId', data: payload);
      if (response.statusCode == 200) {
        await fetchSessions();
        return RoomCheckSession.fromJson(response.data);
      }
    } catch (e) {
      debugPrint("Error updating room check session: $e");
    }
    return null;
  }

  static Future<bool> deleteSession(int sessionId) async {
    try {
      final response = await ApiClient().client
          .delete('/room-checks/sessions/$sessionId');
      if (response.statusCode == 204 || response.statusCode == 200) {
        await fetchSessions();
        return true;
      }
    } catch (e) {
      debugPrint("Error deleting room check session: $e");
      rethrow;
    }
    return false;
  }

  static Future<RoomCheckSession?> completeSession(int sessionId) async {
    try {
      final response = await ApiClient().client
          .post('/room-checks/sessions/$sessionId/complete');
      if (response.statusCode == 200) {
        await fetchSessions();
        return RoomCheckSession.fromJson(response.data);
      }
    } catch (e) {
      debugPrint("Error completing room check session: $e");
    }
    return null;
  }
}
