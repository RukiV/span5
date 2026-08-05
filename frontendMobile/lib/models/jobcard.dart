class Jobcard {
  static const Map<String, String> _statusLabels = {
    'Wag': 'Wag',
    'Oop': 'Oop',
    'Besig': 'Besig',
    'Voltooid': 'Voltooi',
    'Gekanselleer': 'Gekanselleer',
    'WAIT': 'Wag',
    'OPEN': 'Oop',
    'IN_PROGRESS': 'Besig',
    'COMPLETED': 'Voltooi',
    'CANCELLED': 'Gekanselleer',
  };

  static const Map<String, String> _statusToBackend = {
    'Wag': 'Wag',
    'Oop': 'Oop',
    'Besig': 'Besig',
    'Voltooi': 'Voltooid',
    'Voltooid': 'Voltooid',
    'Gekanselleer': 'Gekanselleer',
  };

  static String toBackendStatus(String displayStatus) {
    return _statusToBackend[displayStatus] ?? displayStatus;
  }

  final int id;
  final String description;
  final String fullDescription;
  final String status;
  final String? type;
  final int? faultId;
  final int? contractorId;
  final int? creatorId;
  final int? assetId;
  final int? roomId;
  final int? buildingId;
  final int? locationId;
  final DateTime? createdDatetime;
  final DateTime? scheduledDatetime;
  final DateTime? scheduledEndDatetime;
  final DateTime? finishedDatetime;
  final String? priority;
  final String? nature;
  final String? scheduleType;
  final int? assignedTo;
  final String? ccUsers;
  final int? quoteId;
  final List<int> quoteIds;

  Jobcard({
    required this.id,
    required this.description,
    required this.status,
    this.fullDescription = '',
    this.type,
    this.faultId,
    this.contractorId,
    this.creatorId,
    this.assetId,
    this.roomId,
    this.buildingId,
    this.locationId,
    this.createdDatetime,
    this.scheduledDatetime,
    this.scheduledEndDatetime,
    this.finishedDatetime,
    this.priority,
    this.nature,
    this.scheduleType,
    this.assignedTo,
    this.ccUsers,
    this.quoteId,
    this.quoteIds = const [],
  });

  factory Jobcard.fromJson(Map<String, dynamic> json) {
    final rawDesc = json['job_desc'] ?? '';
    String title = rawDesc;
    String details = '';
    if (rawDesc is String && rawDesc.contains(': ')) {
      final parts = rawDesc.split(': ');
      title = parts[0];
      details = parts.sublist(1).join(': ');
    }
    final rawStatus = json['job_status'] as String? ?? 'OPEN';

    return Jobcard(
      id: json['jobcard_id'] ?? 0,
      description: title,
      fullDescription: details.isNotEmpty ? details : title,
      status: _statusLabels[rawStatus] ?? rawStatus,
      type: json['job_type'],
      faultId: json['fault_id'],
      contractorId: json['contractor_id'],
      creatorId: json['user_id'],
      assetId: json['asset_id'],
      roomId: json['room_id'],
      buildingId: json['building_id'],
      locationId: json['location_id'],
      createdDatetime: json['job_createddatetime'] != null
          ? DateTime.tryParse(json['job_createddatetime'])
          : null,
      scheduledDatetime: json['job_scheduled_datetime'] != null
          ? DateTime.tryParse(json['job_scheduled_datetime'])
          : null,
      scheduledEndDatetime: json['job_scheduled_end_datetime'] != null
          ? DateTime.tryParse(json['job_scheduled_end_datetime'])
          : null,
      finishedDatetime: json['job_finisheddatetime'] != null
          ? DateTime.tryParse(json['job_finisheddatetime'])
          : null,
      priority: json['job_priority'],
      nature: json['nature'],
      scheduleType: json['job_schedule_type'],
      assignedTo: json['assigned_to'],
      ccUsers: json['cc_users'],
      quoteId: json['quote_id'],
      quoteIds: _parseQuoteIds(json['quote_ids']),
    );
  }

  static List<int> _parseQuoteIds(dynamic raw) {
    if (raw == null) return [];
    if (raw is List) {
      return raw.map((e) => int.tryParse(e.toString()) ?? 0).where((e) => e != 0).toList();
    }
    return raw
        .toString()
        .split(',')
        .map((e) => int.tryParse(e.trim()) ?? 0)
        .where((e) => e != 0)
        .toList();
  }

  Map<String, dynamic> toJson() {
    return {
      'job_desc': description,
      'job_status': status,
      'job_type': type,
      'fault_id': faultId,
      'contractor_id': contractorId,
      'asset_id': assetId,
      'room_id': roomId,
      'building_id': buildingId,
      'location_id': locationId,
      if (scheduledDatetime != null)
        'job_scheduled_datetime': scheduledDatetime!.toIso8601String(),
      if (finishedDatetime != null)
        'job_finisheddatetime': finishedDatetime!.toIso8601String(),
    };
  }

  String get statusLabel => status;

  Jobcard copyWith({
    int? id,
    String? description,
    String? status,
    String? type,
    int? faultId,
    int? contractorId,
    int? creatorId,
    int? assetId,
    int? roomId,
    int? buildingId,
    int? locationId,
    DateTime? createdDatetime,
    DateTime? scheduledDatetime,
    DateTime? scheduledEndDatetime,
    DateTime? finishedDatetime,
    String? priority,
    String? nature,
    String? scheduleType,
    int? assignedTo,
    String? ccUsers,
    int? quoteId,
    List<int>? quoteIds,
  }) {
    return Jobcard(
      id: id ?? this.id,
      description: description ?? this.description,
      status: status ?? this.status,
      fullDescription: fullDescription,
      type: type ?? this.type,
      faultId: faultId ?? this.faultId,
      contractorId: contractorId ?? this.contractorId,
      creatorId: creatorId ?? this.creatorId,
      assetId: assetId ?? this.assetId,
      roomId: roomId ?? this.roomId,
      buildingId: buildingId ?? this.buildingId,
      locationId: locationId ?? this.locationId,
      createdDatetime: createdDatetime ?? this.createdDatetime,
      scheduledDatetime: scheduledDatetime ?? this.scheduledDatetime,
      scheduledEndDatetime: scheduledEndDatetime ?? this.scheduledEndDatetime,
      finishedDatetime: finishedDatetime ?? this.finishedDatetime,
      priority: priority ?? this.priority,
      nature: nature ?? this.nature,
      scheduleType: scheduleType ?? this.scheduleType,
      assignedTo: assignedTo ?? this.assignedTo,
      ccUsers: ccUsers ?? this.ccUsers,
      quoteId: quoteId ?? this.quoteId,
      quoteIds: quoteIds ?? this.quoteIds,
    );
  }
}
