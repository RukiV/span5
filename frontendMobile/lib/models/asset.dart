// Asset: Represents a piece of equipment or furniture tracked by the system.
class Asset {
  final String id;
  final String serialCode;
  final String name;
  final String category;
  final int assetTypeId;
  final String location; // room_id
  final String status;
  final bool isOutdoor;
  final String campus;

  Asset({
    required this.campus,
    required this.id,
    required this.serialCode,
    required this.name,
    required this.category,
    required this.assetTypeId,
    required this.location,
    required this.status,
    this.isOutdoor = false,
  });

  Asset copyWith({
    String? campus,
    String? id,
    String? serialCode,
    String? name,
    String? category,
    int? assetTypeId,
    String? location,
    String? status,
    bool? isOutdoor,
  }) {
    return Asset(
      campus: campus ?? this.campus,
      id: id ?? this.id,
      serialCode: serialCode ?? this.serialCode,
      name: name ?? this.name,
      category: category ?? this.category,
      assetTypeId: assetTypeId ?? this.assetTypeId,
      location: location ?? this.location,
      status: status ?? this.status,
      isOutdoor: isOutdoor ?? this.isOutdoor,
    );
  }

  Map<String, dynamic> toJson() => {
    'asset_name': name,
    'asset_status': status.toLowerCase(),
    'room_id': int.tryParse(location) ?? 1,
    'assettype_id': assetTypeId,
    'asset_serial': serialCode,
    'asset_isoutdoor': isOutdoor,
  };

  factory Asset.fromJson(Map<String, dynamic> json) {
    final typeId = json['assettype_id'] as int? ?? 1;
    return Asset(
      campus: 'Loading...', 
      id: json['asset_id']?.toString() ?? '',
      serialCode: json['asset_serial'] ?? '',
      name: json['asset_name'] ?? 'Unknown Asset',
      assetTypeId: typeId,
      category: _getCategoryName(typeId),
      location: json['room_id']?.toString() ?? '1',
      status: json['asset_status'] ?? 'active',
      isOutdoor: json['asset_isoutdoor'] == true || json['asset_isoutdoor'] == 1,
    );
  }

  static String _getCategoryName(int id) {
    switch (id) {
      case 1: return "Meubels";
      case 2: return "IT Toerusting";
      case 3: return "Sekuriteit";
      default: return "Algemeen";
    }
  }

  static int getCategoryId(String name) {
    if (name.contains("Meubel")) return 1;
    if (name.contains("IT") || name.contains("Elektron")) return 2;
    if (name.contains("Sekuriteit")) return 3;
    return 1;
  }
}
