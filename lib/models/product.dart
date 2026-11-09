class Product {
  const Product({
    required this.id,
    required this.name,
    required this.category,
    required this.unit,
    required this.currentQuantity,
    required this.minimumQuantity,
    required this.targetQuantity,
    this.active = true,
  });

  final String id;
  final String name;
  final String category;
  final String unit;
  final double currentQuantity;
  final double minimumQuantity;
  final double targetQuantity;
  final bool active;

  Product copyWith({
    String? name,
    String? category,
    String? unit,
    double? currentQuantity,
    double? minimumQuantity,
    double? targetQuantity,
    bool? active,
  }) {
    return Product(
      id: id,
      name: name ?? this.name,
      category: category ?? this.category,
      unit: unit ?? this.unit,
      currentQuantity: currentQuantity ?? this.currentQuantity,
      minimumQuantity: minimumQuantity ?? this.minimumQuantity,
      targetQuantity: targetQuantity ?? this.targetQuantity,
      active: active ?? this.active,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'category': category,
    'unit': unit,
    'currentQuantity': currentQuantity,
    'minimumQuantity': minimumQuantity,
    'targetQuantity': targetQuantity,
    'active': active,
  };

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as String,
      name: json['name'] as String,
      category: json['category'] as String? ?? 'Sin categoría',
      unit: json['unit'] as String? ?? 'unidad',
      currentQuantity: (json['currentQuantity'] as num?)?.toDouble() ?? 0,
      minimumQuantity: (json['minimumQuantity'] as num?)?.toDouble() ?? 0,
      targetQuantity: (json['targetQuantity'] as num?)?.toDouble() ?? 0,
      active: json['active'] as bool? ?? true,
    );
  }
}
