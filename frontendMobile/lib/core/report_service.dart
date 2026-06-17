import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import '../models/report.dart';
import 'api_client.dart';
import 'asset_service.dart';

// ReportService: Handles all logic related to creating, fetching, and updating fault reports.
class ReportService {
  // Notifier to update the UI whenever the report list changes.
  static final List<Report> _reports = [];
  static final ValueNotifier<List<Report>> reportsNotifier = ValueNotifier(_reports);

  // Fetches all fault reports from the backend and updates the local list.
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
      debugPrint("Error loading reports: $e");
    }
  }

  // Sends a new report to the backend. 
  // IMPORTANT: Uses FormData for multipart/form-data to support image uploads.
  static Future<bool> addReport(Report report, File? imageFile) async {
    try {
      final Map<String, dynamic> data = report.toJson();
      
      final formData = FormData.fromMap({
        ...data,
        if (imageFile != null)
          'image': await MultipartFile.fromFile(
            imageFile.path,
            filename: imageFile.path.split('/').last,
          ),
      });

      final response = await ApiClient.dio.post('/fault', data: formData);
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        final newReport = Report.fromJson(response.data);
        _reports.insert(0, newReport); // Add new report to the top of the list
        reportsNotifier.value = List.from(_reports);
        return true;
      }
    } catch (e) {
      debugPrint("Error adding report: $e");
    }
    return false;
  }

  // Updates an existing report using a PATCH request.
  static Future<void> updateReport(Report updatedReport) async {
    try {
      final response = await ApiClient.dio.patch('/fault/${updatedReport.id}', data: updatedReport.toJson());
      if (response.statusCode == 200) {
        final index = _reports.indexWhere((r) => r.id == updatedReport.id);
        if (index != -1) {
          _reports[index] = updatedReport;
          reportsNotifier.value = List.from(_reports);
        }
      }
    } catch (e) {
      debugPrint("Error updating report: $e");
    }
  }

  // Updates only the status (phase) of a report.
  static Future<bool> updateReportStatus(String id, String phase) async {
    try {
      // Mapping frontend state names to backend enum values
      String backendStatus = "wag";
      if (phase == "Besig") backendStatus = "besig";
      if (phase == "Voltooi") backendStatus = "opgelos";
      if (phase == "Geweier") backendStatus = "verwerp";

      final response = await ApiClient.dio.patch('/fault/$id', data: {'fault_status': backendStatus});
      if (response.statusCode == 200) {
        final index = _reports.indexWhere((r) => r.id == id);
        if (index != -1) {
          _reports[index] = _reports[index].copyWith(phase: phase);
          reportsNotifier.value = List.from(_reports);
        }
        return true;
      }
    } catch (e) {
      debugPrint("Error updating status: $e");
    }
    return false;
  }

  // Updates the priority level of a report.
  static Future<bool> updateReportPriority(String id, String priority) async {
    try {
      String backendPriority = "medium";
      if (priority == "Laag") backendPriority = "low";
      if (priority == "Hoog") backendPriority = "high";

      final response = await ApiClient.dio.patch('/fault/$id', data: {'fault_priority': backendPriority});
      if (response.statusCode == 200) {
        final index = _reports.indexWhere((r) => r.id == id);
        if (index != -1) {
          _reports[index] = _reports[index].copyWith(priority: priority);
          reportsNotifier.value = List.from(_reports);
        }
        return true;
      }
    } catch (e) {
      debugPrint("Error updating priority: $e");
    }
    return false;
  }

  // Approves a report, sets priority, and adds admin notes.
  static Future<void> approveReport(String id, String priority, String adminNotes) async {
    final index = _reports.indexWhere((r) => r.id == id);
    if (index != -1) {
      final updatedReport = _reports[index].copyWith(
        priority: priority,
        phase: 'Besig',
        adminNotes: adminNotes,
      );
      await updateReport(updatedReport);
      
      // Links the report to an asset upon approval if applicable.
      if (updatedReport.assetId != 'ONSIGBAAR') {
        await AssetService.linkReportToAsset(updatedReport.assetId, updatedReport.id);
      }
    }
  }

  // Disapproves a report and adds the reason in the admin notes.
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

  // Stats getters for dashboard summaries
  static int get count => reportsNotifier.value.length;
  static int get pendingCount => reportsNotifier.value.where((r) => r.phase != 'Voltooi').length;
  static int get highPriorityCount => reportsNotifier.value.where((r) => r.priority == 'Hoog').length;
  
  // FUTURE IDEA: Implement a local SQLite cache for 'Offline-First' reporting support.
}
