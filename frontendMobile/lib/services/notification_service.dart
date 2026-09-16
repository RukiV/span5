// =============================================================================
// Flutter-API-laag vir die kennisgewingstelsel
// Vloei:  UI-komponente → hierdie statiese metodes → API (dieselfde backend-eindpunte)
//         Polling: startPolling() roep fetchUnread() elke 20s, werk ValueNotifiers by
// =============================================================================
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../core/api_client.dart';

// --- Model vir 'n kennisgewing (stem ooreen met NotificationRead in die backend) ---
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

// --- Sentrale diensklas (staties, geen voorwerp nodig) ---
class NotificationService {
  static final ApiClient _api = ApiClient();
  static int _unreadCount = 0;
  static Timer? _pollTimer;

  // --- ValueNotifiers waarna die UI kan luister vir opdaterings ---
  static final ValueNotifier<int> unreadCountNotifier = ValueNotifier(0);

  // --- Begin polling (roep in app-start) ---
  static int get unreadCount => _unreadCount;

  static Future<void> startPolling() async {
    await fetchUnread();
    _pollTimer?.cancel();
    _pollTimer =
        Timer.periodic(const Duration(seconds: 20), (_) => fetchUnread());
  }

  // --- Stop polling (roep by app-afsluit) ---
  static void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  // --- Haal ongelees-telling vanaf die bediener ---
  static Future<void> fetchUnread() async {
    try {
      final response = await _api.client.get('/notifications/unread');
      final data = response.data;
      _unreadCount = data['unread_count'] ?? 0;
      unreadCountNotifier.value = _unreadCount;
    } catch (e) {
      debugPrint('Notification poll failed: $e');
    }
  }

  // --- Blaai deur alle kennisgewings (met filter en paginering) ---
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
      final response =
          await _api.client.get('/notifications', queryParameters: params);
      final items = (response.data['items'] as List? ?? [])
          .map((j) => AppNotification.fromJson(j))
          .toList();
      return items;
    } catch (e) {
      debugPrint('Fetch all notifications failed: $e');
      return [];
    }
  }

  // --- Merk een as gelees ---
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

  // --- Merk alles as gelees ---
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

  // --- Laai voorkeure (sleutel = notification_type) ---
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

  // --- Stoor een voorkeur-veld (of meer) vir 'n kennisgewing-tipe ---
  static Future<bool> updatePreference(String type,
      {bool? inAppEnabled, bool? emailEnabled, bool? pushEnabled}) async {
    try {
      final body = <String, dynamic>{'notification_type': type};
      if (inAppEnabled != null) body['in_app_enabled'] = inAppEnabled;
      if (emailEnabled != null) body['email_enabled'] = emailEnabled;
      if (pushEnabled != null) body['push_enabled'] = pushEnabled;
      await _api.client.patch('/notifications/preferences', data: [body]);
      return true;
    } catch (e) {
      debugPrint('Update preference failed: $e');
      return false;
    }
  }

  // --- Registreer 'n FCM-toestel-token ---
  static Future<bool> registerDeviceToken(String token) async {
    try {
      final platform =
          defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';
      await _api.client.post('/notifications/device-token', data: {
        'fcm_token': token,
        'platform': platform,
      });
      return true;
    } catch (e) {
      debugPrint('Register device token failed: $e');
      return false;
    }
  }
}