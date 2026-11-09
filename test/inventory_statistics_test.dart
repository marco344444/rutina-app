import 'package:flutter_test/flutter_test.dart';

import 'package:routine_app/models/inventory_movement.dart';
import 'package:routine_app/utils/inventory_statistics.dart';
import 'package:routine_app/utils/inventory_prediction.dart';

InventoryMovement _movement(
  String productId,
  InventoryMovementType type,
  double quantity,
  DateTime date,
) {
  return InventoryMovement(
    productId: productId,
    type: type,
    quantity: quantity,
    date: date,
  );
}

void main() {
  final reference = DateTime(2026, 9, 6);

  test('sums only consumption for the selected product and ignores adds', () {
    final movements = [
      _movement('eggs', InventoryMovementType.consume, 4, DateTime(2026, 9, 1)),
      _movement('eggs', InventoryMovementType.consume, 2, DateTime(2026, 9, 2)),
      _movement('eggs', InventoryMovementType.add, 30, DateTime(2026, 9, 3)),
      _movement('milk', InventoryMovementType.consume, 5, DateTime(2026, 9, 3)),
    ];

    final metric = InventoryStatistics.metrics(
      movements: movements,
      productId: 'eggs',
      referenceDate: reference,
    );

    expect(metric.last7Days, 6);
    expect(metric.last30Days, 6);
    expect(metric.averageWeekly, closeTo(1.4, .001));
    expect(metric.averageDaily, closeTo(.2, .001));
  });

  test('returns null metrics when there are no movements', () {
    final metric = InventoryStatistics.metrics(
      movements: const [],
      productId: 'eggs',
      referenceDate: reference,
    );

    expect(metric.last7Days, isNull);
    expect(metric.last30Days, isNull);
    expect(metric.averageWeekly, isNull);
    expect(metric.averageDaily, isNull);
  });

  test('groups daily, weekly, and monthly periods with zero gaps', () {
    final movements = [
      _movement(
        'eggs',
        InventoryMovementType.consume,
        4,
        DateTime(2026, 8, 31),
      ),
      _movement('eggs', InventoryMovementType.consume, 2, DateTime(2026, 9, 1)),
      _movement(
        'eggs',
        InventoryMovementType.consume,
        5,
        DateTime(2026, 9, 20),
      ),
    ];

    final daily = InventoryStatistics.daily(
      movements: movements,
      productId: 'eggs',
      referenceDate: reference,
    );
    final weekly = InventoryStatistics.weekly(
      movements: movements,
      productId: 'eggs',
      days: 30,
      referenceDate: reference,
    );
    final monthly = InventoryStatistics.monthly(
      movements: movements,
      productId: 'eggs',
      referenceDate: reference,
    );

    expect(daily.length, 7);
    expect(daily.map((bucket) => bucket.quantity), [4, 2, 0, 0, 0, 0, 0]);
    expect(weekly.length, 5);
    expect(weekly.map((bucket) => bucket.quantity).reduce((a, b) => a + b), 6);
    expect(monthly.length, 12);
    expect(monthly.last.quantity, 7);
  });

  test('honors date boundaries and ranks multiple products', () {
    final movements = [
      _movement('eggs', InventoryMovementType.consume, 3, DateTime(2026, 8, 7)),
      _movement('eggs', InventoryMovementType.consume, 8, DateTime(2026, 8, 7)),
      _movement(
        'milk',
        InventoryMovementType.consume,
        12,
        DateTime(2026, 9, 6),
      ),
      _movement('milk', InventoryMovementType.consume, 4, DateTime(2026, 9, 7)),
    ];

    final metric = InventoryStatistics.metrics(
      movements: movements,
      productId: 'eggs',
      referenceDate: reference,
    );
    final ranking = InventoryStatistics.ranking(
      movements: movements,
      referenceDate: reference,
    );

    expect(metric.last30Days, isNull);
    expect(ranking.keys.first, 'milk');
    expect(ranking['milk'], 12);
  });

  test('calculates prediction from the last 30 days', () {
    final prediction = InventoryPrediction.forProduct(
      movements: [
        _movement(
          'eggs',
          InventoryMovementType.consume,
          3,
          DateTime(2026, 9, 1),
        ),
        _movement(
          'eggs',
          InventoryMovementType.consume,
          4,
          DateTime(2026, 9, 2),
        ),
      ],
      productId: 'eggs',
      currentQuantity: 14,
      referenceDate: reference,
    );

    expect(prediction.averageDaily, closeTo(7 / 30, .001));
    expect(prediction.averageWeekly, closeTo(49 / 30, .001));
    expect(prediction.estimatedWeeklyConsumption, closeTo(49 / 30, .001));
    expect(prediction.daysRemaining, closeTo(60, .001));
  });

  test('does not estimate without enough history or with zero consumption', () {
    final shortHistory = InventoryPrediction.forProduct(
      movements: [
        _movement(
          'eggs',
          InventoryMovementType.consume,
          3,
          DateTime(2026, 9, 1),
        ),
      ],
      productId: 'eggs',
      currentQuantity: 10,
      referenceDate: reference,
    );
    final zeroConsumption = InventoryPrediction.forProduct(
      movements: [
        _movement(
          'eggs',
          InventoryMovementType.consume,
          0,
          DateTime(2026, 9, 1),
        ),
        _movement(
          'eggs',
          InventoryMovementType.consume,
          0,
          DateTime(2026, 9, 2),
        ),
      ],
      productId: 'eggs',
      currentQuantity: 10,
      referenceDate: reference,
    );

    expect(shortHistory.averageDaily, isNull);
    expect(shortHistory.daysRemaining, isNull);
    expect(zeroConsumption.estimatedWeeklyConsumption, isNull);
  });

  test('returns zero days for empty inventory and ignores older movements', () {
    final prediction = InventoryPrediction.forProduct(
      movements: [
        _movement(
          'eggs',
          InventoryMovementType.consume,
          3,
          DateTime(2026, 8, 7),
        ),
        _movement(
          'eggs',
          InventoryMovementType.consume,
          3,
          DateTime(2026, 9, 1),
        ),
        _movement(
          'eggs',
          InventoryMovementType.consume,
          4,
          DateTime(2026, 9, 2),
        ),
      ],
      productId: 'eggs',
      currentQuantity: 0,
      referenceDate: reference,
    );

    expect(prediction.averageDaily, closeTo(7 / 30, .001));
    expect(prediction.daysRemaining, 0);
  });
}
