import 'dart:async';
import 'package:flutter/material.dart';
import '../models/user.dart';
import '../models/user_session.dart';
import '../core/api_client.dart';
import 'cached_list_manager.dart';

class AppRole {
  final int id;
  final String name;
  final bool isBuiltin;

  const AppRole({required this.id, required this.name, this.isBuiltin = false});

  factory AppRole.fromJson(Map<String, dynamic> json) => AppRole(
        id: json['role_id'],
        name: json['role_name'] ?? "Rol ${json['role_id']}",
        isBuiltin: json['is_builtin'] ?? false,
      );
}

class UserService {
  static final CachedListManager<User> _usersManager =
      CachedListManager(load: _loadUsers);

  static final CachedListManager<AppRole> _rolesManager =
      CachedListManager(load: _loadRoles);

  static Future<List<User>> _loadUsers() async {
    final response = await ApiClient().client.get('/users');
    if (response.statusCode == 200) {
      final List<dynamic> data = response.data;
      return data.map((json) => User.fromJson(json)).toList();
    }
    throw Exception('Unexpected users response (${response.statusCode})');
  }

  static Future<List<AppRole>> _loadRoles() async {
    final response = await ApiClient().client.get('/roles');
    if (response.statusCode == 200) {
      final List<dynamic> data = response.data;
      return data.map((json) => AppRole.fromJson(json)).toList();
    }
    throw Exception('Unexpected roles response (${response.statusCode})');
  }

  static final ValueNotifier<bool> usersLoadingNotifier = ValueNotifier(false);
  static final ValueNotifier<bool> usersLoadFailedNotifier =
      ValueNotifier(false);

  static ValueNotifier<List<User>> get usersNotifier => _usersManager.notifier;
  static ValueNotifier<List<AppRole>> get rolesNotifier =>
      _rolesManager.notifier;

  @visibleForTesting
  static void resetForTest() {
    _usersManager.reset();
    _rolesManager.reset();
  }

  static List<User> get users => _usersManager.values;

  static Future<void> fetchAssignableUsers() async {
    try {
      final response = await ApiClient().client.get('/users/assignable');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        final items = data.map((json) => User.fromJson(json)).toList();
        _usersManager.replaceAll(items);
      }
    } catch (e) {
      debugPrint("Error loading assignable users: $e");
    }
  }

  static Future<void> fetchUsers() async {
    usersLoadingNotifier.value = true;
    await _usersManager.fetch();
    usersLoadFailedNotifier.value = _usersManager.lastError != null;
    usersLoadingNotifier.value = false;
  }

  static Future<void> fetchRoles() => _rolesManager.fetch();

  static String roleName(int roleId) {
    for (final role in _rolesManager.values) {
      if (role.id == roleId) return role.name;
    }
    return "Rol $roleId";
  }

  static Map<String, dynamic> _redactPayload(Map<String, dynamic> payload) {
    final redacted = Map<String, dynamic>.from(payload);
    if (redacted.containsKey('user_password')) {
      redacted['user_password'] = '***';
    }
    return redacted;
  }

  static Future<bool> addUser(User user, String password) async {
    try {
      final payload = user.toCreateJson(password);
      debugPrint("POST /users payload: ${_redactPayload(payload)}");
      final response = await ApiClient().client.post('/users', data: payload);
      if (response.statusCode == 200 || response.statusCode == 201) {
        await fetchUsers();
        return true;
      }
    } catch (e) {
      debugPrint("Error adding user: $e");
    }
    return false;
  }

  static Future<User?> addContractor(User user, String password) async {
    try {
      final payload = user.toCreateJson(password);
      debugPrint("POST /users/contractors payload: ${_redactPayload(payload)}");
      final response = await ApiClient().client.post('/users/contractors', data: payload);
      if (response.statusCode == 200 || response.statusCode == 201) {
        // Best-effort cache refresh only — never affects the result. FK's lack
        // users.view (GET /users would 403); the created user is returned from
        // the POST body directly.
        unawaited(fetchAssignableUsers());
        final data = response.data;
        if (data is Map<String, dynamic>) return User.fromJson(data);
        debugPrint("Unexpected contractor response: $data");
        return null;
      }
    } catch (e) {
      debugPrint("Error adding contractor: $e");
    }
    return null;
  }

  static Future<bool> updateUser(User user, {String? password}) async {
    try {
      final payload = user.toUpdateJson(password: password);
      debugPrint("PATCH /users/${user.id} payload: ${_redactPayload(payload)}");
      final response =
          await ApiClient().client.patch('/users/${user.id}', data: payload);
      if (response.statusCode == 200) {
        await fetchUsers();
        return true;
      }
    } catch (e) {
      debugPrint("Error updating user: $e");
    }
    return false;
  }

  static Future<bool> deleteUser(int id) async {
    try {
      final response = await ApiClient().client.delete('/users/$id');
      if (response.statusCode == 204 || response.statusCode == 200) {
        await fetchUsers();
        return true;
      }
    } catch (e) {
      debugPrint("Error deleting user: $e");
    }
    return false;
  }

  static String nameFor(int? userId) {
    if (userId == null) return "";
    for (final u in _usersManager.values) {
      if (u.id == userId) return u.displayName;
    }
    return "";
  }

  /// Wisselbare gebruikers vir lokaal-kontrole-skedulering: alle FK-koördineerders
  /// (rol 2) en dosente/professore (rol 5), plus die huidige gebruiker self.
  /// Gesorteer per toegewysde kampus (location_id), dan per naam.
  static List<User> roomCheckAssignable({bool includeSelf = true}) {
    final selfId = UserSession.userId;
    final assignable = UserService.users
        .where((u) =>
            (includeSelf && u.id == selfId) || u.roleId == 2 || u.roleId == 5)
        .toList();

    assignable.sort((a, b) {
      if (a.id == selfId && b.id != selfId) return -1;
      if (b.id == selfId && a.id != selfId) return 1;
      final ca = a.locationId ?? 1 << 30;
      final cb = b.locationId ?? 1 << 30;
      if (ca != cb) return ca.compareTo(cb);
      return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
    });

    return assignable;
  }
}
