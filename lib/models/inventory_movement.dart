enum InventoryMovementType { consume, add }

class InventoryMovement {
  const InventoryMovement({
    required this.productId,
    required this.type,
    required this.quantity,
    required this.date,
  });

  final String productId;
  final InventoryMovementType type;
  final double quantity;
  final DateTime date;

  Map<String, dynamic> toJson() => {
    'productId': productId,
    'type': type.name,
    'quantity': quantity,
    'date': date.toIso8601String(),
  };

  factory InventoryMovement.fromJson(Map<String, dynamic> json) {
    final type = InventoryMovementType.values.firstWhere(
      (value) => value.name == json['type'],
      orElse: () => throw FormatException('Tipo de movimiento inválido'),
    );
    return InventoryMovement(
      productId: json['productId'] as String,
      type: type,
      quantity: (json['quantity'] as num).toDouble(),
      date: DateTime.parse(json['date'] as String),
    );
  }
}
