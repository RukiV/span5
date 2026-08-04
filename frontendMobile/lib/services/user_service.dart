import 'package:flutter/material.dart';
import '../models/user.dart';
import '../core/api_client.dart';

class UserService {
  static final List<User> _users = [];
  static final ValueNotifier<List<User>> usersNotifier = ValueNotifier(_users);

  static List<User> get users => List.unmodifiable(_users);

  /// Gebruikers wat aan werksopdragte toegewys kan word of as kontrakteurs vir
  /// kwotasies gekies kan word (backend: GET /users/assignable, geopen vir
  /// jobs.manage/quotes.manage).
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
      debugPrint("Fout met laai van gebruikers: $e");
    }
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
