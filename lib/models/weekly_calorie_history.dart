import 'weekly_calorie_review.dart';

class WeeklyCalorieHistory {
  const WeeklyCalorieHistory({
    required this.weekStart,
    required this.previousAverageWeight,
    required this.currentAverageWeight,
    required this.trainingDays,
    required this.stepsDays,
    required this.previousCalories,
    required this.newCalories,
    required this.adjustment,
  });

  final DateTime weekStart;
  final double previousAverageWeight;
  final double currentAverageWeight;
  final int trainingDays;
  final int stepsDays;
  final double previousCalories;
  final double newCalories;
  final double adjustment;

  Map<String, dynamic> toJson() => {
    'weekStart': weekStart.toIso8601String(),
    'previousAverageWeight': previousAverageWeight,
    'currentAverageWeight': currentAverageWeight,
    'trainingDays': trainingDays,
    'stepsDays': stepsDays,
    'previousCalories': previousCalories,
    'newCalories': newCalories,
    'adjustment': adjustment,
  };

  factory WeeklyCalorieHistory.fromJson(Map<String, dynamic> json) {
    return WeeklyCalorieHistory(
      weekStart: DateTime.parse(json['weekStart'] as String),
      previousAverageWeight: (json['previousAverageWeight'] as num).toDouble(),
      currentAverageWeight: (json['currentAverageWeight'] as num).toDouble(),
      trainingDays: json['trainingDays'] as int,
      stepsDays: json['stepsDays'] as int,
      previousCalories: (json['previousCalories'] as num).toDouble(),
      newCalories: (json['newCalories'] as num).toDouble(),
      adjustment: (json['adjustment'] as num).toDouble(),
    );
  }

  WeeklyCalorieReview toReview() => WeeklyCalorieReview(
    weekStart: weekStart,
    reviewedAt: DateTime.now(),
    proposedCalories: newCalories,
    status: WeeklyReviewStatus.applied,
  );
}
