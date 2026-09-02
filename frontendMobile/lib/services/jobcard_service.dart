import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../models/jobcard.dart';
import '../models/user_session.dart';
import '../core/api_client.dart';
import '../core/idempotency.dart';

class JobcardService {
  static final List<Jobcard> _jobcards = [];
  static final ValueNotifier<List<Jobcard>> jobcardsNotifier = ValueNotifier(_jobcards);

  static Future<void> fetchJobs() async {
    try {
      final response = await ApiClient().client.get('/job');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        _jobcards.clear();
        
        final List<Jobcard> allJobs = data.map((json) => Jobcard.fromJson(json)).toList();
        
        // As die gebruiker 'n kontrakteur is, sien hulle slegs hul eie toegewysde take.
        if (UserSession.isContractor) {
          _jobcards.addAll(allJobs.where((j) => j.contractorId == UserSession.userId));
        } else {
          _jobcards.addAll(allJobs);
        }

        jobcardsNotifier.value = List.from(_jobcards);
      }
    } catch (e) {
      debugPrint("Fout met laai van werksopdragte: $e");
    }
  }

  static Future<Jobcard?> createJob(Map<String, dynamic> payload) async {
    try {
      final response = await ApiClient().client.post('/job', data: payload);
      if (response.statusCode == 200 || response.statusCode == 201) {
        final created = Jobcard.fromJson(response.data);
        _jobcards.insert(0, created);
        jobcardsNotifier.value = List.from(_jobcards);
        return created;
      }
    } catch (e) {
      debugPrint("Fout met skep van werksopdrag: $e");
    }
    return null;
  }

  static Future<Jobcard?> updateJob(int jobId, Map<String, dynamic> payload) async {
    try {
      final response = await ApiClient().client.patch('/job/$jobId', data: payload);
      if (response.statusCode == 200) {
        final updated = Jobcard.fromJson(response.data);
        final index = _jobcards.indexWhere((j) => j.id == jobId);
        if (index != -1) {
          _jobcards[index] = updated;
          jobcardsNotifier.value = List.from(_jobcards);
        }
        return updated;
      }
    } catch (e) {
      debugPrint("Fout met opdatering van werksopdrag: $e");
    }
    return null;
  }

  /// Kontrakteur stoor sy werknotas by die werksopdrag.
  static Future<bool> updateJobNotes(int jobId, String notes) async {
    try {
      final response = await ApiClient().client.patch('/job/$jobId', data: {'job_notes': notes});
      if (response.statusCode == 200) {
        final updated = Jobcard.fromJson(response.data);
        final index = _jobcards.indexWhere((j) => j.id == jobId);
        if (index != -1) {
          _jobcards[index] = updated;
          jobcardsNotifier.value = List.from(_jobcards);
        }
        return true;
      }
    } catch (e) {
      debugPrint("Fout met stoor van werknotas: $e");
    }
    return false;
  }

  /// Kontrakteur versoek die verantwoordelike personeellid om die werksopdrag
  /// te voltooi. 'n Pending X-Idempotency-Key voorkom duplikaat-versoeke.
  static String? _pendingCompleteKey;

  static Future<bool> requestCompletion(int jobId) async {
    _pendingCompleteKey ??= Idempotency.generate();
    try {
      final response = await ApiClient().client.post(
        '/job/$jobId/complete-request',
        options: Options(headers: {'X-Idempotency-Key': _pendingCompleteKey!}),
      );
      if (response.statusCode == 200) {
        _pendingCompleteKey = null;
        return true;
      }
    } catch (e) {
      debugPrint("Fout met voltooiingsversoek: $e");
    }
    return false;
  }
}
