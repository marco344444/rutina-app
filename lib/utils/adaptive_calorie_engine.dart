import '../models/weight_entry.dart';

enum WeightTrend { losing, stable, gaining, insufficientData }

class AdaptiveCalorieResult {
  const AdaptiveCalorieResult({
    required this.previousWeeklyAverage,
    required this.currentWeeklyAverage,
    required this.trend,
    required this.weightChange,
    required this.currentCalories,
    required this.recommendedAdjustment,
    required this.newCalories,
    required this.targetWeight,
  });

  final double? previousWeeklyAverage;
  final double? currentWeeklyAverage;
  final WeightTrend trend;
  final double? weightChange;
  final double currentCalories;
  final double recommendedAdjustment;
  final double newCalories;
  final double targetWeight;
}

abstract final class AdaptiveCalorieEngine {
  static AdaptiveCalorieResult calculate({
    required Iterable<WeightEntry> entries,
    required double targetWeight,
    required double desiredWeeklyChange,
    required double currentCalories,
    required double minimumCalories,
    required double maximumCalories,
    double caloriesPerKilogram = 7700,
    double maximumWeeklyAdjustment = 300,
    double stableThreshold = 0.1,
    double activityCaloriesPerDay = 0,
    double activityRate = 0,
  }) {
    if (minimumCalories > maximumCalories ||
        caloriesPerKilogram <= 0 ||
        maximumWeeklyAdjustment < 0 ||
        stableThreshold < 0) {
      throw ArgumentError('Parámetros de calorías o estabilidad inválidos');
    }
    if (activityCaloriesPerDay < 0 || activityRate < 0 || activityRate > 1) {
      throw ArgumentError('Parámetros de actividad inválidos');
    }

    final weeks = <DateTime, List<double>>{};
    for (final entry in entries) {
      final weekStart = _mondayOf(entry.date);
      weeks.putIfAbsent(weekStart, () => []).add(entry.weight);
    }
    final orderedWeeks = weeks.keys.toList()..sort();
    if (orderedWeeks.length < 2) {
      return AdaptiveCalorieResult(
        previousWeeklyAverage: null,
        currentWeeklyAverage: null,
        trend: WeightTrend.insufficientData,
        weightChange: null,
        currentCalories: currentCalories,
        recommendedAdjustment: 0,
        newCalories: _clamp(currentCalories, minimumCalories, maximumCalories),
        targetWeight: targetWeight,
      );
    }

    final previousAverage = _average(
      weeks[orderedWeeks[orderedWeeks.length - 2]]!,
    );
    final currentAverage = _average(weeks[orderedWeeks.last]!);
    final weightChange = currentAverage - previousAverage;
    final trend = weightChange < -stableThreshold
        ? WeightTrend.losing
        : weightChange > stableThreshold
        ? WeightTrend.gaining
        : WeightTrend.stable;

    final activityAdjustment = activityCaloriesPerDay * activityRate * 7;
    final rawAdjustment =
        (desiredWeeklyChange - weightChange) * caloriesPerKilogram / 7 +
        activityAdjustment;
    final adjustment = _clamp(
      rawAdjustment,
      -maximumWeeklyAdjustment,
      maximumWeeklyAdjustment,
    );
    final newCalories = _clamp(
      currentCalories + adjustment,
      minimumCalories,
      maximumCalories,
    );
    return AdaptiveCalorieResult(
      previousWeeklyAverage: previousAverage,
      currentWeeklyAverage: currentAverage,
      trend: trend,
      weightChange: weightChange,
      currentCalories: currentCalories,
      recommendedAdjustment: newCalories - currentCalories,
      newCalories: newCalories,
      targetWeight: targetWeight,
    );
  }

  static DateTime _mondayOf(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    return day.subtract(Duration(days: day.weekday - DateTime.monday));
  }

  static double _average(List<double> values) =>
      values.reduce((sum, value) => sum + value) / values.length;

  static double _clamp(double value, double minimum, double maximum) =>
      value.clamp(minimum, maximum).toDouble();
}
