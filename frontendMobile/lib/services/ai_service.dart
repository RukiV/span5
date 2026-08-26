import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../core/api_client.dart';
import '../models/job_draft.dart';

/// AiSuggestion: een AI-veldvoorstel — die voorgestelde [value] en opsioneel
/// die [id] van 'n bestaande databasisrekord (bv. 'n assettype of kamer).
class AiSuggestion {
  final String value;
  final int? id;
  const AiSuggestion({required this.value, this.id});
}

// AiService: Hanteer alle logika vir die skep, haal en hersiening van
// AI-werkskonsepte — die goedkeurings-ry voordat 'n konsep 'n werkkaart word.
class AiService {
  static final List<JobDraft> _drafts = [];
  static final ValueNotifier<List<JobDraft>> draftsNotifier = ValueNotifier(_drafts);
  static final ValueNotifier<bool> isLoadingNotifier = ValueNotifier<bool>(false);
  static String? lastError;


  // Haal alle konsepte vanaf die backend, gefiltreer op status (opsioneel).
  // statusFilter: draft | approved | rejected — weggelaat vir almal.
  static Future<void> fetchDrafts({String? statusFilter}) async {
    isLoadingNotifier.value = true;
    lastError = null;
    try {
      final response = await ApiClient().client.get(
        '/ai',
        queryParameters: statusFilter == null ? null : {'status_filter': statusFilter},
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        _drafts.clear();
        _drafts.addAll(data.map((json) => JobDraft.fromJson(json)).toList());
        draftsNotifier.value = List.from(_drafts);
      }
    } catch (e) {
      lastError = e.toString();
      debugPrint("Fout met laai van AI-konsepte: $e");
    } finally {
      isLoadingNotifier.value = false;
    }
  }

  // Haal konsepte sonder om die notifier te dateer — vir badge-tellings.
  static Future<List<JobDraft>> draftsRaw({String? statusFilter}) async {
    try {
      final response = await ApiClient().client.get(
        '/ai',
        queryParameters: statusFilter == null ? null : {'status_filter': statusFilter},
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) => JobDraft.fromJson(json)).toList();
      }
    } catch (_) {}
    return [];
  }

  // Skep 'n nuwe AI-konsep vanaf vrye teks. Gee die geskepte konsep terug;
  // null op mislukking. Word NIE by _drafts gevoeg nie — dit leef in die
  // goedkeurings-ry en word deur die volgende fetchDrafts opgetel.
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
      lastError = e.toString();
      debugPrint("Fout met skep van AI-konsep: $e");
    }
    return null;
  }

  // Haal 'n enkele konsep se detail (insluitend bate- en lokaal-kandidate).
  static Future<JobDraftDetail?> fetchDraftDetail(int id) async {
    try {
      final response = await ApiClient().client.get('/ai/$id');
      if (response.statusCode == 200) {
        return JobDraftDetail.fromJson(response.data);
      }
    } catch (e) {
      lastError = e.toString();
      debugPrint("Fout met laai van AI-konsep-detail: $e");
    }
    return null;
  }

  // Keur 'n konsep goed met opsionele wysigings. 'n 409 beteken die konsep is
  // reeds hersien — die statuskode word deurgegee sodat die UI dit kan wys.
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
          if (cleanedDescription != null) 'cleaned_description': cleanedDescription,
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
      return (ok: false, statusCode: response.statusCode, error: 'Onbekende fout');
    } on DioException catch (e) {
      return (ok: false, statusCode: e.response?.statusCode, error: e.message);
    } catch (e) {
      debugPrint("Fout met goedkeuring van AI-konsep: $e");
      return (ok: false, statusCode: null, error: e.toString());
    }
  }

  // AI-veldvoorstelle: vra die backend vir voorstelle vir leë vormvelde.
  /// [context] = watter tipe vorm ('asset' | 'stock' | 'fault' | 'job' | 'draft');
  /// [fields] = die vorm se HUIDIGE waardes. Die enjin antwoord slegs wanneer
  /// minstens 3 velde ingevul is, en voorsel net LEË velde. Enige fout → {} —
  /// voorstelle is altyd opsioneel en mag nooit die vorm blokkeer nie.
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

  // Verwerp 'n konsep met 'n rede (min. 2 karakters). Selfde terugvoer-vorm as
  // [approveDraft] sodat die 409-hantering een keer geskryf word.
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
      return (ok: false, statusCode: response.statusCode, error: 'Onbekende fout');
    } on DioException catch (e) {
      return (ok: false, statusCode: e.response?.statusCode, error: e.message);
    } catch (e) {
      debugPrint("Fout met verwerping van AI-konsep: $e");
      return (ok: false, statusCode: null, error: e.toString());
    }
  }
}
