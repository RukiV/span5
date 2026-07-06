import 'room.dart';

class Building {
  final int id;
  final String name;
  final String streetNum;
  final String streetName;
  final String type;
  final int locationId;
  final List<Room>? rooms;

  Building({
    required this.id,
    required this.name,
    this.streetNum = '',
    this.streetName = '',
    this.type = 'other',
    required this.locationId,
    this.rooms,
  });

  factory Building.fromJson(Map<String, dynamic> json) => Building(
    id: json['building_id'] ?? 0,
    name: json['building_name'] ?? '',
    streetNum: json['building_streetnum'] ?? '',
    streetName: json['building_streetname'] ?? '',
    type: json['building_type'] ?? 'other',
    locationId: json['location_id'] ?? 0,
    rooms: json['rooms'] != null
        ? (json['rooms'] as List).map((r) => Room.fromJson(r)).toList()
        : null,
  );

  Map<String, dynamic> toJson() => {
    'building_name': name,
    'building_type': type,
    'location_id': locationId,
  };

  Building copyWith({
    int? id,
    String? name,
    String? streetNum,
    String? streetName,
    String? type,
    int? locationId,
    List<Room>? rooms,
  }) {
    return Building(
      id: id ?? this.id,
      name: name ?? this.name,
      streetNum: streetNum ?? this.streetNum,
      streetName: streetName ?? this.streetName,
      type: type ?? this.type,
      locationId: locationId ?? this.locationId,
      rooms: rooms ?? this.rooms,
    );
  }

  String get address => '$streetNum $streetName'.trim();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Building && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
