import '../models/product.dart';
import '../models/inventory_movement.dart';
import 'inventory_prediction.dart';

class PurchaseRecommendation {
  const PurchaseRecommendation({
    required this.product,
    required this.quantity,
    this.prediction,
  });

  final Product product;
  final double quantity;
  final InventoryPrediction? prediction;
}

abstract final class PurchaseRecommendations {
  static List<PurchaseRecommendation> forProducts(
    Iterable<Product> products, {
    Iterable<InventoryMovement> movements = const [],
    DateTime? referenceDate,
  }) {
    return products
        .where((product) => product.active)
        .map((product) {
          final prediction = InventoryPrediction.forProduct(
            movements: movements,
            productId: product.id,
            currentQuantity: product.currentQuantity,
            referenceDate: referenceDate,
          );
          final estimatedWeekly = prediction.estimatedWeeklyConsumption;
          final replenishmentLevel = estimatedWeekly == null
              ? product.targetQuantity
              : product.targetQuantity > estimatedWeekly
              ? product.targetQuantity
              : estimatedWeekly;
          return PurchaseRecommendation(
            product: product,
            quantity: replenishmentLevel - product.currentQuantity,
            prediction: estimatedWeekly == null ? null : prediction,
          );
        })
        .where(
          (recommendation) =>
              recommendation.product.currentQuantity <
                  recommendation.product.minimumQuantity &&
              recommendation.quantity > 0,
        )
        .toList();
  }
}
