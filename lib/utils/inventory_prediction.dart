import '../models/inventory_movement.dart';
import 'inventory_statistics.dart';

class InventoryPrediction {
  const InventoryPrediction({
    required this.averageDaily,
    required this.averageWeekly,
    required this.daysRemaining,
    required this.estimatedWeeklyConsumption,
  });

  final double? averageDaily;
  final double? averageWeekly;
  final double? daysRemaining;
  final double? estimatedWeeklyConsumption;

  static InventoryPrediction forProduct({
    required Iterable<InventoryMovement> movements,
    required String productId,
    required double currentQuantity,
    DateTime? referenceDate,
    int periodDays = 30,
    int minimumConsumptionDays = 2,
  }) {
    final metrics = InventoryStatistics.metrics(
      movements: movements,
      productId: productId,
      referenceDate: referenceDate,
    );
    final recordedDays = InventoryStatistics.consumptionDays(
      movements: movements,
      productId: productId,
      referenceDate: referenceDate,
      days: periodDays,
    );
    if (recordedDays < minimumConsumptionDays ||
        metrics.averageDaily == null ||
        metrics.averageDaily == 0) {
      return const InventoryPrediction(
        averageDaily: null,
        averageWeekly: null,
        daysRemaining: null,
        estimatedWeeklyConsumption: null,
      );
    }

    final averageDaily = metrics.averageDaily!;
    return InventoryPrediction(
      averageDaily: averageDaily,
      averageWeekly: averageDaily * 7,
      daysRemaining: currentQuantity / averageDaily,
      estimatedWeeklyConsumption: averageDaily * 7,
    );
  }
}
