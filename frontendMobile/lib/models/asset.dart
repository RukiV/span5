class Asset {
  final String id;
  final String serialCode;
  final String name;
  final String category;
  final String location;
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

  Map<String, dynamic> toJson() => {
    'asset_name': name,
    'asset_status': status.toLowerCase(),
    'room_id': int.tryParse(location) ?? 1,
    'assettype_id': _getCategoryId(category),
    'asset_serial': serialCode,
  };

  factory Asset.fromJson(Map<String, dynamic> json) => Asset(
    campus: 'Hoofkampus (Centurion)', // Backend het nie 'n direkte campus veld op asset nie
    id: json['asset_id']?.toString() ?? '',
    serialCode: json['asset_serial'] ?? '',
    name: json['asset_name'] ?? 'Onbekende Bate',
    category: _getCategoryName(json['assettype_id']),
    location: json['room_id']?.toString() ?? '1',
    status: json['asset_status'] ?? 'active',
    purchaseDate: DateTime.now(), // Backend stoor nie tans aankoopdatum nie
    campusStartDate: DateTime.now(),
    warrantyReceipts: [],
    reportIds: [],
  );

  static int _getCategoryId(String cat) {
    switch (cat) {
      case "Meubels": return 1;
      case "IT Toerusting": return 2;
      default: return 3;
    }
  }

  static String _getCategoryName(int? id) {
    switch (id) {
      case 1: return "Meubels";
      case 2: return "IT Toerusting";
      default: return "Ander";
    }
  }
}
