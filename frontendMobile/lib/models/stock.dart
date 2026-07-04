class Stock {
  final int? id;
  final String brand;
  final int amount;
  final String type;
  final String? description;
  final int? roomId;

  Stock({
    this.id,
    required this.brand,
    required this.amount,
    required this.type,
    this.description,
    this.roomId,
  });

  factory Stock.fromJson(Map<String, dynamic> json) => Stock(
    id: json['stock_id'],
    brand: json['stock_brand'],
    amount: json['stock_amount'],
    type: json['stock_type'],
    description: json['stock_desc'],
    roomId: json['room_id'],
  );

  Map<String, dynamic> toJson() => {
    'stock_name': "$brand $type", // Backend mag dalk hierdie veld verwag
    'stock_brand': brand,
    'stock_amount': amount,
    'stock_type': type,
    'stock_desc': description,
    'room_id': roomId,
  };
}
