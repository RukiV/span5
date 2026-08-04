class User {
  final int id;
  final String name;
  final String surname;
  final String email;
  final int roleId;

  User({
    required this.id,
    required this.name,
    required this.surname,
    required this.email,
    required this.roleId,
  });

  String get displayName => "${name.trim()} ${surname.trim()}".trim();

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['user_id'] ?? 0,
      name: json['user_name'] ?? '',
      surname: json['user_surname'] ?? '',
      email: json['user_email'] ?? '',
      roleId: json['role_id'] ?? 0,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is User && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
