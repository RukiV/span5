
/// DraftCandidate: 'n Moontlike bate/lokaal wat die AI vir 'n konsep
/// geïdentifiseer het (entiteitsresolusie gebeur backend-kant).
class DraftCandidate {
  final int id;
  final String name;
  final String detail;

  DraftCandidate({required this.id, required this.name, this.detail = ''});

  factory DraftCandidate.fromJson(Map<String, dynamic> json) {
    return DraftCandidate(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] ?? '',
      detail: json['detail'] ?? '',
    );
  }
}

/// FaultDraft: 'n AI-foutkonsep in die goedkeurings-ry. Die FK/Admin kan die
/// konsep hersien, wysig en goedkeur of verwerp — eers dan word dit 'n kaartjie.
class FaultDraft {
  final int draftId;
  final String description;
  final String cleanedDescription;
  final String title;
  final String workInstruction;
  final String suggestedType;
  final String suggestedPriority;
  final String failureCategory;
  final String language;
  final String aiStatus; // "ok" | "degraded"
  final String source; // "manual" | "auto"
  final String status; // "draft" | "approved" | "rejected"
  final String reviewNote;
  final int? resolvedAssetId;
  final int? resolvedRoomId;
  final int? duplicateOf;
  final int userId;
  final int? reviewerId;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? reviewedAt;

  FaultDraft({
    required this.draftId,
    required this.description,
    required this.cleanedDescription,
    required this.title,
    required this.workInstruction,
    required this.suggestedType,
    required this.suggestedPriority,
    required this.failureCategory,
    required this.language,
    required this.aiStatus,
    required this.source,
    required this.status,
    required this.reviewNote,
    this.resolvedAssetId,
    this.resolvedRoomId,
    this.duplicateOf,
    required this.userId,
    this.reviewerId,
    this.createdAt,
    this.updatedAt,
    this.reviewedAt,
  });

  // Afrikaanse vertoon-etiket vir die status (draft | approved | rejected).
  String get statusLabel {
    switch (status) {
      case 'draft':
        return 'Wag';
      case 'approved':
        return 'Goedgekeur';
      case 'rejected':
        return 'Verwerp';
      default:
        return status;
    }
  }

  // Afrikaanse vertoon-etiket vir die voorgestelde werksoort.
  String get typeLabel {
    switch (suggestedType) {
      case 'REPAIR':
        return 'Herstel';
      case 'MAINTENANCE':
        return 'Onderhoud';
      case 'INSPECTION':
        return 'Inspeksie';
      case 'INSTALLATION':
        return 'Installasie';
      default:
        return suggestedType;
    }
  }

  // Afrikaanse vertoon-etiket vir die voorgestelde prioriteit.
  String get priorityLabel {
    switch (suggestedPriority) {
      case 'LOW':
        return 'Laag';
      case 'MEDIUM':
        return 'Medium';
      case 'HIGH':
        return 'Hoog';
      default:
        return suggestedPriority;
    }
  }

  factory FaultDraft.fromJson(Map<String, dynamic> json) {
    return FaultDraft(
      draftId: (json['draft_id'] as num?)?.toInt() ?? 0,
      description: json['description'] ?? '',
      cleanedDescription: json['cleaned_description'] ?? '',
      title: json['title'] ?? '',
      workInstruction: json['work_instruction'] ?? '',
      suggestedType: json['suggested_type'] ?? 'REPAIR',
      suggestedPriority: json['suggested_priority'] ?? 'MEDIUM',
      failureCategory: json['failure_category'] ?? '',
      language: json['language'] ?? '',
      aiStatus: json['ai_status'] ?? 'ok',
      source: json['source'] ?? 'manual',
      status: json['status'] ?? 'draft',
      reviewNote: json['review_note'] ?? '',
      resolvedAssetId: (json['resolved_asset_id'] as num?)?.toInt(),
      resolvedRoomId: (json['resolved_room_id'] as num?)?.toInt(),
      duplicateOf: (json['duplicate_of'] as num?)?.toInt(),
      userId: (json['user_id'] as num?)?.toInt() ?? 0,
      reviewerId: (json['reviewer_id'] as num?)?.toInt(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? ''),
      reviewedAt: DateTime.tryParse(json['reviewed_at']?.toString() ?? ''),
    );
  }

  FaultDraft copyWith({
    int? draftId,
    String? description,
    String? cleanedDescription,
    String? title,
    String? workInstruction,
    String? suggestedType,
    String? suggestedPriority,
    String? failureCategory,
    String? language,
    String? aiStatus,
    String? source,
    String? status,
    String? reviewNote,
    int? resolvedAssetId,
    int? resolvedRoomId,
    int? duplicateOf,
    int? userId,
    int? reviewerId,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? reviewedAt,
  }) {
    return FaultDraft(
      draftId: draftId ?? this.draftId,
      description: description ?? this.description,
      cleanedDescription: cleanedDescription ?? this.cleanedDescription,
      title: title ?? this.title,
      workInstruction: workInstruction ?? this.workInstruction,
      suggestedType: suggestedType ?? this.suggestedType,
      suggestedPriority: suggestedPriority ?? this.suggestedPriority,
      failureCategory: failureCategory ?? this.failureCategory,
      language: language ?? this.language,
      aiStatus: aiStatus ?? this.aiStatus,
      source: source ?? this.source,
      status: status ?? this.status,
      reviewNote: reviewNote ?? this.reviewNote,
      resolvedAssetId: resolvedAssetId ?? this.resolvedAssetId,
      resolvedRoomId: resolvedRoomId ?? this.resolvedRoomId,
      duplicateOf: duplicateOf ?? this.duplicateOf,
      userId: userId ?? this.userId,
      reviewerId: reviewerId ?? this.reviewerId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      reviewedAt: reviewedAt ?? this.reviewedAt,
    );
  }
}

/// FaultDraftDetail: 'n Konsep se detail — die lees-velde plus die kandidaat
/// bates/lokale wat die FK/Admin moet ontknoop tydens goedkeuring.
class FaultDraftDetail extends FaultDraft {
  final List<DraftCandidate> assetCandidates;
  final List<DraftCandidate> roomCandidates;

  // Privaat: bou die detail uit 'n reeds-ontlede basis-konsep plus kandidate.
  FaultDraftDetail._({
    required FaultDraft base,
    required this.assetCandidates,
    required this.roomCandidates,
  }) : super(
          draftId: base.draftId,
          description: base.description,
          cleanedDescription: base.cleanedDescription,
          title: base.title,
          workInstruction: base.workInstruction,
          suggestedType: base.suggestedType,
          suggestedPriority: base.suggestedPriority,
          failureCategory: base.failureCategory,
          language: base.language,
          aiStatus: base.aiStatus,
          source: base.source,
          status: base.status,
          reviewNote: base.reviewNote,
          resolvedAssetId: base.resolvedAssetId,
          resolvedRoomId: base.resolvedRoomId,
          duplicateOf: base.duplicateOf,
          userId: base.userId,
          reviewerId: base.reviewerId,
          createdAt: base.createdAt,
          updatedAt: base.updatedAt,
          reviewedAt: base.reviewedAt,
        );

  factory FaultDraftDetail.fromJson(Map<String, dynamic> json) {
    return FaultDraftDetail._(
      base: FaultDraft.fromJson(json),
      assetCandidates: (json['asset_candidates'] as List? ?? [])
          .map((e) => DraftCandidate.fromJson(e as Map<String, dynamic>))
          .toList(),
      roomCandidates: (json['room_candidates'] as List? ?? [])
          .map((e) => DraftCandidate.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
