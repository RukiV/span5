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

  static Future<bool> addCampus(Campus campus) async {
    try {
      // Backend verwag gewoonlik 'location' data vir 'Campus'
      final response = await ApiClient.dio.post('/location', data: {
        "location_name": campus.name,
        "location_streetnum": campus.address.split(' ').first,
        "location_streetname": campus.address.split(' ').skip(1).join(' '),
        "location_type": campus.code,
      });

      if (response.statusCode == 200 || response.statusCode == 201) {
        final locId = response.data['location_id'];
        // Voeg ook die kamers by as daar is
        for (var room in campus.rooms) {
          await ApiClient.dio.post('/rooms', data: {
            "room_name": room,
            "location_id": locId,
          });
        }
        await fetchCampuses();
        return true;
      }
    } catch (e) {
      debugPrint("Fout met byvoeg van kampus: $e");
    }
    return false;
  }

  static Future<bool> updateRooms(String campusId, List<String> updatedRooms) async {
    try {
      // Hierdie is 'n vereenvoudigde weergawe. In 'n regte scenario sou jy 
      // dalk kamers uitvee en her-byvoeg of 'n spesifieke sync endpoint hê.
      // Vir nou, voeg ons net die nuwes by wat nie bestaan nie.
      final campus = _campuses.firstWhere((c) => c.id == campusId);
      final newRooms = updatedRooms.where((r) => !campus.rooms.contains(r)).toList();

      for (var roomName in newRooms) {
        await ApiClient.dio.post('/rooms', data: {
          "room_name": roomName,
          "location_id": int.parse(campusId),
        });
      }
      await fetchCampuses();
      return true;
    } catch (e) {
      debugPrint("Fout met opdatering van kamers: $e");
      return false;
    }
  }

  static Future<bool> removeCampus(String id) async {
    try {
      final response = await ApiClient.dio.delete('/location/$id');
      if (response.statusCode == 200 || response.statusCode == 204) {
        await fetchCampuses();
        return true;
      }
    } catch (e) {
      debugPrint("Fout met verwydering van kampus: $e");
    }
    return false;
  }
}
