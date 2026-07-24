class Quote {
  final int id;
  final int jobId;
  final int contractorId;
  final double price;
  final String description;
  final DateTime date;
  final String status;
  final String? selectionReason;

  Quote({
    required this.id,
    required this.jobId,
    required this.contractorId,
    required this.price,
    required this.description,
    required this.date,
    required this.status,
    this.selectionReason,
  });

  factory Quote.fromJson(Map<String, dynamic> json) {
    return Quote(
      id: json['quote_id'] ?? 0,
      jobId: json['job_id'] ?? 0,
      contractorId: json['contractor_id'] ?? 0,
      price: (json['quote_price'] is num) ? (json['quote_price'] as num).toDouble() : 0.0,
      description: json['quote_desc'] ?? '',
      date: json['quote_date'] != null ? DateTime.parse(json['quote_date']) : DateTime.now(),
      status: json['quote_status'] ?? 'pending',
      selectionReason: json['quote_selection_reason'],
    );
  }

  Map<String, dynamic> toJson() => {
    'job_id': jobId,
    'contractor_id': contractorId,
    'quote_price': price,
    'quote_desc': description,
    'quote_date': date.toIso8601String().split('T')[0],
    'quote_status': status,
    if (selectionReason != null) 'quote_selection_reason': selectionReason,
  };

  Quote copyWith({
    int? id,
    int? jobId,
    int? contractorId,
    double? price,
    String? description,
    DateTime? date,
    String? status,
    String? selectionReason,
  }) {
    return Quote(
      id: id ?? this.id,
      jobId: jobId ?? this.jobId,
      contractorId: contractorId ?? this.contractorId,
      price: price ?? this.price,
      description: description ?? this.description,
      date: date ?? this.date,
      status: status ?? this.status,
      selectionReason: selectionReason ?? this.selectionReason,
    );
  }
}
