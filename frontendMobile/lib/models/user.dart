/// User: 'n Gebruiker soos deur die backend se /users eindpunte teruggegee.
/// Weerspieël UserRead in backend/app/models/user.py (geen wagwoord ooit nie).
class User {
  final int? id;
  final String name;
  final String surname;
  final String email;
  final String? number;
  final String status;
  final int roleId;
  final int? locationId;
  final String? lastLoginTime;

  User({
    this.id,
    required this.name,
    required this.surname,
    required this.email,
    this.number,
    this.status = "active",
    required this.roleId,
    this.locationId,
    this.lastLoginTime,
  });

  String get fullName => "$name $surname".trim();

  bool get isActive => status == "active" || status == "Active" || status == "Aktief";

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['user_id'],
        name: json['user_name'] ?? "",
        surname: json['user_surname'] ?? "",
        email: json['user_email'] ?? "",
        number: json['user_number'],
        status: json['user_status'] ?? "active",
        roleId: json['role_id'] ?? 1,
        locationId: json['location_id'],
        lastLoginTime: json['user_lastlogintime'],
      );

  /// Payload vir POST /users (UserCreate — vereis 'n wagwoord).
  Map<String, dynamic> toCreateJson(String password) => {
        'user_name': name,
        'user_surname': surname,
        'user_email': email,
        'user_number': number,
        'user_status': status,
        'role_id': roleId,
        'location_id': locationId,
        'user_password': password,
      };

  /// Payload vir PATCH /users/{id} (UserUpdate — net nie-nul velde).
  Map<String, dynamic> toUpdateJson({String? password}) => {
        'user_name': name,
        'user_surname': surname,
        'user_email': email,
        'user_number': number,
        'user_status': status,
        'role_id': roleId,
        'location_id': locationId,
        if (password != null && password.isNotEmpty) 'user_password': password,
      };
}
