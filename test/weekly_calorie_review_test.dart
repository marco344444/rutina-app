import 'package:flutter_test/flutter_test.dart';

import 'package:routine_app/models/calorie_settings.dart';
import 'package:routine_app/models/weight_entry.dart';
import 'package:routine_app/utils/weekly_calorie_review.dart';

WeightEntry _weight(double value, DateTime date) =>
    WeightEntry(date: date, weight: value);

void main() {
  const settings = CalorieSettings(
    currentCalories: 2200,
    targetWeight: 80,
    desiredWeeklyChange: -0.5,
    minimumCalories: 1600,
    maximumCalories: 2800,
  );

  final weights = [
    _weight(90, DateTime(2026, 8, 24)),
    _weight(89, DateTime(2026, 8, 31)),
  ];

  test('detects a new latest calendar week and creates a proposal', () {
    final proposal = WeeklyCalorieReviews.createProposal(
      entries: weights,
      settings: settings,
    );

    expect(proposal, isNotNull);
    expect(proposal!.weekStart, DateTime(2026, 8, 31));
    expect(proposal.result.newCalories, inInclusiveRange(1600, 2800));
    expect(
      WeeklyCalorieReviews.isNewWeek(latestWeek: proposal.weekStart),
      isTrue,
    );
  });

  test('does not treat the same week as new', () {
    expect(
      WeeklyCalorieReviews.isNewWeek(
        latestWeek: DateTime(2026, 8, 31),
        reviewedWeek: DateTime(2026, 8, 31),
      ),
      isFalse,
    );
  });

  test('returns no proposal with insufficient weekly data', () {
    expect(
      WeeklyCalorieReviews.createProposal(
        entries: [_weight(90, DateTime(2026, 8, 31))],
        settings: settings,
      ),
      isNull,
    );
  });

  test('respects calorie limits through the engine', () {
    final proposal = WeeklyCalorieReviews.createProposal(
      entries: [
        _weight(90, DateTime(2026, 8, 24)),
        _weight(90, DateTime(2026, 8, 31)),
      ],
      settings: settings.copyWith(currentCalories: 1650),
    );

    expect(proposal!.result.newCalories, greaterThanOrEqualTo(1600));
    expect(proposal.result.newCalories, lessThanOrEqualTo(2800));
  });
}
