import 'package:flutter/material.dart';
import '../models/report.dart';
import 'api/api_client.dart';

// ReportService: Hanteer alle logika vir die skep, haal en opdatering van foutverslae.
class ReportService {
  static final List<Report> _reports = [];
  static final ValueNotifier<List<Report>> reportsNotifier = ValueNotifier(_reports);

  static int get pendingCount => _reports.where((r) => r.phase == "Ontvang" || r.phase == "Besig").length;
  static int get highPriorityCount => _reports.where((r) => r.priority == "Hoog").length;
  static int get completedCount => _reports.where((r) => r.phase == "Voltooi").length;

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

  // Stuur 'n nuwe verslag na die backend
  static Future<bool> addReport(Report report) async {
    try {
      final response = await ApiClient().client.post('/fault', data: report.toJson());
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        final newReport = Report.fromJson(response.data);
        _reports.insert(0, newReport);
        reportsNotifier.value = List.from(_reports);
        return true;
      }
    } catch (e) {
      debugPrint("Fout met byvoeging van verslag: $e");
    }
    return false;
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

  // Dateer slegs die status op
  static Future<bool> updateReportStatus(String id, String phase) async {
    try {
      String backendStatus = "wag";
      if (phase == "Besig") backendStatus = "besig";
      if (phase == "Voltooi") backendStatus = "opgelos";
      if (phase == "Geweier") backendStatus = "verwerp";

      final response = await ApiClient().client.patch('/fault/$id', data: {'fault_status': backendStatus});
      if (response.statusCode == 200) {
        final index = _reports.indexWhere((r) => r.id == id);
        if (index != -1) {
          _reports[index] = _reports[index].copyWith(phase: phase);
          reportsNotifier.value = List.from(_reports);
        }
        return true;
      }
    } catch (e) {
      debugPrint("Fout met status opdatering: $e");
    }
    return false;
  }

  // Dateer slegs die prioriteit op
  static Future<bool> updateReportPriority(String id, String priority) async {
    try {
      String backendPriority = "medium";
      if (priority == "Laag") backendPriority = "low";
      if (priority == "Hoog") backendPriority = "high";

      final response = await ApiClient().client.patch('/fault/$id', data: {'fault_priority': backendPriority});
      if (response.statusCode == 200) {
        final index = _reports.indexWhere((r) => r.id == id);
        if (index != -1) {
          _reports[index] = _reports[index].copyWith(priority: priority);
          reportsNotifier.value = List.from(_reports);
        }
        return true;
      }
    } catch (e) {
      debugPrint("Fout met prioriteit opdatering: $e");
    }
    return false;
  }

  // Goedkeuring (skuif na 'besig' en stel prioriteit)
  static Future<bool> approveReport(String id, String priority, String notes) async {
    try {
      String backendPriority = "medium";
      if (priority == "Laag") backendPriority = "low";
      if (priority == "Hoog") backendPriority = "high";

      final response = await ApiClient().client.patch('/fault/$id', data: {
        'fault_priority': backendPriority,
        'fault_status': 'besig'
      });
      
      if (response.statusCode == 200) {
        final index = _reports.indexWhere((r) => r.id == id);
        if (index != -1) {
          _reports[index] = _reports[index].copyWith(
            priority: priority,
            phase: "Besig",
          );
          reportsNotifier.value = List.from(_reports);
        }
        return true;
      }
    } catch (e) {
      debugPrint("Fout met goedkeuring: $e");
    }
    return false;
  }

  // Verwerp (skuif na 'verwerp')
  static Future<bool> disapproveReport(String id, String notes) async {
    try {
      final response = await ApiClient().client.patch('/fault/$id', data: {'fault_status': 'verwerp'});
      if (response.statusCode == 200) {
        final index = _reports.indexWhere((r) => r.id == id);
        if (index != -1) {
          _reports[index] = _reports[index].copyWith(phase: "Geweier");
          reportsNotifier.value = List.from(_reports);
        }
        return true;
      }
    } catch (e) {
      debugPrint("Fout met verwerping: $e");
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
