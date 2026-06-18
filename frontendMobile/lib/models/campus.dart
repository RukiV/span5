import 'package:google_maps_flutter/google_maps_flutter.dart';

class Campus {
  final String id;
  final String name;
  final String code;
  final String address;
  final LatLng location;
  final double radius; 
  final String? imageAsset;
  final List<String> rooms; // Word gestoor as "ID:Name"

  Campus({
    required this.id,
    required this.name,
    required this.code,
    required this.address,
    required this.location,
    this.radius = 110,
    this.imageAsset,
    this.rooms = const [],
  });

  Campus copyWith({
    String? id,
    String? name,
    String? code,
    String? address,
    LatLng? location,
    double? radius,
    String? imageAsset,
    List<String>? rooms,
  }) {
    return Campus(
      id: id ?? this.id,
      name: name ?? this.name,
      code: code ?? this.code,
      address: address ?? this.address,
      location: location ?? this.location,
      radius: radius ?? this.radius,
      imageAsset: imageAsset ?? this.imageAsset,
      rooms: rooms ?? this.rooms,
    );
  }

  Map<String, dynamic> toJson() => {
    'location_name': name,
    'location_type': code,
    'location_streetnum': address.split(' ').first,
    'location_streetname': address.split(' ').skip(1).join(' '),
    'zipcode_id': 1, // Default vir nou
  };

  factory Campus.fromJson(Map<String, dynamic> json) => Campus(
    id: json['location_id']?.toString() ?? '',
    name: json['location_name'] ?? '',
    code: json['location_type'] ?? 'KAMPUS',
    address: "${json['location_streetnum'] ?? ''} ${json['location_streetname'] ?? ''}".trim(),
    location: const LatLng(-25.8480, 28.2366), // Backend stoor nie tans lat/lng in Location nie
    radius: 110.0,
    imageAsset: null,
    rooms: [], // Moet apart gelaai word via rooms endpoint
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Campus && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
