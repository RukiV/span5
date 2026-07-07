class Stock {
  final int? id;
  final String name;
  final String brand;
  final int amount;
  final String type;
  final String? description;
  final int? roomId;

  Stock({
    this.id,
    required this.name,
    required this.brand,
    required this.amount,
    required this.type,
    this.description,
    this.roomId,
  });

  factory Stock.fromJson(Map<String, dynamic> json) => Stock(
    id: json['stock_id'],
    name: json['stock_name'] ?? "",
    brand: json['stock_brand'] ?? "",
    amount: json['stock_amount'] ?? 0,
    type: json['stock_type'] ?? "",
    description: json['stock_desc'],
    roomId: json['room_id'],
  );

  Map<String, dynamic> toJson() => {
    'stock_name': name,
    'stock_brand': brand,
    'stock_amount': amount,
    'stock_type': type,
    'stock_desc': description,
    'room_id': roomId,
  };
}
