class Quote {
  final int id;
  final int? contractorId;
  final String? contractorName;
  final DateTime date;
  final String status;
  final String? selectionReason;

  Quote({
    this.id = 0,
    this.contractorId,
    this.contractorName,
    required this.date,
    required this.status,
    this.selectionReason,
  });

  factory Quote.fromJson(Map<String, dynamic> json) {
    return Quote(
      id: json['quote_id'] ?? 0,
      contractorId: json['contractor_id'],
      contractorName: json['contractor_name'],
      date: json['quote_date'] != null ? DateTime.parse(json['quote_date']) : DateTime.now(),
      status: json['quote_status'] ?? 'pending',
      selectionReason: json['quote_selection_reason'],
    );
  }

  Map<String, dynamic> toJson() => {
    'quote_date': date.toIso8601String().split('T')[0],
    'quote_status': status,
    if (contractorId != null) 'contractor_id': contractorId,
    if (contractorName != null && contractorName!.trim().isNotEmpty)
      'contractor_name': contractorName!.trim(),
    if (selectionReason != null) 'quote_selection_reason': selectionReason,
  };
}
