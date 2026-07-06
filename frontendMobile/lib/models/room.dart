class Room {
  final int id;
  final String name;
  final String type;
  final int? capacity;
  final int buildingId;

  Room({
    required this.id,
    required this.name,
    this.type = 'other',
    this.capacity,
    required this.buildingId,
  });

  factory Room.fromJson(Map<String, dynamic> json) => Room(
    id: json['room_id'] ?? 0,
    name: json['room_name'] ?? '',
    type: json['room_type'] ?? 'other',
    capacity: json['room_capacity'],
    buildingId: json['building_id'] ?? 0,
  );

  Room copyWith({
    int? id,
    String? name,
    String? type,
    int? capacity,
    int? buildingId,
  }) {
    return Room(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      capacity: capacity ?? this.capacity,
      buildingId: buildingId ?? this.buildingId,
    );
  }

  Map<String, dynamic> toJson() => {
    'room_name': name,
    'room_type': type,
    'room_capacity': capacity,
    'building_id': buildingId,
  };
}
