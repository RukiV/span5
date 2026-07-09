import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'building.dart';

class Campus {
  final int id;
  final String name;
  final String code;
  final String streetNum;
  final String streetName;
  final String suburb;
  final String city;
  final String province;
  final String country;
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
    this.suburb = '',
    this.city = '',
    this.province = '',
    this.country = '',
    required this.location,
    this.radius = 110,
    this.imageAsset,
    this.buildings = const [],
  });

  String get address {
    final parts = ["$streetNum $streetName".trim()];
    if (suburb.isNotEmpty) parts.add(suburb);
    if (city.isNotEmpty) parts.add(city);
    if (province.isNotEmpty) parts.add(province);
    if (country.isNotEmpty) parts.add(country);
    return parts.join(", ");
  }

  Campus copyWith({
    int? id,
    String? name,
    String? code,
    String? streetNum,
    String? streetName,
    String? suburb,
    String? city,
    String? province,
    String? country,
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
      suburb: suburb ?? this.suburb,
      city: city ?? this.city,
      province: province ?? this.province,
      country: country ?? this.country,
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
    'location_suburb': suburb,
    'location_city': city,
    'location_province': province,
    'location_country': country,
  };

  factory Campus.fromJson(Map<String, dynamic> json) => Campus(
    id: json['location_id'] ?? 0,
    name: json['location_name'] ?? '',
    code: json['location_type'] ?? 'KAMPUS',
    streetNum: json['location_streetnum']?.toString() ?? '',
    streetName: json['location_streetname'] ?? '',
    suburb: json['location_suburb'] ?? '',
    city: json['location_city'] ?? '',
    province: json['location_province'] ?? '',
    country: json['location_country'] ?? '',
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
