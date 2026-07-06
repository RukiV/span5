// Asset: Represents a piece of equipment or furniture tracked by the system.
class Asset {
  final String id;
  final String serialCode;
  final String name;
  final String category;
  final int assetTypeId; // Added to maintain backend parity
  final String location; // Corresponds to room_id on the backend
  final String status;
  final DateTime purchaseDate;
  final DateTime campusStartDate;
  final String campus; 
  final List<String> warrantyReceipts;
  final List<String> reportIds;

  Asset({
    required this.campus,
    required this.id,
    required this.serialCode,
    required this.name,
    required this.category,
    required this.assetTypeId,
    required this.location,
    required this.status,
    required this.purchaseDate,
    required this.campusStartDate,
    List<String>? warrantyReceipts,
    List<String>? reportIds,
  })  : warrantyReceipts = warrantyReceipts ?? [],
        reportIds = reportIds ?? [];

  // Creates a copy of the asset with optional updated fields.
  Asset copyWith({
    String? campus,
    String? id,
    String? serialCode,
    String? name,
    String? category,
    int? assetTypeId,
    String? location,
    String? status,
    DateTime? purchaseDate,
    DateTime? campusStartDate,
    List<String>? warrantyReceipts,
    List<String>? reportIds,
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
      purchaseDate: purchaseDate ?? this.purchaseDate,
      campusStartDate: campusStartDate ?? this.campusStartDate,
      warrantyReceipts: warrantyReceipts ?? this.warrantyReceipts,
      reportIds: reportIds ?? this.reportIds,
    );
  }

  // Converts the object into a JSON-friendly map for backend updates.
  Map<String, dynamic> toJson() => {
    'asset_name': name,
    'asset_status': status.toLowerCase(),
    'room_id': int.tryParse(location) ?? 1,
    'assettype_id': assetTypeId, // Use the stored ID instead of re-mapping
    'asset_serial': serialCode,
    'asset_isoutdoor': false,
  };

  // Factory constructor to create an Asset object from a backend JSON response.
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
      purchaseDate: DateTime.now(),
      campusStartDate: DateTime.now(),
      warrantyReceipts: [],
      reportIds: [],
    );
  }

  // Helper to map backend IDs back to human-readable categories
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
    return 1; // Default na Meubels as veiligheid
  }
}
