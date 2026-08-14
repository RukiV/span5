import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../models/report.dart';
import '../core/api_client.dart';
import '../core/idempotency.dart';

// ReportService: Hanteer alle logika vir die skep, haal en opdatering van foutverslae.
class ReportService {
  static final List<Report> _reports = [];
  static final ValueNotifier<List<Report>> reportsNotifier = ValueNotifier(_reports);

  // Pending X-Idempotency-Key; reused until the create succeeds, then cleared.
  static String? _pendingKey;

  // Haal alle verslae vanaf die backend
  static Future<void> fetchReports() async {
    try {
      final response = await ApiClient().client.get('/fault');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        _reports.clear();
        _reports.addAll(data.map((json) => Report.fromJson(json)).toList());
        reportsNotifier.value = List.from(_reports);
      }
    } catch (e) {
      debugPrint("Fout met laai van verslae: $e");
    }
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
      final response = await ApiClient().client.patch('/fault/${updatedReport.id}', data: updatedReport.toJson());
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
