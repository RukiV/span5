import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import '../models/report.dart';
import 'api_client.dart';
import 'asset_service.dart';

class ReportService {
  static final List<Report> _reports = [];
  static final ValueNotifier<List<Report>> reportsNotifier = ValueNotifier(_reports);

  static Future<void> fetchReports() async {
    try {
      final response = await ApiClient.dio.get('/fault');
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

  static Future<bool> addReport(Report report, File? imageFile) async {
    try {
      // Vir nou stuur ons net die JSON data aangesien die backend dalk nie 
      // Multipart/Form-data vir FaultcardCreate ondersteun nie (dit gebruik Pydantic model)
      final response = await ApiClient.dio.post('/fault', data: report.toJson());
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        final newReport = Report.fromJson(response.data);
        _reports.insert(0, newReport);
        reportsNotifier.value = List.from(_reports);
        return true;
      }
    } catch (e) {
      debugPrint("Fout met byvoeg van verslag: $e");
    }
    return false;
  }

  static Future<void> updateReport(Report updatedReport) async {
    try {
      // Gebruik PATCH soos per backend endpoint
      final response = await ApiClient.dio.patch('/fault/${updatedReport.id}', data: updatedReport.toJson());
      if (response.statusCode == 200) {
        final index = _reports.indexWhere((r) => r.id == updatedReport.id);
        if (index != -1) {
          _reports[index] = updatedReport;
          reportsNotifier.value = List.from(_reports);
        }
      }
    } catch (e) {
      debugPrint("Fout met opdatering van verslag: $e");
    }
  }

  static Future<void> approveReport(String id, String priority, String adminNotes) async {
    final index = _reports.indexWhere((r) => r.id == id);
    if (index != -1) {
      final updatedReport = _reports[index].copyWith(
        priority: priority,
        phase: 'Besig',
        adminNotes: adminNotes,
      );
      await updateReport(updatedReport);
      
      // Koppel die verslag aan die bate as dit goedgekeur word
      if (updatedReport.assetId != 'ONSIGBAAR') {
        await AssetService.linkReportToAsset(updatedReport.assetId, updatedReport.id);
      }
    }
  }

  static Future<void> disapproveReport(String id, String adminNotes) async {
    final index = _reports.indexWhere((r) => r.id == id);
    if (index != -1) {
      final updatedReport = _reports[index].copyWith(
        phase: 'Geweier',
        adminNotes: adminNotes,
      );
      await updateReport(updatedReport);
    }
  }

  static int get count => reportsNotifier.value.length;
  static int get pendingCount => reportsNotifier.value.where((r) => r.phase != 'Voltooi').length;
  static int get highPriorityCount => reportsNotifier.value.where((r) => r.priority == 'Hoog').length;
}
