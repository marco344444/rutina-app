import 'package:flutter_test/flutter_test.dart';

import 'package:routine_app/models/weight_entry.dart';
import 'package:routine_app/utils/adaptive_calorie_engine.dart';

WeightEntry _weight(double value, DateTime date) =>
    WeightEntry(date: date, weight: value);

void main() {
  test('detects weight loss from weekly averages', () {
    final result = AdaptiveCalorieEngine.calculate(
      entries: [
        _weight(90, DateTime(2026, 8, 24)),
        _weight(89, DateTime(2026, 8, 30)),
        _weight(88, DateTime(2026, 8, 31)),
        _weight(87, DateTime(2026, 9, 6)),
      ],
      desiredWeeklyChange: -0.5,
      targetWeight: 80,
      currentCalories: 2200,
      minimumCalories: 1600,
      maximumCalories: 3000,
    );

    expect(result.previousWeeklyAverage, 89.5);
    expect(result.currentWeeklyAverage, 87.5);
    expect(result.weightChange, -2);
    expect(result.trend, WeightTrend.losing);
  });

  test('detects weight gain and stable weight', () {
    final gaining = AdaptiveCalorieEngine.calculate(
      entries: [
        _weight(80, DateTime(2026, 8, 24)),
        _weight(81, DateTime(2026, 8, 31)),
      ],
      desiredWeeklyChange: 0.5,
      targetWeight: 80,
      currentCalories: 2200,
      minimumCalories: 1600,
      maximumCalories: 3000,
    );
    final stable = AdaptiveCalorieEngine.calculate(
      entries: [
        _weight(80, DateTime(2026, 8, 24)),
        _weight(80.05, DateTime(2026, 8, 31)),
      ],
      desiredWeeklyChange: 0,
      targetWeight: 80,
      currentCalories: 2200,
      minimumCalories: 1600,
      maximumCalories: 3000,
    );

    expect(gaining.trend, WeightTrend.gaining);
    expect(stable.trend, WeightTrend.stable);
  });

  test('supports multiple records and incomplete weeks', () {
    final result = AdaptiveCalorieEngine.calculate(
      entries: [
        _weight(90, DateTime(2026, 8, 24)),
        _weight(88, DateTime(2026, 8, 25)),
        _weight(87, DateTime(2026, 8, 31)),
      ],
      desiredWeeklyChange: -0.5,
      targetWeight: 80,
      currentCalories: 2200,
      minimumCalories: 1600,
      maximumCalories: 3000,
    );

    expect(result.previousWeeklyAverage, 89);
    expect(result.currentWeeklyAverage, 87);
  });

  test('returns insufficient data with one relevant week', () {
    final result = AdaptiveCalorieEngine.calculate(
      entries: [_weight(80, DateTime(2026, 9, 1))],
      desiredWeeklyChange: -0.5,
      targetWeight: 80,
      currentCalories: 2200,
      minimumCalories: 1600,
      maximumCalories: 3000,
    );

    expect(result.trend, WeightTrend.insufficientData);
    expect(result.weightChange, isNull);
    expect(result.recommendedAdjustment, 0);
  });

  test('limits adjustment and respects calorie bounds', () {
    final limited = AdaptiveCalorieEngine.calculate(
      entries: [
        _weight(90, DateTime(2026, 8, 24)),
        _weight(90, DateTime(2026, 8, 31)),
      ],
      desiredWeeklyChange: -2,
      maximumWeeklyAdjustment: 100,
      targetWeight: 80,
      currentCalories: 2200,
      minimumCalories: 1600,
      maximumCalories: 3000,
    );
    final minimum = AdaptiveCalorieEngine.calculate(
      entries: [
        _weight(90, DateTime(2026, 8, 24)),
        _weight(90, DateTime(2026, 8, 31)),
      ],
      desiredWeeklyChange: -2,
      currentCalories: 1650,
      maximumWeeklyAdjustment: 300,
      targetWeight: 80,
      minimumCalories: 1600,
      maximumCalories: 3000,
    );
    final maximum = AdaptiveCalorieEngine.calculate(
      entries: [
        _weight(80, DateTime(2026, 8, 24)),
        _weight(80, DateTime(2026, 8, 31)),
      ],
      desiredWeeklyChange: 2,
      currentCalories: 2950,
      maximumWeeklyAdjustment: 300,
      targetWeight: 80,
      minimumCalories: 1600,
      maximumCalories: 3000,
    );

    expect(limited.recommendedAdjustment, -100);
    expect(minimum.newCalories, 1600);
    expect(maximum.newCalories, 3000);
  });

  test('groups dates correctly and ignores older weeks', () {
    final result = AdaptiveCalorieEngine.calculate(
      entries: [
        _weight(100, DateTime(2026, 7, 1)),
        _weight(90, DateTime(2026, 8, 24)),
        _weight(89, DateTime(2026, 8, 31)),
      ],
      desiredWeeklyChange: -0.5,
      targetWeight: 80,
      currentCalories: 2200,
      minimumCalories: 1600,
      maximumCalories: 3000,
    );

    expect(result.previousWeeklyAverage, 90);
    expect(result.currentWeeklyAverage, 89);
  });
}
