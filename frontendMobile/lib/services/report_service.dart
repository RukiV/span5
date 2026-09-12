import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../core/api_client.dart';
import '../core/idempotency.dart';
import '../models/report.dart';
import 'cached_list_manager.dart';

class ReportService {
  static final CachedListManager<Report> _manager = CachedListManager(
    load: _load,
  );

  static Future<List<Report>> _load() async {
    final response = await ApiClient().client.get('/fault');
    if (response.statusCode == 200) {
      final List<dynamic> data = response.data;
      final List<Report> parsed = [];
      for (final json in data) {
        try {
          parsed.add(Report.fromJson(json as Map<String, dynamic>));
        } catch (e) {
          debugPrint('Slegs foutkaartjie oorgeslaan: $e');
        }
      }
      return parsed;
    }
    throw Exception('Unexpected reports response (${response.statusCode})');
  }

  static final ValueNotifier<bool> isLoadingNotifier = ValueNotifier(false);

  static ValueNotifier<List<Report>> get reportsNotifier => _manager.notifier;

  @visibleForTesting
  static void resetForTest() =>
      // ignore: invalid_use_of_visible_for_testing_member
      _manager.reset();

  @visibleForTesting
  static String? get lastError => _manager.lastError;

  static Future<void> fetchReports() async {
    isLoadingNotifier.value = true;
    await _manager.fetch();
    isLoadingNotifier.value = false;
  }

  static Future<Report?> addReport(Report report) async {
    try {
      final idempotencyKey = Idempotency.generate();
      final response = await ApiClient().client.post(
            '/fault',
            data: report.toJson(),
            options: Options(headers: {'X-Idempotency-Key': idempotencyKey}),
          );
      if (response.statusCode == 200 || response.statusCode == 201) {
        final newReport = Report.fromJson(response.data);
        final items = List<Report>.from(_manager.values)..insert(0, newReport);
        _manager.replaceAll(items);
        return newReport;
      }
    } catch (e) {
      debugPrint("Fout met byvoeging van verslag: $e");
    }
    return null;
  }

  static Future<bool> updateReport(Report updatedReport) async {
    try {
      final response = await ApiClient().client.patch(
          '/fault/${updatedReport.id}',
          data: updatedReport.toUpdateJson());
      if (response.statusCode == 200) {
        final items = List<Report>.from(_manager.values);
        final index = items.indexWhere((r) => r.id == updatedReport.id);
        if (index != -1) {
          items[index] = updatedReport;
          _manager.replaceAll(items);
        }
        return true;
      }
    } catch (e) {
      debugPrint("Fout met opdatering van verslag: $e");
    }
    return false;
  }

  static Future<bool> deleteReport(String id) async {
    try {
      final response = await ApiClient().client.delete('/fault/$id');
      if (response.statusCode == 200 || response.statusCode == 204) {
        final items = List<Report>.from(_manager.values)
          ..removeWhere((r) => r.id == id);
        _manager.replaceAll(items);
        return true;
      }
    } catch (e) {
      debugPrint("Fout met verwydering van verslag: $e");
    }
    return false;
  }
}
