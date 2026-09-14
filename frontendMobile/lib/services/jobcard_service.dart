import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../core/api_client.dart';
import '../core/idempotency.dart';
import '../models/jobcard.dart';
import '../models/user_session.dart';
import 'cached_list_manager.dart';

class JobcardService {
  static final CachedListManager<Jobcard> _manager = CachedListManager(
    load: _load,
  );

  static String? _pendingCompleteKey;

  static Future<List<Jobcard>> _load() async {
    final response = await ApiClient().client.get('/job');
    if (response.statusCode == 200) {
      final List<dynamic> data = response.data;
      final allJobs = data.map((json) => Jobcard.fromJson(json)).toList();
      if (UserSession.isContractor) {
        return allJobs
            .where((j) => j.contractorId == UserSession.userId)
            .toList();
      }
      return allJobs;
    }
    throw Exception('Unexpected jobcards response (${response.statusCode})');
  }

  static ValueNotifier<List<Jobcard>> get jobcardsNotifier => _manager.notifier;

  @visibleForTesting
  static void resetForTest() =>
      _manager.reset();

  static Future<void> fetchJobs() => _manager.fetch();

  static Future<Jobcard?> createJob(
      Map<String, dynamic> payload, {
      String? idempotencyKey,
    }) async {
    try {
      final key = idempotencyKey ?? Idempotency.generate();
      final response = await ApiClient().client.post(
            '/job',
            data: payload,
            options: Options(headers: {'X-Idempotency-Key': key}),
          );
      if (response.statusCode == 200 || response.statusCode == 201) {
        final created = Jobcard.fromJson(response.data);
        final items = List<Jobcard>.from(_manager.values)..insert(0, created);
        _manager.replaceAll(items);
        return created;
      }
    } catch (e) {
      debugPrint("Fout met skep van werksopdrag: $e");
    }
    return null;
  }

  static Future<Jobcard?> updateJob(
      int jobId, Map<String, dynamic> payload) async {
    try {
      final response =
          await ApiClient().client.patch('/job/$jobId', data: payload);
      if (response.statusCode == 200) {
        final updated = Jobcard.fromJson(response.data);
        final items = List<Jobcard>.from(_manager.values);
        final index = items.indexWhere((j) => j.id == jobId);
        if (index != -1) {
          items[index] = updated;
          _manager.replaceAll(items);
        }
        return updated;
      }
    } catch (e) {
      debugPrint("Fout met opdatering van werksopdrag: $e");
    }
    return null;
  }

  static Future<bool> updateJobNotes(int jobId, String notes) async {
    try {
      final response = await ApiClient()
          .client
          .patch('/job/$jobId', data: {'job_notes': notes});
      if (response.statusCode == 200) {
        final updated = Jobcard.fromJson(response.data);
        final items = List<Jobcard>.from(_manager.values);
        final index = items.indexWhere((j) => j.id == jobId);
        if (index != -1) {
          items[index] = updated;
          _manager.replaceAll(items);
        }
        return true;
      }
    } catch (e) {
      debugPrint("Fout met stoor van werknotas: $e");
    }
    return false;
  }

  static Future<bool> deleteJob(int jobId) async {
    try {
      final response = await ApiClient().client.delete('/job/$jobId');
      if (response.statusCode == 204 || response.statusCode == 200) {
        final items = List<Jobcard>.from(_manager.values)
          ..removeWhere((j) => j.id == jobId);
        _manager.replaceAll(items);
        return true;
      }
    } catch (e) {
      debugPrint("Fout met verwydering van werksopdrag: $e");
    }
    return false;
  }

  static Future<bool> requestCompletion(int jobId) async {
    _pendingCompleteKey ??= Idempotency.generate();
    try {
      final response = await ApiClient().client.post(
            '/job/$jobId/complete-request',
            options:
                Options(headers: {'X-Idempotency-Key': _pendingCompleteKey!}),
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
}