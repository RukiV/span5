import 'user_session.dart';

class Report {
  final String id;
  final String assetId;
  final String location; // Word gemap na room_id op backend
  final String title;
  final String description;
  final String category; // Word gemap na fault_type op backend
  final String priority;
  final String phase; // Word gemap na fault_status op backend
  final String user;
  final DateTime timestamp;
  final String? gpsCoords; // Word gemap na mappoint_id op backend

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
    this.gpsCoords,
  });

  // Map vanaf Flutter model na Backend (Faultcard)
  Map<String, dynamic> toJson() {
    // Map prioriteit (Backend verwag: low, medium, high)
    String backendPriority = "medium";
    if (priority == "Laag") backendPriority = "low";
    if (priority == "Hoog") backendPriority = "high";

    // Map status (Backend verwag: wag, open, bevestig, besig, opgelos, verwerp)
    String backendStatus = "wag";
    if (phase == "Besig") backendStatus = "besig";
    if (phase == "Voltooi") backendStatus = "opgelos";
    if (phase == "Geweier") backendStatus = "verwerp";

    // Map tipe (Backend verwag: maintenance, repair, upgrade)
    String? backendType;
    if (category == "Instandhouding") backendType = "maintenance";
    if (category == "Herstel") backendType = "repair";
    if (category == "Opgradering") backendType = "upgrade";

    return {
      'fault_description': '$title: $description',
      'fault_type': backendType,
      'fault_priority': backendPriority,
      'fault_status': backendStatus,
      'fault_reportdatetime': timestamp.toIso8601String(),
      'asset_id': assetId == "0" ? null : int.tryParse(assetId),
      'user_id': UserSession.userId,
      'room_id': int.tryParse(location),
      'mappoint_id': int.tryParse(gpsCoords ?? ''),
    };
  }

  factory Report.fromJson(Map<String, dynamic> json) {
    // Map backend status terug na frontend fase
    String frontendPhase = "Ontvang";
    String bs = json['fault_status'] ?? "wag";
    if (bs == "besig") frontendPhase = "Besig";
    if (bs == "opgelos") frontendPhase = "Voltooi";
    if (bs == "verwerp") frontendPhase = "Geweier";

    // Map backend prioriteit
    String frontendPriority = "Medium";
    String bp = json['fault_priority'] ?? "medium";
    if (bp == "low") frontendPriority = "Laag";
    if (bp == "high") frontendPriority = "Hoog";

    // Map backend tipe terug na frontend kategorie
    String frontendCategory = "Algemeen";
    String? bt = json['fault_type'];
    if (bt == "maintenance") frontendCategory = "Instandhouding";
    if (bt == "repair") frontendCategory = "Herstel";
    if (bt == "upgrade") frontendCategory = "Opgradering";

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
    );
  }

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
      gpsCoords: gpsCoords ?? this.gpsCoords,
    );
  }
}
