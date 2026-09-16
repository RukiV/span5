import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../models/campus.dart';
import '../models/building.dart';
import '../models/room.dart';
import '../core/api_client.dart';
import '../core/idempotency.dart';
import 'cached_list_manager.dart';

class CampusService {
  static final CachedListManager<Campus> _manager = CachedListManager(
    load: _load,
  );

  static ValueNotifier<List<Campus>> get campusesNotifier => _manager.notifier;

  /// Laaste laai-fout (bv. bediener-onbereikbaar). Die UI lees dit om 'n
  /// foutboodskap + "Probeer weer"-knoppie te wys na 'n mislukte laai.
  static String? get lastError => _manager.lastError;

  static Future<List<Campus>> _load() async {
    final locResponse = await ApiClient().client.get('/location');
    final buildingResponse = await ApiClient().client.get('/building');
    final roomResponse = await ApiClient().client.get('/rooms');

    if (locResponse.statusCode == 200 &&
        buildingResponse.statusCode == 200 &&
        roomResponse.statusCode == 200) {
      final List<dynamic> locData = locResponse.data;
      final List<dynamic> buildingData = buildingResponse.data;
      final List<dynamic> roomData = roomResponse.data;

      final campuses = <Campus>[];

      for (var locJson in locData) {
        int locId = locJson['location_id'];

        List<Building> locationBuildings =
            buildingData.where((b) => b['location_id'] == locId).map((bJson) {
          int bId = bJson['building_id'];
          List<Room> buildingRooms = roomData
              .where((r) => r['building_id'] == bId)
              .map((r) => Room.fromJson(r))
              .toList();
          return Building.fromJson(bJson).copyWith(rooms: buildingRooms);
        }).toList();

        campuses.add(
            Campus.fromJson(locJson).copyWith(buildings: locationBuildings));
      }

      return campuses;
    }
    throw Exception('Unexpected locations/buildings/rooms response');
  }

  static Future<void> fetchCampuses() => _manager.fetch();

  // --- Helper methods (adapted from old rooms-based approach) ---

  static ({Campus? campus, Building? building, Room? room}) findRoomPath(
      int roomId) {
    for (final campus in _manager.values) {
      for (final building in campus.buildings) {
        for (final room in building.rooms ?? const <Room>[]) {
          if (room.id == roomId) {
            return (campus: campus, building: building, room: room);
          }
        }
      }
    }
    return (campus: null, building: null, room: null);
  }

  static ({Campus? campus, Building? building, Room? room}) findLocationPath(
      int? campusId, int? buildingId, int? roomId) {
    Campus? campus;
    Building? building;
    Room? room;
    for (final c in _manager.values) {
      if (c.id == campusId) {
        campus = c;
        for (final b in c.buildings) {
          if (b.id == buildingId) {
            building = b;
            for (final r in b.rooms ?? const <Room>[]) {
              if (r.id == roomId) room = r;
            }
          }
        }
      }
    }
    return (campus: campus, building: building, room: room);
  }

  static String getRoomName(String roomId) {
    return findRoomPath(int.tryParse(roomId) ?? -1).room?.name ?? "";
  }

  static String getBuildingNameByRoomId(String roomId) {
    return findRoomPath(int.tryParse(roomId) ?? -1).building?.name ?? "";
  }

  static String getCampusNameByRoomId(String roomId) {
    return findRoomPath(int.tryParse(roomId) ?? -1).campus?.name ?? "";
  }

  static String getCampusName(int campusId) {
    for (var campus in _manager.values) {
      if (campus.id == campusId) return campus.name;
    }
    return "";
  }

  static String getBuildingName(int buildingId) {
    for (var campus in _manager.values) {
      for (var building in campus.buildings) {
        if (building.id == buildingId) return building.name;
      }
    }
    return "";
  }

  static Campus? getCampusByName(String name) {
    try {
      return _manager.values.firstWhere(
        (c) => c.name == name || name.contains(c.name),
      );
    } catch (_) {
      return null;
    }
  }

  // --- Campus CRUD ---

  static Future<bool> addCampus(Campus campus, {String? idempotencyKey}) async {
    try {
      final key = idempotencyKey ?? Idempotency.generate();
      final data = campus.toJson();

      final response = await ApiClient().client.post(
            '/location',
            data: data,
            options: Options(headers: {'X-Idempotency-Key': key}),
          );

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
      final response = await ApiClient()
          .client
          .patch('/location/${campus.id}', data: campus.toJson());

      if (response.statusCode == 200) {
        await fetchCampuses();
        return true;
      }
    } catch (e) {
      debugPrint("Error updating campus: $e");
    }
    return false;
  }

  static Future<bool> removeCampus(int id) async {
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

  static Future<bool> addBuilding(
      Building building, {
      String? idempotencyKey,
    }) async {
    try {
      final key = idempotencyKey ?? Idempotency.generate();
      final response = await ApiClient().client.post(
            '/building',
            data: building.toJson(),
            options: Options(headers: {'X-Idempotency-Key': key}),
          );

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
      final response = await ApiClient()
          .client
          .patch('/building/${building.id}', data: building.toJson());

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

  static Future<bool> addRoom(Room room, {String? idempotencyKey}) async {
    try {
      final key = idempotencyKey ?? Idempotency.generate();
      final response = await ApiClient().client.post(
            '/rooms',
            data: room.toJson(),
            options: Options(headers: {'X-Idempotency-Key': key}),
          );
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
      final response = await ApiClient()
          .client
          .patch('/rooms/${room.id}', data: room.toJson());
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
