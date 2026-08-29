class Room {
  final int id;
  final String name;
  final String type;
  final int? capacity;
  final int buildingId;
  final int? locationId;
  final String? roomCode;

  Room({
    required this.id,
    required this.name,
    this.type = 'other',
    this.capacity,
    required this.buildingId,
    this.locationId,
    this.roomCode,
  });

  factory Room.fromJson(Map<String, dynamic> json) => Room(
    id: json['room_id'] ?? 0,
    name: json['room_name'] ?? '',
    type: _frontendRoomType(json['room_type'] ?? 'other'),
    capacity: json['room_capacity'],
    buildingId: json['building_id'] ?? 0,
    locationId: json['location_id'],
    roomCode: json['room_code'],
  );

  static String _frontendRoomType(String t) {
    switch (t) {
      case 'CLASSROOM':
      case 'Klaskamer':
        return 'klas';
      case 'LABORATORY':
      case 'Laboratorium':
        return 'laboratorium';
      case 'OFFICE':
      case 'Kantoor':
        return 'kantoor';
      case 'CONFERENCE':
      case 'Konferensiekamer':
        return 'konferensie';
      case 'WAREHOUSE':
      case 'Pakhuis':
        return 'pakhuis';
      case 'BATHROOM':
      case 'Badkamer':
        return 'badkamer';
      case 'OTHER':
      case 'Ander':
        return 'other';
      default:
        return 'other';
    }
  }

  Room copyWith({
    int? id,
    String? name,
    String? type,
    int? capacity,
    int? buildingId,
    int? locationId,
    String? roomCode,
  }) {
    return Room(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      capacity: capacity ?? this.capacity,
      buildingId: buildingId ?? this.buildingId,
      locationId: locationId ?? this.locationId,
      roomCode: roomCode ?? this.roomCode,
    );
  }

  Map<String, dynamic> toJson() => {
    'room_name': name,
    'room_type': _backendRoomType(type),
    'room_capacity': capacity,
    'building_id': buildingId,
    if (roomCode != null) 'room_code': roomCode,
  };

  static String _backendRoomType(String t) {
    switch (t.toLowerCase()) {
      case 'klas':
      case 'klaskamer':
      case 'classroom':
        return 'Klaskamer';
      case 'laboratorium':
      case 'laboratory':
        return 'Laboratorium';
      case 'kantoor':
      case 'office':
        return 'Kantoor';
      case 'konferensie':
      case 'konferensiekamer':
      case 'conference':
        return 'Konferensiekamer';
      case 'pakhuis':
      case 'warehouse':
        return 'Pakhuis';
      case 'badkamer':
      case 'bathroom':
        return 'Badkamer';
      case 'other':
      case 'ander':
        return 'Ander';
      default:
        return t;
    }
  }
}
