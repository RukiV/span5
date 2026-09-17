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
    // Haal die drie lyste gelyktydig, nie agtereenvolgens nie.
    final results = await Future.wait([
      ApiClient().client.get('/location'),
      ApiClient().client.get('/building'),
      ApiClient().client.get('/rooms'),
    ]);
    final locResponse = results[0];
    final buildingResponse = results[1];
    final roomResponse = results[2];

    if (locResponse.statusCode == 200 &&
        buildingResponse.statusCode == 200 &&
        roomResponse.statusCode == 200) {
      final List<dynamic> locData = locResponse.data;
      final List<dynamic> buildingData = buildingResponse.data;
      final List<dynamic> roomData = roomResponse.data;

      // Bou indekskaarte in een deurloop (O(n)) in plaas van geneste
      // .where()-loops (O(n²)) — vinniger op die hoof-isolaat met baie lokale.
      final buildingsByLocation = <int, List<Building>>{};
      final roomsByBuilding = <int, List<Room>>{};
      for (final bJson in buildingData) {
        final bId = bJson['building_id'] as int?;
        final locId = bJson['location_id'] as int?;
        if (bId == null || locId == null) continue;
        buildingsByLocation.putIfAbsent(locId, () => []).add(
            Building.fromJson(bJson));
        roomsByBuilding.putIfAbsent(bId, () => []);
      }
      for (final rJson in roomData) {
        final bId = rJson['building_id'] as int?;
        if (bId == null) continue;
        roomsByBuilding.putIfAbsent(bId, () => []).add(Room.fromJson(rJson));
      }

      final campuses = <Campus>[];
      for (final locJson in locData) {
        final locId = locJson['location_id'] as int?;
        if (locId == null) continue;

        final locationBuildings =
            (buildingsByLocation[locId] ?? const <Building>[])
                .map((b) => b.copyWith(rooms: roomsByBuilding[b.id] ?? const []))
                .toList();

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
