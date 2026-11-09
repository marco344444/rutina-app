class ShoppingItem {
  const ShoppingItem({
    required this.id,
    required this.name,
    this.purchased = false,
    this.productId,
    this.quantity,
    this.unit,
  });

  final String id;
  final String name;
  final bool purchased;
  final String? productId;
  final double? quantity;
  final String? unit;

  ShoppingItem copyWith({bool? purchased, double? quantity}) {
    return ShoppingItem(
      id: id,
      name: name,
      purchased: purchased ?? this.purchased,
      productId: productId,
      quantity: quantity ?? this.quantity,
      unit: unit,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'purchased': purchased,
    if (productId != null) 'productId': productId,
    if (quantity != null) 'quantity': quantity,
    if (unit != null) 'unit': unit,
  };

  factory ShoppingItem.fromJson(Map<String, dynamic> json) {
    return ShoppingItem(
      id: json['id'] as String,
      name: json['name'] as String,
      purchased: json['purchased'] as bool? ?? false,
      productId: json['productId'] as String?,
      quantity: (json['quantity'] as num?)?.toDouble(),
      unit: json['unit'] as String?,
    );
  }
}
