
class Report {
  final String id;
  final String assetId;
  final String? assetSerialCode;
  final String location; // Word gemap na room_id op backend
  final String title;
  final String description;
  final String category; // Word gemap na fault_type op backend
  final String priority;
  final String phase; // Word gemap na fault_status op backend
  final String user;
  final DateTime timestamp;
  final String? gpsCoords; // Word gemap na mappoint_id op backend
  // Fotos leef nou in ImageAssetLink (parent_type 'ticket') aan die backend-kant,
  // NIE meer as 'n image_id op die Faultcard nie — sien ImageService.
  final int? locationId; // Kampus (location_id op backend)
  final int? buildingId; // Gebou (building_id op backend)

  Report({
    required this.id,
    required this.assetId,
    this.assetSerialCode,
    required this.location,
    required this.title,
    required this.description,
    required this.category,
    required this.priority,
    required this.phase,
    required this.user,
    required this.timestamp,
    this.gpsCoords,
    this.locationId,
    this.buildingId,
  });

  // Map vanaf Flutter model na Backend (Faultcard)
  Map<String, dynamic> toJson() {
    return {
      'fault_description': '$title: $description',
      'fault_type': _backendFaultType(category),
      'fault_priority': _backendPriority(priority),
      'fault_status': _backendFaultStatus(phase),
      'fault_reportdatetime': timestamp.toIso8601String(),
      'asset_id': (assetId == "0" || assetId == "Geen Bate") ? null : int.tryParse(assetId),
      'room_id': int.tryParse(location),
      'mappoint_id': int.tryParse(gpsCoords ?? ''),
      'location_id': locationId,
      'building_id': buildingId,
    };
  }

  static String? _backendFaultType(String cat) {
    switch (cat.toLowerCase()) {
      case 'onderhoud':
      case 'instandhouding':
      case 'maintenance':
        return 'Onderhoud';
      case 'herstel':
      case 'herstelwerk':
      case 'repair':
        return 'Herstel';
      case 'inspeksie':
      case 'inspection':
        return 'Inspeksie';
      case 'installasie':
      case 'installation':
        return 'Installasie';
      default:
        return 'Onderhoud';
    }
  }

  static String _backendPriority(String prio) {
    switch (prio.toLowerCase()) {
      case 'laag':
      case 'low':
        return 'Laag';
      case 'medium':
        return 'Medium';
      case 'hoog':
      case 'high':
        return 'Hoog';
      default:
        return 'Medium';
    }
  }

  static String _backendFaultStatus(String ph) {
    switch (ph.toLowerCase()) {
      case 'ontvang':
      case 'wag':
      case 'wait':
        return 'Wag';
      case 'oop':
      case 'open':
        return 'Oop';
      case 'bevestig':
      case 'confirmed':
      case 'confrimed':
        return 'Bevestig';
      case 'besig':
      case 'in_progress':
      case 'in progress':
        return 'Besig';
      case 'voltooi':
      case 'opgelos':
      case 'resolved':
        return 'Opgelos';
      case 'geweier':
      case 'verwerp':
      case 'closed':
      case 'gesluit':
        return 'Gesluit';
      default:
        return 'Wag';
    }
  }

  static String _frontendFaultStatus(String s) {
    switch (s) {
      case 'WAIT':
      case 'Wag':
        return 'Ontvang';
      case 'OPEN':
      case 'Oop':
        return 'Ontvang';
      case 'CONFRIMED':
      case 'Bevestig':
        return 'Ontvang';
      case 'IN_PROGRESS':
      case 'Besig':
        return 'Besig';
      case 'RESOLVED':
      case 'Opgelos':
        return 'Voltooi';
      case 'CLOSED':
      case 'Gesluit':
        return 'Geweier';
      default:
        return 'Ontvang';
    }
  }

  static String _frontendPriority(String p) {
    switch (p) {
      case 'LOW':
      case 'Laag':
        return 'Laag';
      case 'MEDIUM':
      case 'Medium':
        return 'Medium';
      case 'HIGH':
      case 'Hoog':
        return 'Hoog';
      default:
        return 'Medium';
    }
  }

  static String _frontendFaultType(String? t) {
    switch (t) {
      case 'MAINTENANCE':
      case 'Instandhouding':
      case 'Onderhoud':
        return 'Onderhoud';
      case 'REPAIR':
      case 'Herstelwerk':
      case 'Herstel':
        return 'Herstel';
      case 'INSPECTION':
      case 'Inspeksie':
        return 'Inspeksie';
      case 'INSTALLATION':
      case 'Installasie':
        return 'Installasie';
      default:
        return 'Onderhoud';
    }
  }

  factory Report.fromJson(Map<String, dynamic> json) {
    // Map backend status terug na frontend fase
    String frontendPhase = _frontendFaultStatus(json['fault_status'] ?? "Wag");

    // Map backend prioriteit
    String frontendPriority = _frontendPriority(json['fault_priority'] ?? "Medium");

    // Map backend tipe terug na frontend kategorie
    String frontendCategory = _frontendFaultType(json['fault_type']);

    // Beskrywing split (backend stoor as "Title: Description")
    String fullDesc = json['fault_description'] ?? "";
    String title = fullDesc;
    String description = "";
    if (fullDesc.contains(": ")) {
      var parts = fullDesc.split(": ");
      title = parts[0];
      description = parts.sublist(1).join(": ");
    }

    return Report(
      id: json['fault_id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      assetId: json['asset_id']?.toString() ?? 'Geen Bate',
      location: json['room_id']?.toString() ?? 'Onbekend',
      title: title,
      description: description,
      category: frontendCategory,
      priority: frontendPriority,
      phase: frontendPhase,
      user: json['user_id']?.toString() ?? "Stelsel",
      timestamp: json['fault_reportdatetime'] != null 
          ? DateTime.parse(json['fault_reportdatetime']) 
          : DateTime.now(),
      gpsCoords: json['mappoint_id']?.toString(),
      locationId: json['location_id'],
      buildingId: json['building_id'],
    );
  }

  Report copyWith({
    String? id,
    String? assetId,
    String? assetSerialCode,
    String? location,
    String? title,
    String? description,
    String? category,
    String? priority,
    String? phase,
    String? user,
    DateTime? timestamp,
    String? gpsCoords,
    int? locationId,
    int? buildingId,
  }) {
    return Report(
      id: id ?? this.id,
      assetId: assetId ?? this.assetId,
      assetSerialCode: assetSerialCode ?? this.assetSerialCode,
      location: location ?? this.location,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      priority: priority ?? this.priority,
      phase: phase ?? this.phase,
      user: user ?? this.user,
      timestamp: timestamp ?? this.timestamp,
      gpsCoords: gpsCoords ?? this.gpsCoords,
      locationId: locationId ?? this.locationId,
      buildingId: buildingId ?? this.buildingId,
    );
  }
}
