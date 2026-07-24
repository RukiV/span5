import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'building.dart';

class Campus {
  final int id;
  final String name;
  final String code;
  final String streetNum;
  final String streetName;
  final int zipcodeId;
  final LatLng location;
  final double radius;
  final String? imageAsset;
  final List<Building> buildings;

  Campus({
    required this.id,
    required this.name,
    required this.code,
    required this.streetNum,
    required this.streetName,
    this.zipcodeId = 1,
    required this.location,
    this.radius = 110,
    this.imageAsset,
    this.buildings = const [],
  });

  String get address => "$streetNum $streetName".trim();

  Campus copyWith({
    int? id,
    String? name,
    String? code,
    String? streetNum,
    String? streetName,
    int? zipcodeId,
    LatLng? location,
    double? radius,
    String? imageAsset,
    List<Building>? buildings,
  }) {
    return Campus(
      id: id ?? this.id,
      name: name ?? this.name,
      code: code ?? this.code,
      streetNum: streetNum ?? this.streetNum,
      streetName: streetName ?? this.streetName,
      zipcodeId: zipcodeId ?? this.zipcodeId,
      location: location ?? this.location,
      radius: radius ?? this.radius,
      imageAsset: imageAsset ?? this.imageAsset,
      buildings: buildings ?? this.buildings,
    );
  }

  Map<String, dynamic> toJson() => {
    'location_name': name,
    'location_type': code,
    'location_streetnum': streetNum,
    'location_streetname': streetName,
    'zipcode_id': zipcodeId,
  };

  factory Campus.fromJson(Map<String, dynamic> json) => Campus(
    id: json['location_id'] ?? 0,
    name: json['location_name'] ?? '',
    code: json['location_type'] ?? 'KAMPUS',
    streetNum: json['location_streetnum']?.toString() ?? '',
    streetName: json['location_streetname'] ?? '',
    zipcodeId: json['zipcode_id'] ?? 1,
    location: const LatLng(-25.8480, 28.2366),
    radius: 110.0,
    imageAsset: null,
    buildings: json['buildings'] != null
        ? (json['buildings'] as List).map((b) => Building.fromJson(b)).toList()
        : [],
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Campus && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
