import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'outlook_token_manager.dart';

/// OutlookService: Direkte MS Graph-kalenderoproepe, dieselfde as die web se
/// CalendarPage/WorkOrderPage (frontend/src/pages/...). Die Graph-token kom
/// vanaf [OutlookTokenManager]. Alle oproepe degradeer grasieus (log + leë
/// resultaat) sodat 'n ontbrekende Outlook-sessie die app nooit blokkeer nie.
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

  /// Haal die gebruiker se Outlook-kalender vir [start]..[end] op en gee dit
  /// terug in dieselfde JSON-vorm as die backend se /calendar/events, sodat
  /// CalendarService dit deur CalendarEvent.fromJson kan laat loop.
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

  /// Sinkroniseer 'n plaaslike afspraak na Outlook. Gee die nuwe
  /// Outlook-event-ID terug, of null by fout.
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

  /// Verwyder 'n Outlook-afspraak by sy Graph-ID.
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

  /// Skep 'n Outlook-afspraak vir 'n geskeduleerde werksopdrag, met dieselfde
  /// `FBS-WO-<id>`-merker as die web se WorkOrderPage.
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

  /// Verwyder alle Outlook-afsprake wat die `FBS-WO-<id>`-merker dra.
  ///
  /// Gebruik 'n verfynde navraag (`$filter` op die onderwerp) asook
  /// `$orderby=lastModifiedDateTime` en `@odata.nextLink`-deurblaaiing eerder
  /// as om die eerste 100 gebeurtenisse blind te skandeer, sodat 'n besige
  /// kalender die merker-afspraak nie verberg nie. As die onderwerp-filter nie
  /// deur die kliënt se Graph ondersteun word nie, word teruggeval op 'n
  /// gesorteerde deurblaai tot die merker gevind is. Enige mislukking word
  /// gerapporteer en nooit na bo opgewers nie (die stoor van die werksopdrag
  /// word dus nooit geblokkeer nie).
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

  /// Blaai deur `/me/events` en verwyder elke gebeurtenis wat [marker] in sy
  /// onderwerp of liggaam dra. Eerste bladsy gebruik [queryParameters]; latere
  /// bladsye volg die bediener se `@odata.nextLink`.
  ///
  /// Keer normaal terug wanneer die deurblaai voltooi is en gooi 'n
  /// [DioException] by 'n Graph-fout. As [stopAfterCleanPage] waar is en daar
  /// reeds 'n treffer was ('n bladsy met merker-afsprake), word daar gestop
  /// sodra 'n volgende bladsy niks meer bevat nie.
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
