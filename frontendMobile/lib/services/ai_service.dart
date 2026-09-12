import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../core/api_client.dart';
import '../models/job_draft.dart';
import 'cached_list_manager.dart';

class AiSuggestion {
  final String value;
  final int? id;
  const AiSuggestion({required this.value, this.id});
}

class AiService {
  static final CachedListManager<JobDraft> _manager = CachedListManager(
    load: _load,
  );

  static String? _statusFilter;

  static Future<List<JobDraft>> _load() async {
    final response = await ApiClient().client.get(
          '/ai',
          queryParameters:
              _statusFilter == null ? null : {'status_filter': _statusFilter},
        );
    if (response.statusCode == 200) {
      final List<dynamic> data = response.data;
      return data.map((json) => JobDraft.fromJson(json)).toList();
    }
    throw Exception('Unexpected AI drafts response (${response.statusCode})');
  }

  static final ValueNotifier<bool> isLoadingNotifier =
      ValueNotifier<bool>(false);

  static ValueNotifier<List<JobDraft>> get draftsNotifier => _manager.notifier;

  @visibleForTesting
  static void resetForTest() =>
      // ignore: invalid_use_of_visible_for_testing_member
      _manager.reset();

  static String? get lastError => _manager.lastError;

  static Future<void> fetchDrafts({String? statusFilter}) async {
    _statusFilter = statusFilter;
    isLoadingNotifier.value = true;
    await _manager.fetch();
    isLoadingNotifier.value = false;
  }

  static Future<List<JobDraft>> draftsRaw({String? statusFilter}) async {
    try {
      final response = await ApiClient().client.get(
            '/ai',
            queryParameters:
                statusFilter == null ? null : {'status_filter': statusFilter},
          );
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) => JobDraft.fromJson(json)).toList();
      }
    } catch (_) {}
    return [];
  }

  static Future<JobDraft?> createDraft(String description) async {
    try {
      final response = await ApiClient().client.post(
        '/ai',
        data: {'description': description},
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return JobDraft.fromJson(response.data);
      }
    } catch (e) {
      _manager.lastError = e.toString();
      debugPrint("Fout met skep van AI-konsep: $e");
    }
    return null;
  }

  static Future<JobDraftDetail?> fetchDraftDetail(int id) async {
    try {
      final response = await ApiClient().client.get('/ai/$id');
      if (response.statusCode == 200) {
        return JobDraftDetail.fromJson(response.data);
      }
    } catch (e) {
      _manager.lastError = e.toString();
      debugPrint("Fout met laai van AI-konsep-detail: $e");
    }
    return null;
  }

  static Future<({bool ok, int? statusCode, String? error})> approveDraft(
    int id, {
    String? cleanedDescription,
    String? title,
    String? workInstruction,
    String? faultType,
    String? faultPriority,
    int? assetId,
    int? roomId,
    int? buildingId,
  }) async {
    try {
      final response = await ApiClient().client.post(
        '/ai/$id/approve',
        data: {
          if (cleanedDescription != null)
            'cleaned_description': cleanedDescription,
          if (title != null) 'title': title,
          if (workInstruction != null) 'work_instruction': workInstruction,
          if (faultType != null) 'fault_type': faultType,
          if (faultPriority != null) 'fault_priority': faultPriority,
          if (assetId != null) 'asset_id': assetId,
          if (roomId != null) 'room_id': roomId,
          if (buildingId != null) 'building_id': buildingId,
        },
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return (ok: true, statusCode: response.statusCode, error: null);
      }
      return (
        ok: false,
        statusCode: response.statusCode,
        error: 'Onbekende fout'
      );
    } on DioException catch (e) {
      return (ok: false, statusCode: e.response?.statusCode, error: e.message);
    } catch (e) {
      debugPrint("Fout met goedkeuring van AI-konsep: $e");
      return (ok: false, statusCode: null, error: e.toString());
    }
  }

  static Future<Map<String, AiSuggestion>> suggest({
    required String context,
    required Map<String, dynamic> fields,
  }) async {
    try {
      final response = await ApiClient().client.post(
        '/ai/suggest',
        data: {'context': context, 'fields': fields},
      );
      if (response.statusCode == 200) {
        final raw = response.data['suggestions'];
        if (raw is Map) {
          return raw.map((k, v) {
            final String value;
            final int? id;
            if (v is Map) {
              value = v['value']?.toString() ?? '';
              id = v['id'] != null ? int.tryParse('${v['id']}') : null;
            } else {
              value = v.toString();
              id = null;
            }
            return MapEntry(k.toString(), AiSuggestion(value: value, id: id));
          });
        }
      }
    } catch (e) {
      debugPrint("Fout met AI-voorstelle: $e");
    }
    return {};
  }

  static Future<({bool ok, int? statusCode, String? error})> rejectDraft(
    int id,
    String reason,
  ) async {
    try {
      final response = await ApiClient().client.post(
        '/ai/$id/reject',
        data: {'reason': reason},
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return (ok: true, statusCode: response.statusCode, error: null);
      }
      return (
        ok: false,
        statusCode: response.statusCode,
        error: 'Onbekende fout'
      );
    } on DioException catch (e) {
      return (ok: false, statusCode: e.response?.statusCode, error: e.message);
    } catch (e) {
      debugPrint("Fout met verwerping van AI-konsep: $e");
      return (ok: false, statusCode: null, error: e.toString());
    }
  }
}
