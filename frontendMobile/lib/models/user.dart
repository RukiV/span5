/// User model combining fields from both branches.
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
  String get displayName => fullName;

  bool get isActive =>
      status == "active" || status == "Active" || status == "Aktief";

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['user_id'] ?? json['id'],
        name: json['user_name'] ?? json['name'] ?? "",
        surname: json['user_surname'] ?? json['surname'] ?? "",
        email: json['user_email'] ?? json['email'] ?? "",
        number: json['user_number'] ?? json['number'],
        status: json['user_status'] ?? json['status'] ?? "active",
        roleId: json['role_id'] ?? 1,
        locationId: json['location_id'],
        lastLoginTime: json['user_lastlogintime'] ?? json['lastLoginTime'],
      );

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

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! User) return false;
    if (id != null && other.id != null) return id == other.id;
    return email == other.email;
  }

  @override
  int get hashCode => id?.hashCode ?? email.hashCode;
}
