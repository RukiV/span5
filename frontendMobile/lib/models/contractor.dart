class Contractor {
  final int id;
  final String businessName;
  final String name;
  final String surname;
  final String email;
  final String? phone;
  final String? type;

  Contractor({
    required this.id,
    this.businessName = '',
    required this.name,
    required this.surname,
    required this.email,
    this.phone,
    this.type,
  });

  factory Contractor.fromJson(Map<String, dynamic> json) => Contractor(
    id: json['contractor_id'] ?? 0,
    businessName: json['contractor_businessName'] ?? '',
    name: json['contractor_name'] ?? '',
    surname: json['contractor_surname'] ?? '',
    email: json['contractor_email'] ?? '',
    phone: json['contractor_number'],
    type: json['contractor_type'],
  );

  Map<String, dynamic> toJson() => {
    'contractor_businessName': businessName,
    'contractor_name': name,
    'contractor_surname': surname,
    'contractor_email': email,
    'contractor_number': phone,
    'contractor_type': type,
  };

  String get fullName => '$name $surname';

  Contractor copyWith({
    int? id,
    String? businessName,
    String? name,
    String? surname,
    String? email,
    String? phone,
    String? type,
  }) {
    return Contractor(
      id: id ?? this.id,
      businessName: businessName ?? this.businessName,
      name: name ?? this.name,
      surname: surname ?? this.surname,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      type: type ?? this.type,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Contractor && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
