import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'outlook_token_manager.dart';

class OutlookService {
  OutlookService._();

  static final OutlookService instance = OutlookService._();

  static const _graphBase = 'https://graph.microsoft.com/v1.0';
  static const _timeZone = 'South Africa Standard Time';

  static const _calendarViewSelect =
      'id,subject,bodyPreview,start,end,location,recurrence';

  Future<Dio?> _graphDio() async {
    final token = await OutlookTokenManager.instance.getGraphAccessToken();
    if (token == null) return null;
    return Dio(BaseOptions(
      baseUrl: _graphBase,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'Prefer': 'outlook.timezone="$_timeZone"',
      },
    ));
  }

  Future<List<Map<String, dynamic>>> fetchCalendarView(
      DateTime start, DateTime end) async {
    try {
      final dio = await _graphDio();
      if (dio == null) return const [];

      final response = await dio.get(
        '/me/calendarView',
        queryParameters: {
          'startDateTime': start.toUtc().toIso8601String(),
          'endDateTime': end.toUtc().toIso8601String(),
          r'$top': 100,
          r'$orderby': 'start/dateTime asc',
          r'$select': _calendarViewSelect,
        },
      );
      final data = response.data;
      final events = (data['value'] as List? ?? []);
      return events.map((ev) {
        final evMap = ev as Map<String, dynamic>;
        final startObj = evMap['start'] as Map<String, dynamic>? ?? {};
        final endObj = evMap['end'] as Map<String, dynamic>? ?? {};
        final locObj = evMap['location'] as Map<String, dynamic>? ?? {};
        return <String, dynamic>{
          'source': 'outlook',
          'source_id': evMap['id'],
          'title': evMap['subject'] ?? '',
          'description': evMap['bodyPreview'] ?? '',
          'start_datetime': startObj['dateTime'],
          'end_datetime': endObj['dateTime'],
          'all_day': startObj['dateTime'] == null,
          'location': locObj['displayName'] ?? '',
          'color': '#0078D4',
          'outlook_event_id': evMap['id'],
        };
      }).toList();
    } catch (e) {
      debugPrint('Outlook events laai fout: $e');
      return const [];
    }
  }

  Future<String?> createEvent({
    required String title,
    String? description,
    required DateTime start,
    required DateTime end,
    String? location,
  }) async {
    try {
      final dio = await _graphDio();
      if (dio == null) return null;

      final response = await dio.post(
        '/me/events',
        data: {
          'subject': title,
          'body': {
            'contentType': 'HTML',
            'content': description ?? '',
          },
          'start': {'dateTime': _graphDateTime(start), 'timeZone': _timeZone},
          'end': {'dateTime': _graphDateTime(end), 'timeZone': _timeZone},
          'location': {'displayName': location ?? ''},
        },
      );
      final created = response.data as Map<String, dynamic>?;
      return created?['id'];
    } catch (e) {
      debugPrint('Outlook event skep fout: $e');
      return null;
    }
  }

  Future<bool> deleteEvent(String outlookEventId) async {
    try {
      final dio = await _graphDio();
      if (dio == null) return false;
      await dio.delete('/me/events/$outlookEventId');
      return true;
    } catch (e) {
      debugPrint('Outlook event verwyder fout: $e');
      return false;
    }
  }

  Future<bool> createWorkOrderEvent({
    required int jobId,
    String? description,
    required DateTime scheduledDatetime,
    String? scheduleType,
  }) async {
    try {
      final dio = await _graphDio();
      if (dio == null) return false;

      final marker = 'FBS-WO-$jobId';
      final start = scheduledDatetime;
      final end = scheduledDatetime.add(const Duration(hours: 1));
      final desc = (description == null || description.isEmpty)
          ? 'Werksopdrag'
          : description;

      final payload = <String, dynamic>{
        'subject': '$marker $desc',
        'body': {
          'contentType': 'HTML',
          'content': '<p>Werksopdrag ID: $jobId</p><p>$desc</p>',
        },
        'start': {'dateTime': _graphDateTime(start), 'timeZone': _timeZone},
        'end': {'dateTime': _graphDateTime(end), 'timeZone': _timeZone},
      };

      final recurrence = _buildRecurrence(scheduleType, start);
      if (recurrence != null) payload['recurrence'] = recurrence;

      await dio.post('/me/events', data: payload);
      return true;
    } catch (e) {
      debugPrint('Outlook werksopdrag-afspraak skep fout: $e');
      return false;
    }
  }

  Future<void> deleteWorkOrderEvents(int jobId) async {
    try {
      final dio = await _graphDio();
      if (dio == null) return;

      final marker = 'FBS-WO-$jobId';
      try {
        await _scanAndDeleteEvents(dio, marker, queryParameters: {
          r'$top': 100,
          r'$select': 'id,subject,bodyPreview',
          r'$orderby': 'lastModifiedDateTime desc',
          r'$filter': "contains(subject,'$marker')",
        });
      } on DioException {
        await _scanAndDeleteEvents(dio, marker,
            queryParameters: {
              r'$top': 100,
              r'$select': 'id,subject,bodyPreview',
              r'$orderby': 'lastModifiedDateTime desc',
            },
            stopAfterCleanPage: true);
      }
    } catch (e) {
      debugPrint('Kon Outlook-afsprake vir werksopdrag nie verwyder nie: $e');
    }
  }

  Future<void> _scanAndDeleteEvents(
    Dio dio,
    String marker, {
    Map<String, dynamic>? queryParameters,
    bool stopAfterCleanPage = false,
  }) async {
    Uri? next;
    var foundMatches = false;
    while (true) {
      final response = next == null
          ? await dio.get('/me/events', queryParameters: queryParameters)
          : await dio.getUri(next);
      final data = response.data as Map<String, dynamic>?;
      final events = data?['value'] as List? ?? [];

      var matches = 0;
      for (final ev in events) {
        final evMap = ev as Map<String, dynamic>;
        final subject = evMap['subject'] ?? '';
        final body = evMap['bodyPreview'] ?? '';
        if (subject.contains(marker) || body.contains(marker)) {
          matches++;
          await dio.delete('/me/events/${evMap['id']}');
        }
      }

      if (stopAfterCleanPage && foundMatches && matches == 0) return;
      foundMatches = foundMatches || matches > 0;

      final link = data?['@odata.nextLink'];
      if (link is! String || link.isEmpty) return;
      next = Uri.parse(link);
    }
  }

  Map<String, dynamic>? _buildRecurrence(String? scheduleType, DateTime start) {
    switch (scheduleType) {
      case 'weekliks':
        return {
          'pattern': {
            'type': 'weekly',
            'interval': 1,
            'daysOfWeek': [_graphWeekday(start)],
          },
          'range': {
            'type': 'noEnd',
            'startDate': _graphDate(start),
          },
        };
      case 'maandeliks':
        return {
          'pattern': {
            'type': 'absoluteMonthly',
            'interval': 1,
            'dayOfMonth': start.day,
          },
          'range': {
            'type': 'noEnd',
            'startDate': _graphDate(start),
          },
        };
      case 'jaarliks':
        return {
          'pattern': {
            'type': 'absoluteYearly',
            'interval': 1,
            'dayOfMonth': start.day,
            'month': start.month,
          },
          'range': {
            'type': 'noEnd',
            'startDate': _graphDate(start),
          },
        };
      default:
        return null;
    }
  }

  String _graphDateTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '${_graphDate(dt)}T$h:$m:00';
  }

  String _graphDate(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final mo = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$mo-$d';
  }

  String _graphWeekday(DateTime dt) {
    const days = ['sunday', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday'];
    return days[dt.weekday % 7];
  }
}