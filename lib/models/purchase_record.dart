class PurchaseRecord {
  const PurchaseRecord({
    this.productId,
    required this.productName,
    required this.quantity,
    required this.unit,
    required this.date,
  });

  final String? productId;
  final String productName;
  final double quantity;
  final String unit;
  final DateTime date;

  Map<String, dynamic> toJson() => {
    if (productId != null) 'productId': productId,
    'productName': productName,
    'quantity': quantity,
    'unit': unit,
    'date': date.toIso8601String(),
  };

  factory PurchaseRecord.fromJson(Map<String, dynamic> json) {
    return PurchaseRecord(
      productId: json['productId'] as String?,
      productName: json['productName'] as String,
      quantity: (json['quantity'] as num).toDouble(),
      unit: json['unit'] as String,
      date: DateTime.parse(json['date'] as String),
    );
  }
}
