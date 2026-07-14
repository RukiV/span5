import '../services/asset_type_service.dart';

// Asset: Represents a piece of equipment or furniture tracked by the system.
class Asset {
  final String id;
  final String serialCode;
  final String name;
  final String brand;
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
    this.brand = '',
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
    String? brand,
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
      brand: brand ?? this.brand,
      category: category ?? this.category,
      assetTypeId: assetTypeId ?? this.assetTypeId,
      location: location ?? this.location,
      status: status ?? this.status,
      isOutdoor: isOutdoor ?? this.isOutdoor,
    );
  }

  Map<String, dynamic> toJson() => {
    'asset_name': name,
    'asset_brand': brand,
    'asset_status': _backendAssetStatus(status),
    'room_id': int.tryParse(location) ?? 1,
    'assettype_id': assetTypeId,
    'asset_serial': serialCode,
    'asset_isoutdoor': isOutdoor,
  };

  static String _backendAssetStatus(String s) {
    switch (s.toLowerCase()) {
      case 'active':
      case 'aktief':
        return 'Aktief';
      case 'inactive':
      case 'onaktief':
        return 'Onaktief';
      case 'maintenance':
      case 'instandhouding':
      case 'onderhoud':
        return 'Instandhouding';
      case 'retired':
      case 'decommissioned':
      case 'afgedank':
        return 'Afgedank';
      default:
        return s;
    }
  }

  factory Asset.fromJson(Map<String, dynamic> json) {
    final typeId = json['assettype_id'] as int? ?? 1;
    return Asset(
      campus: 'Loading...',
      id: json['asset_id']?.toString() ?? '',
      serialCode: json['asset_serial'] ?? '',
      name: json['asset_name'] ?? 'Unknown Asset',
      brand: json['asset_brand'] ?? '',
      assetTypeId: typeId,
      category: AssetTypeService.getTypeName(typeId),
      location: json['room_id']?.toString() ?? '1',
      status: _frontendAssetStatus(json['asset_status'] ?? 'active'),
      isOutdoor: json['asset_isoutdoor'] == true || json['asset_isoutdoor'] == 1,
    );
  }

  static String _frontendAssetStatus(String s) {
    switch (s) {
      case 'ACTIVE':
      case 'Aktief':
        return 'active';
      case 'INACTIVE':
      case 'Onaktief':
        return 'inactive';
      case 'MAINTENANCE':
      case 'Instandhouding':
        return 'maintenance';
      case 'DECOMMISSIONED':
      case 'Afgedank':
        return 'retired';
      default:
        return s.toLowerCase();
    }
  }
}
