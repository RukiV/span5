import 'dart:async';
import 'package:flutter/foundation.dart';
import '../core/api_client.dart';

class AppNotification {
  final int notificationId;
  final String notificationType;
  final String title;
  final String message;
  final String? referenceType;
  final int? referenceId;
  final bool isRead;
  final String createdAt;

  AppNotification({
    required this.notificationId,
    required this.notificationType,
    required this.title,
    required this.message,
    this.referenceType,
    this.referenceId,
    required this.isRead,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      notificationId: json['notification_id'] ?? 0,
      notificationType: json['notification_type'] ?? '',
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      referenceType: json['reference_type'],
      referenceId: json['reference_id'],
      isRead: json['is_read'] ?? false,
      createdAt: json['created_at'] ?? '',
    );
  }
}

class NotificationService {
  static final ApiClient _api = ApiClient();
  static int _unreadCount = 0;
  static List<AppNotification> _latest = [];
  static Timer? _pollTimer;

  static final ValueNotifier<int> unreadCountNotifier = ValueNotifier(0);
  static final ValueNotifier<List<AppNotification>> latestNotifier =
      ValueNotifier([]);

  static int get unreadCount => _unreadCount;
  static List<AppNotification> get latest => _latest;

  static Future<void> startPolling() async {
    await fetchUnread();
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 20), (_) => fetchUnread());
  }

  static void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  static Future<void> fetchUnread() async {
    try {
      final response = await _api.client.get('/notifications/unread');
      final data = response.data;
      _unreadCount = data['unread_count'] ?? 0;
      _latest = (data['latest'] as List? ?? [])
          .map((j) => AppNotification.fromJson(j))
          .toList();
      unreadCountNotifier.value = _unreadCount;
      latestNotifier.value = _latest;
    } catch (e) {
      debugPrint('Notification poll failed: $e');
    }
  }

  static Future<List<AppNotification>> fetchAll({
    int page = 1,
    int perPage = 20,
    String? type,
    bool? isRead,
  }) async {
    try {
      final params = <String, dynamic>{
        'page': page,
        'per_page': perPage,
      };
      if (type != null && type.isNotEmpty) params['notification_type'] = type;
      if (isRead != null) params['is_read'] = isRead;
      final response = await _api.client.get('/notifications', queryParameters: params);
      final items = (response.data['items'] as List? ?? [])
          .map((j) => AppNotification.fromJson(j))
          .toList();
      return items;
    } catch (e) {
      debugPrint('Fetch all notifications failed: $e');
      return [];
    }
  }

  static Future<bool> markAsRead(int id) async {
    try {
      await _api.client.patch('/notifications/$id/read');
      _unreadCount = (_unreadCount - 1).clamp(0, _unreadCount);
      unreadCountNotifier.value = _unreadCount;
      return true;
    } catch (e) {
      debugPrint('Mark as read failed: $e');
      return false;
    }
  }

  static Future<bool> markAllAsRead() async {
    try {
      await _api.client.patch('/notifications/read-all');
      _unreadCount = 0;
      unreadCountNotifier.value = 0;
      return true;
    } catch (e) {
      debugPrint('Mark all as read failed: $e');
      return false;
    }
  }

  static Future<bool> deleteNotification(int id) async {
    try {
      await _api.client.delete('/notifications/$id');
      return true;
    } catch (e) {
      debugPrint('Delete notification failed: $e');
      return false;
    }
  }

  static Future<Map<String, dynamic>> fetchPreferences() async {
    try {
      final res = await _api.client.get('/notifications/preferences');
      final list = res.data as List? ?? [];
      final map = <String, dynamic>{};
      for (final item in list) {
        map[item['notification_type']] = item;
      }
      return map;
    } catch (e) {
      debugPrint('Fetch preferences failed: $e');
      return {};
    }
  }

  static Future<bool> updatePreference(String type, bool inAppEnabled) async {
    try {
      await _api.client.patch('/notifications/preferences', data: [
        {'notification_type': type, 'in_app_enabled': inAppEnabled},
      ]);
      return true;
    } catch (e) {
      debugPrint('Update preference failed: $e');
      return false;
    }
  }

  static Future<bool> registerDeviceToken(String token) async {
    try {
      await _api.client.post('/notifications/device-token', data: {
        'fcm_token': token,
        'platform': 'android',
      });
      return true;
    } catch (e) {
      debugPrint('Register device token failed: $e');
      return false;
    }
  }

  static Future<void> unregisterDeviceToken(String token) async {
    try {
      await _api.client.delete('/notifications/device-token', data: {
        'fcm_token': token,
      });
    } catch (e) {
      debugPrint('Unregister device token failed: $e');
    }
  }
}
