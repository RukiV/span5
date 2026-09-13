import 'package:flutter_test/flutter_test.dart';
import 'package:fbs/services/user_service.dart';

import 'test_api_helpers.dart';

void main() {
  initTestApi();

  group('UserService', () {
    test('fetchUsers laai gebruikers suksesvol', () async {
      mockAdapter.onGet('/users', (server) {
        server.reply(200, [
          {
            'user_id': 1,
            'user_name': 'Jan',
            'user_surname': 'Test',
            'user_email': 'jan@test.com',
            'role_id': 2,
          },
          {
            'user_id': 2,
            'user_name': 'Pieter',
            'user_surname': 'Van',
            'user_email': 'pieter@test.com',
            'role_id': 3,
          },
        ]);
      });

      await UserService.fetchUsers();

      expect(UserService.users.length, 2);
      expect(UserService.usersLoadFailedNotifier.value, isFalse);
    });

    test('fetchUsers stel usersLoadFailed op fout', () async {
      mockAdapter.onGet('/users', (server) {
        server.reply(500, {'detail': 'error'});
      });

      await UserService.fetchUsers();

      expect(UserService.usersLoadFailedNotifier.value, isTrue);
      expect(UserService.usersLoadingNotifier.value, isFalse);
    });

    test('fetchAssignableUsers laai assignbare gebruikers', () async {
      mockAdapter.onGet('/users/assignable', (server) {
        server.reply(200, [
          {
            'user_id': 10,
            'user_name': 'Anna',
            'user_surname': 'Bot',
            'user_email': 'anna@test.com',
            'role_id': 2,
          },
        ]);
      });

      await UserService.fetchAssignableUsers();

      expect(UserService.users, isNotEmpty);
      expect(UserService.users.length, 1);
      expect(UserService.usersNotifier.value.length, 1);
    });

    test('fetchRoles laai rolle suksesvol', () async {
      mockAdapter.onGet('/roles', (server) {
        server.reply(200, [
          {'role_id': 1, 'role_name': 'Admin'},
          {'role_id': 2, 'role_name': 'Tegnikus'},
        ]);
      });

      await UserService.fetchRoles();

      expect(UserService.rolesNotifier.value.length, 2);
    });

    test('roleName gee regte naam', () async {
      mockAdapter.onGet('/roles', (server) {
        server.reply(200, [
          {'role_id': 1, 'role_name': 'Admin'},
        ]);
      });

      await UserService.fetchRoles();
      expect(UserService.roleName(1), 'Admin');
      expect(UserService.roleName(999), 'Rol 999');
    });

    test('nameFor gee displayName', () async {
      mockAdapter.onGet('/users', (server) {
        server.reply(200, [
          {
            'user_id': 1,
            'user_name': 'Jan',
            'user_surname': 'Test',
            'user_email': 'jan@test.com',
            'role_id': 1,
          },
        ]);
      });

      await UserService.fetchUsers();
      expect(UserService.nameFor(1), 'Jan Test');
      expect(UserService.nameFor(null), '');
      expect(UserService.nameFor(999), '');
    });
  });
}
