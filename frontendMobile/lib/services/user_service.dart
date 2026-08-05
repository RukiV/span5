import 'package:flutter/material.dart';
import '../models/user.dart';
import '../core/api_client.dart';

/// Role information returned by /roles (RoleManageRead).
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

/// UserService: Load and manage users via the /users endpoints.
class UserService {
  static final List<User> _users = [];
  static final ValueNotifier<List<User>> usersNotifier = ValueNotifier(_users);

  static final List<AppRole> _roles = [];
  static final ValueNotifier<List<AppRole>> rolesNotifier = ValueNotifier(_roles);

  static final ValueNotifier<bool> usersLoadingNotifier = ValueNotifier(false);
  static final ValueNotifier<bool> usersLoadFailedNotifier = ValueNotifier(false);
  static final ValueNotifier<bool> rolesLoadingNotifier = ValueNotifier(false);
  static final ValueNotifier<bool> rolesLoadFailedNotifier = ValueNotifier(false);

  static List<User> get users => List.unmodifiable(_users);

  /// Fetch users that can be assigned to jobs or chosen as contractors.
  /// Backend: GET /users/assignable
  static Future<void> fetchAssignableUsers() async {
    try {
      final response = await ApiClient().client.get('/users/assignable');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        _users.clear();
        _users.addAll(data.map((json) => User.fromJson(json)).toList());
        usersNotifier.value = List.from(_users);
      }
    } catch (e) {
      debugPrint("Error loading assignable users: $e");
    }
  }

  static Future<void> fetchUsers() async {
    usersLoadingNotifier.value = true;
    try {
      final response = await ApiClient().client.get('/users');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        _users.clear();
        _users.addAll(data.map((json) => User.fromJson(json)).toList());
        usersNotifier.value = List.from(_users);
        usersLoadFailedNotifier.value = false;
      } else {
        usersLoadFailedNotifier.value = true;
      }
    } catch (e) {
      debugPrint("Error loading users: $e");
      usersLoadFailedNotifier.value = true;
    } finally {
      usersLoadingNotifier.value = false;
    }
  }

  static Future<void> fetchRoles() async {
    rolesLoadingNotifier.value = true;
    try {
      final response = await ApiClient().client.get('/roles');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        _roles.clear();
        _roles.addAll(data.map((json) => AppRole.fromJson(json)).toList());
        rolesNotifier.value = List.from(_roles);
        rolesLoadFailedNotifier.value = false;
      } else {
        rolesLoadFailedNotifier.value = true;
      }
    } catch (e) {
      debugPrint("Error loading roles: $e");
      rolesLoadFailedNotifier.value = true;
    } finally {
      rolesLoadingNotifier.value = false;
    }
  }

  static String roleName(int roleId) {
    for (final role in _roles) {
      if (role.id == roleId) return role.name;
    }
    return "Rol $roleId";
  }

  static Future<bool> addUser(User user, String password) async {
    try {
      final payload = user.toCreateJson(password);
      debugPrint("POST /users payload: $payload");
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

  static Future<bool> updateUser(User user, {String? password}) async {
    try {
      final payload = user.toUpdateJson(password: password);
      debugPrint("PATCH /users/${user.id} payload: $payload");
      final response = await ApiClient().client.patch('/users/${user.id}', data: payload);
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

  static List<User> get contractors => _users.where((u) => u.roleId == 4).toList();

  static String nameFor(int? userId) {
    if (userId == null) return "";
    for (final u in _users) {
      if (u.id == userId) return u.displayName;
    }
    return "";
  }
}
