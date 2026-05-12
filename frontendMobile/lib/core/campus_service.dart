import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/campus.dart';
import 'api_client.dart';

class CampusService {
  static final List<Campus> _campuses = [];
  static final ValueNotifier<List<Campus>> campusesNotifier = ValueNotifier(_campuses);

  static Future<void> fetchCampuses() async {
    try {
      // 1. Laai alle Locations (wat ons as Kampusse sien)
      final locResponse = await ApiClient.dio.get('/location');
      // 2. Laai alle Rooms
      final roomResponse = await ApiClient.dio.get('/rooms');

      if (locResponse.statusCode == 200 && roomResponse.statusCode == 200) {
        final List<dynamic> locData = locResponse.data;
        final List<dynamic> roomData = roomResponse.data;

        _campuses.clear();

        for (var locJson in locData) {
          int locId = locJson['location_id'];
          
          // Filtreer kamers wat aan hierdie ligging behoort
          List<String> locationRooms = roomData
              .where((r) => r['location_id'] == locId)
              .map((r) => r['room_name'].toString())
              .toList();

          _campuses.add(Campus(
            id: locId.toString(),
            name: locJson['location_name'],
            code: locJson['location_type'] ?? 'KAMPUS',
            address: "${locJson['location_streetnum']} ${locJson['location_streetname']}",
            location: const LatLng(-25.8480, 28.2366), // Dummy koördinate, backend het dit nog nie
            rooms: locationRooms,
          ));
        }
        
        campusesNotifier.value = List.from(_campuses);
      }
    } catch (e) {
      debugPrint("Fout met laai van kampusse/lokale: $e");
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
