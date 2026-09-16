
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
  // Fotos leef nou in ImageAssetLink (parent_type 'ticket') aan die backend-kant,
  // NIE meer as 'n image_id op die Faultcard nie — sien ImageService.
  final int? locationId; // Kampus (location_id op backend)
  final int? buildingId; // Gebou (building_id op backend)
  final int? mappointId; // Kaartligging (mappoint_id op backend)
  final double? latitude; // Kaartligging (transiënt, gestoor via mappoint)
  final double? longitude; // Kaartligging (transiënt, gestoor via mappoint)
  final bool isOutdoor; // Buite Lokaal (is_outdoor op backend)
  final String? rawStatus; // Rou backend-status (fault_status), voorkom status-verlies by opdatering

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
    this.locationId,
    this.buildingId,
    this.mappointId,
    this.latitude,
    this.longitude,
    this.isOutdoor = false,
    this.rawStatus,
  });

  // Map vanaf Flutter model na Backend (Faultcard)
  Map<String, dynamic> toJson() {
    return {
      'fault_description': '$title: $description',
      'fault_type': _backendFaultType(category),
      'fault_priority': _backendPriority(priority),
      'fault_status': rawStatus ?? _backendFaultStatus(phase),
      'fault_reportdatetime': timestamp.toIso8601String(),
      'asset_id': (assetId == "0" || assetId == "Geen Bate") ? null : int.tryParse(assetId),
      'room_id': int.tryParse(location),
      'location_id': locationId,
      'building_id': buildingId,
      'latitude': latitude,
      'longitude': longitude,
      'is_outdoor': isOutdoor,
    };
  }

  /// PATCH-payload: stuur slegs die velde wat ons wel het; null/leë ID's word
  /// weggelaat sodat die backend die bestaande waardes behou (geen stomp
  /// "null"-oorskrywings by opdatering nie).
  Map<String, dynamic> toUpdateJson() {
    final m = <String, dynamic>{};
    m['fault_type'] = _backendFaultType(category);
    m['fault_priority'] = _backendPriority(priority);
    m['fault_status'] = rawStatus ?? _backendFaultStatus(phase);
    m['fault_description'] = '$title: $description';
    if (assetId != 'Geen Bate') {
      final a = int.tryParse(assetId);
      if (a != null) m['asset_id'] = a;
    }
    final rid = int.tryParse(location);
    if (rid != null) m['room_id'] = rid;
    if (locationId != null) m['location_id'] = locationId;
    if (buildingId != null) m['building_id'] = buildingId;
    if (latitude != null) m['latitude'] = latitude;
    if (longitude != null) m['longitude'] = longitude;
    if (mappointId != null) m['mappoint_id'] = mappointId;
    m['is_outdoor'] = isOutdoor;
    return m;
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
    if (json['fault_id'] == null) {
      throw FormatException('Report sonder fault_id');
    }
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
      id: json['fault_id'].toString(),
      assetId: json['asset_id']?.toString() ?? 'Geen Bate',
      location: json['room_id']?.toString() ?? 'Onbekend',
      title: title,
      description: description,
      category: frontendCategory,
      priority: frontendPriority,
      phase: frontendPhase,
      rawStatus: json['fault_status'] as String?,
      user: json['user_id']?.toString() ?? "Stelsel",
      timestamp: json['fault_reportdatetime'] != null 
          ? DateTime.parse(json['fault_reportdatetime']) 
          : DateTime.now(),
      locationId: json['location_id'],
      buildingId: json['building_id'],
      mappointId: json['mappoint_id'],
      isOutdoor: json['is_outdoor'] ?? false,
    );
  }

  static const Object _unset = Object();

  Report copyWith({
    String? id,
    String? assetId,
    Object? assetSerialCode = _unset,
    String? location,
    String? title,
    String? description,
    String? category,
    String? priority,
    String? phase,
    String? user,
    DateTime? timestamp,
    Object? locationId = _unset,
    Object? buildingId = _unset,
    Object? mappointId = _unset,
    Object? latitude = _unset,
    Object? longitude = _unset,
    bool? isOutdoor,
    String? rawStatus,
  }) {
    return Report(
      id: id ?? this.id,
      assetId: assetId ?? this.assetId,
      assetSerialCode: identical(assetSerialCode, _unset) ? this.assetSerialCode : assetSerialCode as String?,
      location: location ?? this.location,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      priority: priority ?? this.priority,
      phase: phase ?? this.phase,
      user: user ?? this.user,
      timestamp: timestamp ?? this.timestamp,
      locationId: identical(locationId, _unset) ? this.locationId : locationId as int?,
      buildingId: identical(buildingId, _unset) ? this.buildingId : buildingId as int?,
      mappointId: identical(mappointId, _unset) ? this.mappointId : mappointId as int?,
      latitude: identical(latitude, _unset) ? this.latitude : latitude as double?,
      longitude: identical(longitude, _unset) ? this.longitude : longitude as double?,
      isOutdoor: isOutdoor ?? this.isOutdoor,
      rawStatus: rawStatus ?? this.rawStatus,
    );
  }
}
