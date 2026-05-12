import 'package:flutter/material.dart';
import '../models/campus.dart';
import 'api_client.dart';

class CampusService {
  static final List<Campus> _campuses = [];
  static final ValueNotifier<List<Campus>> campusesNotifier = ValueNotifier(_campuses);

  static Future<void> fetchCampuses() async {
    try {
      final response = await ApiClient.dio.get('/campuses');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        _campuses.clear();
        _campuses.addAll(data.map((json) => Campus.fromJson(json)).toList());
        campusesNotifier.value = List.from(_campuses);
      }
    } catch (e) {
      debugPrint("Fout met laai van kampusse: $e");
    }
  }

  static Future<bool> addCampus(Campus campus) async {
    try {
      final response = await ApiClient.dio.post('/campuses', data: campus.toJson());
      if (response.statusCode == 200 || response.statusCode == 201) {
        _campuses.add(campus);
        campusesNotifier.value = List.from(_campuses);
        return true;
      }
    } catch (e) {
      debugPrint("Fout met byvoeg van kampus: $e");
    }
    return false;
  }

  static Future<void> removeCampus(String id) async {
    try {
      final response = await ApiClient.dio.delete('/campuses/$id');
      if (response.statusCode == 200) {
        _campuses.removeWhere((c) => c.id == id);
        campusesNotifier.value = List.from(_campuses);
      }
    } catch (e) {
      debugPrint("Fout met verwydering van kampus: $e");
    }
  }

  static Future<void> updateRooms(String campusId, List<String> newRooms) async {
    try {
      final response = await ApiClient.dio.put('/campuses/$campusId/rooms', data: {'rooms': newRooms});
      if (response.statusCode == 200) {
        final index = _campuses.indexWhere((c) => c.id == campusId);
        if (index != -1) {
          _campuses[index] = _campuses[index].copyWith(rooms: newRooms);
          campusesNotifier.value = List.from(_campuses);
        }
      }
    } catch (e) {
      debugPrint("Fout met opdatering van lokale: $e");
    }
  }

  static List<String> getRoomsForCampus(String campusName) {
    try {
      final campus = _campuses.firstWhere((c) => c.name == campusName || campusName.contains(c.name));
      return campus.rooms;
    } catch (_) {
      return [];
    }
  }

  static Campus? getCampusByName(String name) {
    try {
      return _campuses.firstWhere((c) => c.name == name || name.contains(c.name));
    } catch (_) {
      return null;
    }
  }
}
