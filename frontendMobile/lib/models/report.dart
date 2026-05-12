import 'user_session.dart';

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

  // Map vanaf Flutter model na Backend (Faultcard)
  Map<String, dynamic> toJson() {
    // Map prioriteit
    String backendPriority = "medium";
    if (priority == "Laag") backendPriority = "low";
    if (priority == "Hoog") backendPriority = "high";

    // Map status
    String backendStatus = "wag";
    if (phase == "Besig") backendStatus = "besig";
    if (phase == "Voltooi") backendStatus = "opgelos";
    if (phase == "Geweier") backendStatus = "verwerp";

    return {
      'fault_description': '$title: $description',
      'fault_priority': backendPriority,
      'fault_status': backendStatus,
      'fault_reportdatetime': timestamp.toIso8601String(),
      // Backend verwag IDs as integers, ons stuur dit as null as dit nie beskikbaar is nie
      'asset_id': int.tryParse(assetId),
      'user_id': UserSession.userId,
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
      assetId: json['asset_id']?.toString() ?? 'ONSIGBAAR',
      location: json['room_id']?.toString() ?? 'Onbekend',
      title: title,
      description: description,
      category: json['fault_type'] ?? 'Algemeen',
      priority: frontendPriority,
      phase: frontendPhase,
      user: json['user_id']?.toString() ?? "Stelsel",
      timestamp: json['fault_reportdatetime'] != null 
          ? DateTime.parse(json['fault_reportdatetime']) 
          : DateTime.now(),
      adminNotes: json['admin_notes'],
      imageUrl: json['image_url'], // As die backend dit ondersteun
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
