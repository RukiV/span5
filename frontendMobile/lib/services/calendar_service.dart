import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../core/api_client.dart';
import '../core/idempotency.dart';

class CalendarEvent {
  final int? eventId;
  final String? source;
  final String title;
  final String? description;
  final DateTime startDatetime;
  final DateTime? endDatetime;
  final bool allDay;
  final String? location;
  final String? color;
  final bool notifyEmail;
  final int? reminderMinutes;
  final bool reminderSent;
  final String? outlookEventId;
  final bool outlookSynced;

  CalendarEvent({
    this.eventId,
    this.source,
    required this.title,
    this.description,
    required this.startDatetime,
    this.endDatetime,
    this.allDay = false,
    this.location,
    this.color,
    this.notifyEmail = false,
    this.reminderMinutes,
    this.reminderSent = false,
    this.outlookEventId,
    this.outlookSynced = false,
  });

  factory CalendarEvent.fromJson(Map<String, dynamic> json) {
    return CalendarEvent(
      eventId: json['source'] == 'calendar_event' ? json['source_id'] : null,
      source: json['source'],
      title: json['title'] ?? '',
      description: json['description'],
      startDatetime: json['start_datetime'] != null
          ? DateTime.parse(json['start_datetime'])
          : DateTime.now(),
      endDatetime: json['end_datetime'] != null
          ? DateTime.parse(json['end_datetime'])
          : null,
      allDay: json['all_day'] ?? false,
      location: json['location'],
      color: json['color'],
      notifyEmail: json['notify_email'] ?? false,
      reminderMinutes: json['reminder_minutes'],
      reminderSent: json['reminder_sent'] ?? false,
      outlookEventId: json['outlook_event_id'],
      outlookSynced: json['outlook_synced'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'title': title,
    'description': description,
    'start_datetime': startDatetime.toIso8601String(),
    'end_datetime': endDatetime?.toIso8601String(),
    'all_day': allDay,
    'location': location,
    'color': color,
    'notify_email': notifyEmail,
    'reminder_minutes': reminderMinutes,
  };
}

class CalendarService {
  static final List<CalendarEvent> _events = [];
  static final ValueNotifier<List<CalendarEvent>> eventsNotifier = ValueNotifier(_events);

  // Pending X-Idempotency-Key; reused until the create succeeds, then cleared.
  static String? _pendingKey;

  static Future<void> fetchEvents(DateTime start, DateTime end) async {
    try {
      final response = await ApiClient().client.get(
        '/calendar/events',
        queryParameters: {
          'start': start.toIso8601String(),
          'end': end.toIso8601String(),
        },
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        _events.clear();
        _events.addAll(data.map((j) => CalendarEvent.fromJson(j)));
        eventsNotifier.value = List.from(_events);
      }
    } catch (e) {
      debugPrint("Fout met laai van kalender events: $e");
    }
  }

  static Future<bool> addEvent(CalendarEvent event) async {
    try {
      _pendingKey ??= Idempotency.generate();
      final response = await ApiClient().client.post(
        '/calendar/events',
        data: event.toJson(),
        options: Options(headers: {'X-Idempotency-Key': _pendingKey!}),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        _pendingKey = null;
        await fetchEvents(
          DateTime.now().subtract(const Duration(days: 30)),
          DateTime.now().add(const Duration(days: 60)),
        );
        return true;
      }
    } catch (e) {
      debugPrint("Fout met byvoeging van event: $e");
    }
    return false;
  }

  static Future<bool> deleteEvent(int eventId) async {
    try {
      final response = await ApiClient().client.delete('/calendar/events/$eventId');
      if (response.statusCode == 204 || response.statusCode == 200) {
        _events.removeWhere((e) => e.eventId == eventId);
        eventsNotifier.value = List.from(_events);
        return true;
      }
    } catch (e) {
      debugPrint("Fout met verwydering van event: $e");
    }
    return false;
  }
}
