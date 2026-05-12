import 'package:google_maps_flutter/google_maps_flutter.dart';

class Campus {
  final String id;
  final String name;
  final String code;
  final String address;
  final LatLng location;
  final double radius; 
  final String? imageAsset;
  final List<String> rooms;

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
    'id': id,
    'name': name,
    'code': code,
    'address': address,
    'lat': location.latitude,
    'lng': location.longitude,
    'radius': radius,
    'imageAsset': imageAsset,
    'rooms': rooms,
  };

  factory Campus.fromJson(Map<String, dynamic> json) => Campus(
    id: json['id'],
    name: json['name'],
    code: json['code'],
    address: json['address'],
    location: LatLng(json['lat'], json['lng']),
    radius: (json['radius'] as num).toDouble(),
    imageAsset: json['imageAsset'],
    rooms: List<String>.from(json['rooms'] ?? []),
  );
}
