class Report {
  final String id;
  final String assetId;
  final String location;
  final String title;
  final String description;
  final String category;
  final String priority;
  final String phase;
  final String user;
  final DateTime timestamp;
  final String? adminNotes;
  final String? imageUrl;
  final String? gpsCoords;

  Report({
    required this.id,
    required this.assetId,
    required this.location,
    required this.title,
    required this.description,
    required this.category,
    required this.priority,
    required this.phase,
    required this.user,
    required this.timestamp,
    this.adminNotes,
    this.imageUrl,
    this.gpsCoords,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'assetId': assetId,
    'location': location,
    'title': title,
    'description': description,
    'category': category,
    'priority': priority,
    'phase': phase,
    'user': user,
    'timestamp': timestamp.toIso8601String(),
    'adminNotes': adminNotes,
    'imageUrl': imageUrl,
    'gpsCoords': gpsCoords,
  };

  factory Report.fromJson(Map<String, dynamic> json) => Report(
    id: json['id'],
    assetId: json['assetId'] ?? 'ONSIGBAAR',
    location: json['location'],
    title: json['title'],
    description: json['description'] ?? '',
    category: json['category'],
    priority: json['priority'],
    phase: json['phase'],
    user: json['user'],
    timestamp: DateTime.parse(json['timestamp']),
    adminNotes: json['adminNotes'],
    imageUrl: json['imageUrl'],
    gpsCoords: json['gpsCoords'],
  );

  Report copyWith({
    String? id,
    String? assetId,
    String? location,
    String? title,
    String? description,
    String? category,
    String? priority,
    String? phase,
    String? user,
    DateTime? timestamp,
    String? adminNotes,
    String? imageUrl,
    String? gpsCoords,
  }) {
    return Report(
      id: id ?? this.id,
      assetId: assetId ?? this.assetId,
      location: location ?? this.location,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      priority: priority ?? this.priority,
      phase: phase ?? this.phase,
      user: user ?? this.user,
      timestamp: timestamp ?? this.timestamp,
      adminNotes: adminNotes ?? this.adminNotes,
      imageUrl: imageUrl ?? this.imageUrl,
      gpsCoords: gpsCoords ?? this.gpsCoords,
    );
  }
}
