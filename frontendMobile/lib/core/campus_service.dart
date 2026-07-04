<<<<<<< HEAD
import 'package:flutter/material.dart';
import '../models/campus.dart';
import 'api_client.dart';

// CampusService: Manages campus locations and their associated rooms.
class CampusService {
  // Notifier to allow UI components to react to campus list changes.
  static final List<Campus> _campuses = [];
  static final ValueNotifier<List<Campus>> campusesNotifier = ValueNotifier(_campuses);

  // Fetches campuses and rooms, then maps rooms to their respective campuses.
  static Future<void> fetchCampuses() async {
    try {
      // 1. Load all Locations (treated as Campuses in the mobile app)
      final locResponse = await ApiClient.dio.get('/location');
      // 2. Load all Rooms
      final roomResponse = await ApiClient.dio.get('/rooms');

      if (locResponse.statusCode == 200 && roomResponse.statusCode == 200) {
        final List<dynamic> locData = locResponse.data;
        final List<dynamic> roomData = roomResponse.data;

        _campuses.clear();

        for (var locJson in locData) {
          int locId = locJson['location_id'];
          
          // Map rooms to the campus based on the location_id foreign key
          List<String> locationRooms = roomData
              .where((r) => r['location_id'] == locId)
              .map((r) => "${r['room_id']}:${r['room_name']}")
              .toList();

          _campuses.add(Campus.fromJson(locJson).copyWith(rooms: locationRooms));
        }
        
        campusesNotifier.value = List.from(_campuses);
      }
    } catch (e) {
      debugPrint("Error loading campuses/rooms: $e");
    }
  }

  // Returns rooms for a specific campus name
  static List<String> getRoomsForCampus(String campusName) {
    try {
      final campus = _campuses.firstWhere((c) => c.name == campusName || campusName.contains(c.name));
      return campus.rooms;
    } catch (_) {
      return [];
    }
  }

  // Helper to get a human-readable room name from an ID
  static String getRoomName(String roomId) {
    for (var campus in _campuses) {
      for (var room in campus.rooms) {
        if (room.startsWith("$roomId:")) {
          return room.split(":").last;
        }
      }
    }
    return "Room $roomId";
  }

  // FUTURE IDEA: Add a method to fetch a single campus details with its GPS center point.
  static Campus? getCampusByName(String name) {
    try {
      return _campuses.firstWhere((c) => c.name == name || name.contains(c.name));
    } catch (_) {
      return null;
    }
  }

  // Adds a new campus and its rooms to the backend.
  static Future<bool> addCampus(Campus campus) async {
    try {
      // Attempt to get a default zipcode or use ID 1 from seed data.
      int defaultZipId = 1;
      try {
        final zipResponse = await ApiClient.dio.get('/zipcode');
        if (zipResponse.statusCode == 200 && (zipResponse.data as List).isNotEmpty) {
          defaultZipId = zipResponse.data[0]['zipcode_id'];
        }
      } catch (e) {
        debugPrint("Could not load zipcodes, using default ID 1: $e");
      }

      // Parse address into street number and name as required by the backend schema.
      final parts = campus.address.split(' ');
      final streetNum = parts.isNotEmpty ? parts[0] : "0";
      final streetName = parts.length > 1 ? parts.skip(1).join(' ') : "Unknown";

      final response = await ApiClient.dio.post('/location', data: {
        "location_name": campus.name,
        "location_streetnum": streetNum,
        "location_streetname": streetName,
        "location_type": campus.code,
        "zipcode_id": defaultZipId,
      });

      if (response.statusCode == 200 || response.statusCode == 201) {
        final locId = response.data['location_id'];
        // Batch create the rooms for this location.
        for (var room in campus.rooms) {
          await ApiClient.dio.post('/rooms', data: {
            "room_name": room,
            "location_id": locId,
            "room_type": "other",
            "room_capacity": 30
          });
        }
        await fetchCampuses();
        return true;
      }
    } catch (e) {
      debugPrint("Error adding campus: $e");
    }
    return false;
  }

  // Updates the room list for a specific campus.
  static Future<bool> updateRooms(String campusId, List<String> updatedRooms) async {
    try {
      final campus = _campuses.firstWhere((c) => c.id == campusId);
      final newRooms = updatedRooms.where((r) => !campus.rooms.contains(r)).toList();

      for (var roomName in newRooms) {
        await ApiClient.dio.post('/rooms', data: {
          "room_name": roomName,
          "location_id": int.parse(campusId),
          "room_type": "other",
          "room_capacity": 30
        });
      }
      await fetchCampuses();
      return true;
    } catch (e) {
      debugPrint("Error updating rooms: $e");
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
      debugPrint("Error deleting campus: $e");
    }
    return false;
  }
}
=======
import 'package:flutter/material.dart';
import '../models/campus.dart';
import 'api/api_client.dart';

// CampusService: Manages campus locations and their associated rooms.
class CampusService {
  // Notifier to allow UI components to react to campus list changes.
  static final List<Campus> _campuses = [];
  static final ValueNotifier<List<Campus>> campusesNotifier = ValueNotifier(_campuses);

  // Fetches campuses and rooms, then maps rooms to their respective campuses.
  static Future<void> fetchCampuses() async {
    try {
      // 1. Load all Locations (treated as Campuses in the mobile app)
      final locResponse = await ApiClient().client.get('/location');
      // 2. Load all Rooms
      final roomResponse = await ApiClient().client.get('/rooms');

      if (locResponse.statusCode == 200 && roomResponse.statusCode == 200) {
        final List<dynamic> locData = locResponse.data;
        final List<dynamic> roomData = roomResponse.data;

        _campuses.clear();

        for (var locJson in locData) {
          int locId = locJson['location_id'];
          
          // Map rooms to the campus based on the location_id foreign key
          List<String> locationRooms = roomData
              .where((r) => r['location_id'] == locId)
              .map((r) => "${r['room_id']}:${r['room_name']}")
              .toList();

          _campuses.add(Campus.fromJson(locJson).copyWith(rooms: locationRooms));
        }
        
        campusesNotifier.value = List.from(_campuses);
      }
    } catch (e) {
      debugPrint("Error loading campuses/rooms: $e");
    }
  }

  // Returns rooms for a specific campus name
  static List<String> getRoomsForCampus(String campusName) {
    try {
      final campus = _campuses.firstWhere((c) => c.name == campusName || campusName.contains(c.name));
      return campus.rooms;
    } catch (_) {
      return [];
    }
  }

  // Helper to get a human-readable room name from an ID
  static String getRoomName(String roomId) {
    for (var campus in _campuses) {
      for (var room in campus.rooms) {
        if (room.startsWith("$roomId:")) {
          return room.split(":").last;
        }
      }
    }
    return "Room $roomId";
  }

  // Helper to get campus name from room ID
  static String getCampusNameByRoomId(String roomId) {
    for (var campus in _campuses) {
      for (var room in campus.rooms) {
        if (room.startsWith("$roomId:")) {
          return campus.name;
        }
      }
    }
    return "";
  }

  // FUTURE IDEA: Add a method to fetch a single campus details with its GPS center point.
  static Campus? getCampusByName(String name) {
    try {
      return _campuses.firstWhere((c) => c.name == name || name.contains(c.name));
    } catch (_) {
      return null;
    }
  }

  // Adds a new campus and its rooms to the backend.
  static Future<bool> addCampus(Campus campus) async {
    try {
      // Attempt to get a default zipcode or use ID 1 from seed data.
      int defaultZipId = 1;
      try {
        final zipResponse = await ApiClient().client.get('/zipcode');
        if (zipResponse.statusCode == 200 && (zipResponse.data as List).isNotEmpty) {
          defaultZipId = zipResponse.data[0]['zipcode_id'];
        }
      } catch (e) {
        debugPrint("Could not load zipcodes, using default ID 1: $e");
      }

      // Parse address into street number and name as required by the backend schema.
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
        final locId = response.data['location_id'];
        // Batch create the rooms for this location.
        for (var room in campus.rooms) {
          await ApiClient().client.post('/rooms', data: {
            "room_name": room,
            "location_id": locId,
            "room_type": "other",
            "room_capacity": 30
          });
        }
        await fetchCampuses();
        return true;
      }
    } catch (e) {
      debugPrint("Error adding campus: $e");
    }
    return false;
  }

  // Updates campus details on the backend.
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
        "zipcode_id": 1, // Default or fetch from somewhere
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

  // Updates the room list for a specific campus.
  static Future<bool> updateRooms(String campusId, List<String> updatedRooms) async {
    try {
      final campus = _campuses.firstWhere((c) => c.id == campusId);
      final newRooms = updatedRooms.where((r) => !campus.rooms.contains(r)).toList();

      for (var roomName in newRooms) {
        await ApiClient().client.post('/rooms', data: {
          "room_name": roomName,
          "location_id": int.parse(campusId),
          "room_type": "other",
          "room_capacity": 30
        });
      }
      await fetchCampuses();
      return true;
    } catch (e) {
      debugPrint("Error updating rooms: $e");
      return false;
    }
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
}
>>>>>>> 3080162a6b51675de2ce74fa53f3bd629f39db17
