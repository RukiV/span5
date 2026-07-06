import 'package:flutter/material.dart';
import '../models/campus.dart';
import '../models/building.dart';
import '../models/room.dart';
import 'api_client.dart';

class CampusService {
  static final List<Campus> _campuses = [];
  static final ValueNotifier<List<Campus>> campusesNotifier = ValueNotifier(_campuses);

  static Future<void> fetchCampuses() async {
    try {
      final locResponse = await ApiClient().client.get('/location');
      final buildingResponse = await ApiClient().client.get('/building');
      final roomResponse = await ApiClient().client.get('/rooms');

      if (locResponse.statusCode == 200 &&
          buildingResponse.statusCode == 200 &&
          roomResponse.statusCode == 200) {
        final List<dynamic> locData = locResponse.data;
        final List<dynamic> buildingData = buildingResponse.data;
        final List<dynamic> roomData = roomResponse.data;

        _campuses.clear();

        for (var locJson in locData) {
          int locId = locJson['location_id'];

          List<Building> locationBuildings = buildingData
              .where((b) => b['location_id'] == locId)
              .map((bJson) {
                int bId = bJson['building_id'];
                List<Room> buildingRooms = roomData
                    .where((r) => r['building_id'] == bId)
                    .map((r) => Room.fromJson(r))
                    .toList();
                return Building.fromJson(bJson).copyWith(rooms: buildingRooms);
              })
              .toList();

          _campuses.add(Campus.fromJson(locJson).copyWith(buildings: locationBuildings));
        }

        campusesNotifier.value = List.from(_campuses);
      }
    } catch (e) {
      debugPrint("Error loading locations/buildings/rooms: $e");
    }
  }

  // --- Helper methods (adapted from old rooms-based approach) ---

  static List<Room> getRoomsForCampus(String campusName) {
    try {
      final campus = _campuses.firstWhere(
        (c) => c.name == campusName || campusName.contains(c.name),
      );
      return campus.buildings.expand<Room>((b) => b.rooms ?? <Room>[]).toList();
    } catch (_) {
      return [];
    }
  }

  static String getRoomName(String roomId) {
    for (var campus in _campuses) {
      for (var building in campus.buildings) {
        for (var room in (building.rooms ?? [])) {
          if (room.id.toString() == roomId) {
            return room.name;
          }
        }
      }
    }
    return "Room $roomId";
  }

  static String getCampusNameByRoomId(String roomId) {
    for (var campus in _campuses) {
      for (var building in campus.buildings) {
        for (var room in (building.rooms ?? [])) {
          if (room.id.toString() == roomId) {
            return campus.name;
          }
        }
      }
    }
    return "";
  }

  static Campus? getCampusByName(String name) {
    try {
      return _campuses.firstWhere(
        (c) => c.name == name || name.contains(c.name),
      );
    } catch (_) {
      return null;
    }
  }

  static List<Building> getBuildingsForCampus(String campusName) {
    final campus = getCampusByName(campusName);
    return campus?.buildings ?? [];
  }

  static List<Room> getRoomsForBuilding(int buildingId) {
    for (var campus in _campuses) {
      for (var building in campus.buildings) {
        if (building.id == buildingId) {
          return building.rooms ?? [];
        }
      }
    }
    return [];
  }

  // --- Campus CRUD ---

  static Future<bool> addCampus(Campus campus) async {
    try {
      int defaultZipId = 1;
      try {
        final zipResponse = await ApiClient().client.get('/zipcode');
        if (zipResponse.statusCode == 200 && (zipResponse.data as List).isNotEmpty) {
          defaultZipId = zipResponse.data[0]['zipcode_id'];
        }
      } catch (e) {
        debugPrint("Could not load zipcodes, using default ID 1: $e");
      }

      final parts = campus.address.split(' ');
      final streetNum = parts.isNotEmpty ? parts[0] : "0";
      final streetName = parts.length > 1 ? parts.skip(1).join(' ') : "Unknown";

      final response = await ApiClient().client.post('/location', data: {
        "location_name": campus.name,
        "location_streetnum": streetNum,
        "location_streetname": streetName,
        "location_type": campus.code,
        "zipcode_id": defaultZipId,
      });

      if (response.statusCode == 200 || response.statusCode == 201) {
        await fetchCampuses();
        return true;
      }
    } catch (e) {
      debugPrint("Error adding campus: $e");
    }
    return false;
  }

  static Future<bool> updateCampus(Campus campus) async {
    try {
      final parts = campus.address.split(' ');
      final streetNum = parts.isNotEmpty ? parts[0] : "0";
      final streetName = parts.length > 1 ? parts.skip(1).join(' ') : "Unknown";

      final response = await ApiClient().client.put('/location/${campus.id}', data: {
        "location_name": campus.name,
        "location_streetnum": streetNum,
        "location_streetname": streetName,
        "location_type": campus.code,
        "zipcode_id": 1,
      });

      if (response.statusCode == 200) {
        await fetchCampuses();
        return true;
      }
    } catch (e) {
      debugPrint("Error updating campus: $e");
    }
    return false;
  }

  static Future<bool> removeCampus(String id) async {
    try {
      final response = await ApiClient().client.delete('/location/$id');
      if (response.statusCode == 200 || response.statusCode == 204) {
        await fetchCampuses();
        return true;
      }
    } catch (e) {
      debugPrint("Error deleting campus: $e");
    }
    return false;
  }

  // --- Building CRUD ---

  static Future<bool> addBuilding(Building building) async {
    try {
      final response = await ApiClient().client.post('/building', data: {
        "building_name": building.name,
        "building_type": building.type,
        "building_streetnum": building.streetNum,
        "building_streetname": building.streetName,
        "location_id": building.locationId,
      });

      if (response.statusCode == 200 || response.statusCode == 201) {
        await fetchCampuses();
        return true;
      }
    } catch (e) {
      debugPrint("Error adding building: $e");
    }
    return false;
  }

  static Future<bool> updateBuilding(Building building) async {
    try {
      final response = await ApiClient().client.put('/building/${building.id}', data: {
        "building_name": building.name,
        "building_type": building.type,
        "building_streetnum": building.streetNum,
        "building_streetname": building.streetName,
      });

      if (response.statusCode == 200) {
        await fetchCampuses();
        return true;
      }
    } catch (e) {
      debugPrint("Error updating building: $e");
    }
    return false;
  }

  static Future<bool> removeBuilding(int id) async {
    try {
      final response = await ApiClient().client.delete('/building/$id');
      if (response.statusCode == 200 || response.statusCode == 204) {
        await fetchCampuses();
        return true;
      }
    } catch (e) {
      debugPrint("Error deleting building: $e");
    }
    return false;
  }

  // --- Room CRUD ---

  static Future<bool> addRoom(Room room) async {
    try {
      final response = await ApiClient().client.post('/rooms', data: room.toJson());
      if (response.statusCode == 200 || response.statusCode == 201) {
        await fetchCampuses();
        return true;
      }
    } catch (e) {
      debugPrint("Error adding room: $e");
    }
    return false;
  }

  static Future<bool> updateRoom(Room room) async {
    try {
      final response = await ApiClient().client.put('/rooms/${room.id}', data: room.toJson());
      if (response.statusCode == 200) {
        await fetchCampuses();
        return true;
      }
    } catch (e) {
      debugPrint("Error updating room: $e");
    }
    return false;
  }

  static Future<bool> removeRoom(int id) async {
    try {
      final response = await ApiClient().client.delete('/rooms/$id');
      if (response.statusCode == 200 || response.statusCode == 204) {
        await fetchCampuses();
        return true;
      }
    } catch (e) {
      debugPrint("Error deleting room: $e");
    }
    return false;
  }
}
