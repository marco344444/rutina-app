import '../models/calorie_settings.dart';
import '../models/weekly_calorie_history.dart';
import '../models/weight_entry.dart';
import '../models/task.dart';
import 'weekly_activity.dart';
import 'adaptive_calorie_engine.dart';

class AutomaticCalorieReview {
  const AutomaticCalorieReview({required this.history, required this.settings});

  final WeeklyCalorieHistory? history;
  final CalorieSettings settings;
}

abstract final class AutomaticCalorieReviews {
  static AutomaticCalorieReview? process({
    required CalorieSettings settings,
    required Iterable<WeightEntry> weights,
    required Map<String, List<Task>> activityHistory,
    required Iterable<WeeklyCalorieHistory> processedHistory,
    DateTime? referenceDate,
  }) {
    final activity = WeeklyActivity.summarize(
      history: activityHistory,
      referenceDate: referenceDate,
    );
    if (processedHistory.any(
      (item) => _sameDay(item.weekStart, activity.weekStart),
    )) {
      return null;
    }
    final cutoff = activity.weekStart.add(const Duration(days: 6));
    final relevantWeights = weights.where(
      (entry) => entry.date.isBefore(cutoff.add(const Duration(days: 1))),
    );
    final result = AdaptiveCalorieEngine.calculate(
      entries: relevantWeights,
      targetWeight: settings.targetWeight,
      desiredWeeklyChange: settings.desiredWeeklyChange,
      currentCalories: settings.currentCalories,
      minimumCalories: settings.minimumCalories,
      maximumCalories: settings.maximumCalories,
      activityCaloriesPerDay: 200,
      activityRate: activity.combinedRate,
    );
    if (result.trend == WeightTrend.insufficientData) return null;
    final historyEntry = WeeklyCalorieHistory(
      weekStart: activity.weekStart,
      previousAverageWeight: result.previousWeeklyAverage!,
      currentAverageWeight: result.currentWeeklyAverage!,
      trainingDays: activity.trainingDays,
      stepsDays: activity.stepsDays,
      previousCalories: settings.currentCalories,
      newCalories: result.newCalories,
      adjustment: result.recommendedAdjustment,
    );
    return AutomaticCalorieReview(
      history: historyEntry,
      settings: settings.copyWith(currentCalories: result.newCalories),
    );
  }

  static bool _sameDay(DateTime first, DateTime second) =>
      first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;
}
