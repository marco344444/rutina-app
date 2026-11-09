import '../models/inventory_movement.dart';

class ConsumptionMetric {
  const ConsumptionMetric({
    required this.last7Days,
    required this.last30Days,
    required this.averageWeekly,
    required this.averageDaily,
  });

  final double? last7Days;
  final double? last30Days;
  final double? averageWeekly;
  final double? averageDaily;
}

class ConsumptionBucket {
  const ConsumptionBucket({required this.label, required this.quantity});

  final String label;
  final double quantity;
}

abstract final class InventoryStatistics {
  static ConsumptionMetric metrics({
    required Iterable<InventoryMovement> movements,
    required String productId,
    DateTime? referenceDate,
  }) {
    final date = _dateOnly(referenceDate ?? DateTime.now());
    final consumed = _consumptionFor(movements, productId);
    final last7 = _sumBetween(
      consumed,
      date.subtract(const Duration(days: 6)),
      date,
    );
    final last30 = _sumBetween(
      consumed,
      date.subtract(const Duration(days: 29)),
      date,
    );
    final hasData7 = _hasDataBetween(
      consumed,
      date.subtract(const Duration(days: 6)),
      date,
    );
    final hasData30 = _hasDataBetween(
      consumed,
      date.subtract(const Duration(days: 29)),
      date,
    );
    return ConsumptionMetric(
      last7Days: hasData7 ? last7 : null,
      last30Days: hasData30 ? last30 : null,
      averageWeekly: hasData30 ? last30 / (30 / 7) : null,
      averageDaily: hasData30 ? last30 / 30 : null,
    );
  }

  static int consumptionDays({
    required Iterable<InventoryMovement> movements,
    required String productId,
    DateTime? referenceDate,
    int days = 30,
  }) {
    final date = _dateOnly(referenceDate ?? DateTime.now());
    final start = date.subtract(Duration(days: days - 1));
    return _consumptionFor(movements, productId).keys.where((key) {
      final movementDate = DateTime.tryParse(key);
      return movementDate != null &&
          !movementDate.isBefore(start) &&
          !movementDate.isAfter(date);
    }).length;
  }

  static List<ConsumptionBucket> daily({
    required Iterable<InventoryMovement> movements,
    required String productId,
    DateTime? referenceDate,
  }) {
    final date = _dateOnly(referenceDate ?? DateTime.now());
    final consumed = _consumptionFor(movements, productId);
    return List.generate(7, (index) {
      final day = date.subtract(Duration(days: 6 - index));
      return ConsumptionBucket(
        label: _dayLabel(day.weekday),
        quantity: consumed[_key(day)] ?? 0,
      );
    });
  }

  static List<ConsumptionBucket> weekly({
    required Iterable<InventoryMovement> movements,
    required String productId,
    required int days,
    DateTime? referenceDate,
  }) {
    final date = _dateOnly(referenceDate ?? DateTime.now());
    final consumed = _consumptionFor(movements, productId);
    final weeks = (days / 7).ceil();
    final rangeStart = date.subtract(Duration(days: days - 1));
    return List.generate(weeks, (index) {
      final start = rangeStart.add(Duration(days: index * 7));
      final proposedEnd = start.add(const Duration(days: 6));
      final end = proposedEnd.isAfter(date) ? date : proposedEnd;
      return ConsumptionBucket(
        label: 'S${index + 1}',
        quantity: _sumBetween(consumed, start, end),
      );
    });
  }

  static List<ConsumptionBucket> monthly({
    required Iterable<InventoryMovement> movements,
    required String productId,
    DateTime? referenceDate,
  }) {
    final date = _dateOnly(referenceDate ?? DateTime.now());
    final consumed = _consumptionFor(movements, productId);
    return List.generate(12, (index) {
      final month = DateTime(date.year, date.month - 11 + index);
      final start = DateTime(month.year, month.month);
      final end = DateTime(month.year, month.month + 1, 0);
      return ConsumptionBucket(
        label: _monthLabel(month.month),
        quantity: _sumBetween(consumed, start, end),
      );
    });
  }

  static Map<String, double> ranking({
    required Iterable<InventoryMovement> movements,
    DateTime? referenceDate,
    int days = 30,
  }) {
    final date = _dateOnly(referenceDate ?? DateTime.now());
    final start = date.subtract(Duration(days: days - 1));
    final totals = <String, double>{};
    for (final movement in movements) {
      final movementDate = _dateOnly(movement.date);
      if (movement.type != InventoryMovementType.consume ||
          movementDate.isBefore(start) ||
          movementDate.isAfter(date)) {
        continue;
      }
      totals.update(
        movement.productId,
        (value) => value + movement.quantity,
        ifAbsent: () => movement.quantity,
      );
    }
    return Map.fromEntries(
      totals.entries.toList()..sort((a, b) => b.value.compareTo(a.value)),
    );
  }

  static Map<String, double> _consumptionFor(
    Iterable<InventoryMovement> movements,
    String productId,
  ) {
    final totals = <String, double>{};
    for (final movement in movements) {
      if (movement.productId != productId ||
          movement.type != InventoryMovementType.consume) {
        continue;
      }
      final date = _dateOnly(movement.date);
      totals.update(
        _key(date),
        (value) => value + movement.quantity,
        ifAbsent: () => movement.quantity,
      );
    }
    return totals;
  }

  static double _sumBetween(
    Map<String, double> values,
    DateTime start,
    DateTime end,
  ) {
    var total = 0.0;
    for (
      var date = _dateOnly(start);
      !date.isAfter(_dateOnly(end));
      date = date.add(const Duration(days: 1))
    ) {
      total += values[_key(date)] ?? 0;
    }
    return total;
  }

  static bool _hasDataBetween(
    Map<String, double> values,
    DateTime start,
    DateTime end,
  ) {
    return values.keys.any((key) {
      final date = DateTime.tryParse(key);
      return date != null &&
          !date.isBefore(_dateOnly(start)) &&
          !date.isAfter(_dateOnly(end));
    });
  }

  static DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static String _key(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  static String _dayLabel(int weekday) =>
      const ['L', 'M', 'X', 'J', 'V', 'S', 'D'][weekday - 1];

  static String _monthLabel(int month) => const [
    'Ene',
    'Feb',
    'Mar',
    'Abr',
    'May',
    'Jun',
    'Jul',
    'Ago',
    'Sep',
    'Oct',
    'Nov',
    'Dic',
  ][month - 1];
}
