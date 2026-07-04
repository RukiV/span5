// Asset: Represents a piece of equipment or furniture tracked by the system.
class Asset {
  final String id;
  final String serialCode;
  final String name;
  final String category;
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
    'assettype_id': _getCategoryId(category),
    'asset_serial': serialCode,
    'asset_isoutdoor': false, // Currently default to false, could be a toggle in UI later
  };

  // Factory constructor to create an Asset object from a backend JSON response.
  factory Asset.fromJson(Map<String, dynamic> json) => Asset(
    campus: 'Loading...', // Ideally populated via Room -> Location relationship
    id: json['asset_id']?.toString() ?? '',
    serialCode: json['asset_serial'] ?? '',
    name: json['asset_name'] ?? 'Unknown Asset',
    category: _getCategoryName(json['assettype_id']),
    location: json['room_id']?.toString() ?? '1',
    status: json['asset_status'] ?? 'active',
    purchaseDate: DateTime.now(),
    campusStartDate: DateTime.now(),
    warrantyReceipts: [],
    reportIds: [],
  );

  // Helper to map category names to backend-expected IDs
  static int _getCategoryId(String cat) {
    if (cat.contains("Meubel")) return 1;
    if (cat.contains("IT") || cat.contains("Tegno")) return 2;
    return 3; // Other
  }

  // Helper to map backend IDs back to human-readable categories
  static String _getCategoryName(int? id) {
    switch (id) {
      case 1: return "Furniture";
      case 2: return "IT Equipment";
      default: return "Other";
    }
  }
}
