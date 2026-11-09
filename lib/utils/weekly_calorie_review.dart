import '../models/calorie_settings.dart';
import '../models/weight_entry.dart';
import 'adaptive_calorie_engine.dart';

class WeeklyCalorieReviewProposal {
  const WeeklyCalorieReviewProposal({
    required this.weekStart,
    required this.result,
  });

  final DateTime weekStart;
  final AdaptiveCalorieResult result;
}

abstract final class WeeklyCalorieReviews {
  static WeeklyCalorieReviewProposal? createProposal({
    required Iterable<WeightEntry> entries,
    required CalorieSettings settings,
  }) {
    final weekStarts =
        (entries.map((entry) => _mondayOf(entry.date)).toSet().toList()
          ..sort());
    if (weekStarts.length < 2) return null;
    final result = AdaptiveCalorieEngine.calculate(
      entries: entries,
      targetWeight: settings.targetWeight,
      desiredWeeklyChange: settings.desiredWeeklyChange,
      currentCalories: settings.currentCalories,
      minimumCalories: settings.minimumCalories,
      maximumCalories: settings.maximumCalories,
    );
    if (result.trend == WeightTrend.insufficientData) return null;
    return WeeklyCalorieReviewProposal(
      weekStart: weekStarts.last,
      result: result,
    );
  }

  static bool isNewWeek({
    required DateTime latestWeek,
    DateTime? reviewedWeek,
  }) {
    return reviewedWeek == null ||
        !_dateOnly(latestWeek).isAtSameMomentAs(_dateOnly(reviewedWeek));
  }

  static DateTime _mondayOf(DateTime date) {
    final day = _dateOnly(date);
    return day.subtract(Duration(days: day.weekday - DateTime.monday));
  }

  static DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);
}
