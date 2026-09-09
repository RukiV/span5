import 'package:flutter/foundation.dart';
import '../core/api_client.dart';
import '../core/datetime_utils.dart';
import 'cached_list_manager.dart';

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

  factory RoomCheckSession.fromJson(Map<String, dynamic> json) =>
      RoomCheckSession(
        sessionId: json['session_id'] ?? 0,
        roomId: json['room_id'] ?? 0,
        assignedUserId: json['assigned_user_id'] ?? 0,
        scheduledDatetime: parseWallClockDatetime(json['scheduled_datetime']),
        status: json['status'] ?? 'scheduled',
        calendarEventId: json['calendar_event_id'],
        roomCheckId: json['room_check_id'],
        notes: json['notes'],
        roomName: json['room_name'],
        assignedUserName: json['assigned_user_name'],
      );
}

class RoomCheckSessionService {
  static final CachedListManager<RoomCheckSession> _manager =
      CachedListManager(load: _load);

  static int? _assignedUserId;
  static int? _roomId;
  static String? _status;

  static Future<List<RoomCheckSession>> _load() async {
    final query = <String, dynamic>{
      if (_assignedUserId != null) 'assigned_user_id': _assignedUserId,
      if (_roomId != null) 'room_id': _roomId,
      if (_status != null) 'status': _status,
    };
    final response = await ApiClient()
        .client
        .get('/room-checks/sessions', queryParameters: query);
    if (response.statusCode == 200) {
      final List<dynamic> data = response.data;
      return data.map((j) => RoomCheckSession.fromJson(j)).toList();
    }
    throw Exception('Unexpected sessions response (${response.statusCode})');
  }

  static final ValueNotifier<bool> loadingNotifier = ValueNotifier(false);

  static ValueNotifier<List<RoomCheckSession>> get sessionsNotifier =>
      _manager.notifier;

  @visibleForTesting
  static void resetForTest() =>
      _manager.reset();

  static Future<void> fetchSessions({
    int? assignedUserId,
    int? roomId,
    String? status,
  }) async {
    _assignedUserId = assignedUserId;
    _roomId = roomId;
    _status = status;
    loadingNotifier.value = true;
    await _manager.fetch();
    loadingNotifier.value = false;
  }

  static Future<RoomCheckSession?> createSession({
    required int roomId,
    required int assignedUserId,
    DateTime? scheduledDatetime,
    String? notes,
  }) async {
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
          'scheduled_datetime': scheduledDatetime.toIso8601String(),
        if (status != null) 'status': status,
      };
      final response = await ApiClient()
          .client
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
      final response =
          await ApiClient().client.delete('/room-checks/sessions/$sessionId');
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
}
