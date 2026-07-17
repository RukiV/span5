import 'package:flutter/material.dart';
import '../models/jobcard.dart';
import '../core/api_client.dart';

class JobcardService {
  static final List<Jobcard> _jobcards = [];
  static final ValueNotifier<List<Jobcard>> jobcardsNotifier = ValueNotifier(_jobcards);

  static int get openCount => _jobcards.where((j) => j.status == 'Oop' || j.status == 'Wag').length;
  static int get inProgressCount => _jobcards.where((j) => j.status == 'Besig').length;
  static int get completedCount => _jobcards.where((j) => j.status == 'Voltooi').length;

  static Future<void> fetchJobs() async {
    try {
      final response = await ApiClient().client.get('/job');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        _jobcards.clear();
        _jobcards.addAll(data.map((json) => Jobcard.fromJson(json)).toList());
        jobcardsNotifier.value = List.from(_jobcards);
      }
    } catch (e) {
      debugPrint("Fout met laai van werksopdragte: $e");
    }
  }

  static Future<bool> updateJobStatus(int jobId, String status) async {
    try {
      final backendStatus = Jobcard.toBackendStatus(status);
      final response = await ApiClient().client.patch(
        '/job/$jobId',
        data: {'job_status': backendStatus},
      );
      if (response.statusCode == 200) {
        final index = _jobcards.indexWhere((j) => j.id == jobId);
        if (index != -1) {
          _jobcards[index] = _jobcards[index].copyWith(status: status);
          jobcardsNotifier.value = List.from(_jobcards);
        }
        return true;
      }
    } catch (e) {
      debugPrint("Fout met status opdatering van werksopdrag: $e");
    }
    return false;
  }
}
