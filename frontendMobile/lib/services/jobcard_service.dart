import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../models/jobcard.dart';
import '../core/api_client.dart';
import '../core/idempotency.dart';

class JobcardService {
  static final List<Jobcard> _jobcards = [];
  static final ValueNotifier<List<Jobcard>> jobcardsNotifier = ValueNotifier(_jobcards);

  static String? _pendingCreateKey;

  /// Skep 'n nuwe werksopdrag op die backend.
  /// Gee die nuwe jobcard_id terug, of null op mislukking.
  /// 'n Pending X-Idempotency-Key word hergebruik totdat die skep slaag,
  /// sodat spam-taps / retries nooit duplikaat-werksopdragte maak nie.
  static Future<int?> createJobcard(Map<String, dynamic> payload) async {
    _pendingCreateKey ??= Idempotency.generate();
    try {
      final response = await ApiClient().client.post(
        '/job',
        data: payload,
        options: Options(headers: {'X-Idempotency-Key': _pendingCreateKey!}),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        _pendingCreateKey = null;
        await fetchJobs();
        final data = response.data;
        if (data is Map && data['jobcard_id'] != null) {
          return (data['jobcard_id'] as num).toInt();
        }
      }
    } catch (e) {
      debugPrint("Fout met skep van werksopdrag: $e");
    }
    return null;
  }

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
}
