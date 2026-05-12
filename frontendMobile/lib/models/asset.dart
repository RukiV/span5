class Asset {
  final String id;
  final String name;
  final String category;
  final String location;
  final String status;
  final DateTime purchaseDate;
  final DateTime campusStartDate;
  final String campus; // Nuwe veld vir campus-filtering
  final List<String> warrantyReceipts;
  final List<String> reportIds; // IDs van alle verslae gekoppel aan hierdie bate

  Asset({
    required this.campus,
    required this.id,
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
    'campus': campus,
    'id': id,
    'name': name,
    'category': category,
    'location': location,
    'status': status,
    'purchaseDate': purchaseDate.toIso8601String(),
    'campusStartDate': campusStartDate.toIso8601String(),
    'warrantyReceipts': warrantyReceipts,
    'reportIds': reportIds,
  };

  factory Asset.fromJson(Map<String, dynamic> json) => Asset(
    campus: json['campus'] ?? 'Hoofkampus (Centurion)',
    id: json['id'],
    name: json['name'],
    category: json['category'],
    location: json['location'],
    status: json['status'],
    purchaseDate: DateTime.parse(json['purchaseDate']),
    campusStartDate: DateTime.parse(json['campusStartDate']),
    warrantyReceipts: List<String>.from(json['warrantyReceipts'] ?? []),
    reportIds: List<String>.from(json['reportIds'] ?? []),
  );
}
