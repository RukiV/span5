import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../models/report.dart';
import '../core/api_client.dart';
import '../core/idempotency.dart';

// ReportService: Hanteer alle logika vir die skep, haal en opdatering van foutverslae.
class ReportService {
  static final List<Report> _reports = [];
  static final ValueNotifier<List<Report>> reportsNotifier = ValueNotifier(_reports);
  static final ValueNotifier<bool> isLoadingNotifier = ValueNotifier(false);
  static String? lastError;

  // Pending X-Idempotency-Key; reused until the create succeeds, then cleared.
  static String? _pendingKey;

  // Haal alle verslae vanaf die backend
  static Future<void> fetchReports() async {
    isLoadingNotifier.value = true;
    lastError = null;
    try {
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
        _reports.clear();
        _reports.addAll(parsed);
        reportsNotifier.value = List.from(_reports);
      }
    } catch (e) {
      lastError = e.toString();
      debugPrint("Fout met laai van verslae: $e");
    } finally {
      isLoadingNotifier.value = false;
    }
  }

  /// Haal 'n enkele verslag volgens id (GET /fault/{id}) sodat die detail-
  /// bladsy vars kan wys sonder om op die lys se kas staat te maak.
  static Future<Report?> getReportById(String id) async {
    try {
      final response = await ApiClient().client.get('/fault/$id');
      if (response.statusCode == 200) {
        return Report.fromJson(response.data);
      }
    } catch (e) {
      debugPrint("Fout met haal van verslag $id: $e");
    }
    return null;
  }

  // Stuur 'n nuwe verslag na die backend.
  // Gee die geskepte Report terug (met sy fault_id) sodat die oproeper fotos
  // daarna aan die nuwe kaartjie kan koppel; null op mislukking.
  static Future<Report?> addReport(Report report) async {
    try {
      _pendingKey ??= Idempotency.generate();
      final response = await ApiClient().client.post(
        '/fault',
        data: report.toJson(),
        options: Options(headers: {'X-Idempotency-Key': _pendingKey!}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final newReport = Report.fromJson(response.data);
        _reports.insert(0, newReport);
        reportsNotifier.value = List.from(_reports);
        _pendingKey = null;
        return newReport;
      }
    } catch (e) {
      debugPrint("Fout met byvoeging van verslag: $e");
    }
    return null;
  }

  // Dateer 'n verslag op
  static Future<bool> updateReport(Report updatedReport) async {
    try {
      final response = await ApiClient().client.patch('/fault/${updatedReport.id}', data: updatedReport.toUpdateJson());
      if (response.statusCode == 200) {
        final index = _reports.indexWhere((r) => r.id == updatedReport.id);
        if (index != -1) {
          _reports[index] = updatedReport;
          reportsNotifier.value = List.from(_reports);
        }
        return true;
      }
    } catch (e) {
      debugPrint("Fout met opdatering van verslag: $e");
    }
    return false;
  }

  // Verwyder 'n verslag
  static Future<bool> deleteReport(String id) async {
    try {
      final response = await ApiClient().client.delete('/fault/$id');
      if (response.statusCode == 200 || response.statusCode == 204) {
        _reports.removeWhere((r) => r.id == id);
        reportsNotifier.value = List.from(_reports);
        return true;
      }
    } catch (e) {
      debugPrint("Fout met verwydering van verslag: $e");
    }
    return false;
  }
}
