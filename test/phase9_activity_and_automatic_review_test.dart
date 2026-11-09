import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:routine_app/models/calorie_settings.dart';
import 'package:routine_app/models/reminder_settings.dart';
import 'package:routine_app/models/task.dart';
import 'package:routine_app/models/weekly_calorie_history.dart';
import 'package:routine_app/models/weight_entry.dart';
import 'package:routine_app/services/local_storage_service.dart';
import 'package:routine_app/utils/automatic_calorie_review.dart';
import 'package:routine_app/utils/weekly_activity.dart';

String dayKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

List<Task> tasks({bool training = false, bool steps = false}) => [
  Task(id: 'training', title: 'Entrenamiento', completed: training),
  Task(id: 'steps', title: '10.000 pasos', completed: steps),
];

void main() {
  final reference = DateTime(2026, 9, 16); // Wednesday.

  test('summarizes zero, full, and mixed activity over seven days', () {
    final monday = DateTime(2026, 9, 7);
    final history = <String, List<Task>>{
      dayKey(monday): tasks(training: true, steps: true),
      dayKey(monday.add(const Duration(days: 1))): tasks(training: true),
      dayKey(monday.add(const Duration(days: 2))): tasks(steps: true),
      dayKey(monday.add(const Duration(days: 3))): tasks(training: true),
    };

    final summary = WeeklyActivity.summarize(
      history: history,
      referenceDate: reference,
    );

    expect(summary.trainingDays, 3);
    expect(summary.stepsDays, 2);
    expect(summary.daysInWeek, 7);
    expect(summary.trainingRate, closeTo(3 / 7, 0.0001));
    expect(summary.stepsRate, closeTo(2 / 7, 0.0001));
    expect(summary.combinedRate, closeTo(2.5 / 7, 0.0001));
  });

  test('counts seven days for complete training and steps activity', () {
    final monday = DateTime(2026, 9, 7);
    final history = <String, List<Task>>{
      for (var i = 0; i < 7; i++)
        dayKey(monday.add(Duration(days: i))): tasks(
          training: true,
          steps: true,
        ),
    };

    final summary = WeeklyActivity.summarize(
      history: history,
      referenceDate: reference,
    );

    expect(summary.trainingDays, 7);
    expect(summary.stepsDays, 7);
    expect(summary.combinedRate, 1);
  });

  test('automatic review combines activity with weight and processes once', () {
    const settings = CalorieSettings(
      currentCalories: 2000,
      targetWeight: 80,
      desiredWeeklyChange: -0.4,
      minimumCalories: 1500,
      maximumCalories: 2500,
    );
    final weights = [
      WeightEntry(date: DateTime(2026, 8, 31), weight: 87),
      WeightEntry(date: DateTime(2026, 9, 6), weight: 86.8),
      WeightEntry(date: DateTime(2026, 9, 7), weight: 86.5),
      WeightEntry(date: DateTime(2026, 9, 13), weight: 86.2),
    ];
    final activity = <String, List<Task>>{
      dayKey(DateTime(2026, 9, 7)): tasks(training: true, steps: true),
    };

    final review = AutomaticCalorieReviews.process(
      settings: settings,
      weights: weights,
      activityHistory: activity,
      referenceDate: reference,
      processedHistory: const [],
    );

    expect(review, isNotNull);
    expect(review!.history!.trainingDays, 1);
    expect(review.history!.stepsDays, 1);
    expect(
      review.settings.currentCalories,
      greaterThan(settings.currentCalories),
    );

    final duplicate = AutomaticCalorieReviews.process(
      settings: settings,
      weights: weights,
      activityHistory: activity,
      referenceDate: reference,
      processedHistory: [review.history!],
    );
    expect(duplicate, isNull);
  });

  test('automatic review does not update without two weight weeks', () {
    const settings = CalorieSettings.defaults;
    final review = AutomaticCalorieReviews.process(
      settings: settings,
      weights: [WeightEntry(date: DateTime(2026, 9, 7), weight: 86)],
      activityHistory: const {},
      referenceDate: reference,
      processedHistory: const [],
    );

    expect(review, isNull);
  });

  test(
    'persists weekly history and reminder settings across storage instances',
    () async {
      SharedPreferences.setMockInitialValues({});
      final first = await LocalStorageService.create();
      final history = WeeklyCalorieHistory(
        weekStart: DateTime(2026, 9, 7),
        previousAverageWeight: 87,
        currentAverageWeight: 86.5,
        trainingDays: 4,
        stepsDays: 6,
        previousCalories: 2000,
        newCalories: 2100,
        adjustment: 100,
      );
      await first.saveWeeklyCalorieHistory([history]);
      await first.saveReminderSettings(
        const ReminderSettings(enabled: true, hour: 20, minute: 30),
      );

      final second = await LocalStorageService.create();
      expect(
        (await second.loadWeeklyCalorieHistory()).single.newCalories,
        2100,
      );
      final reminder = await second.loadReminderSettings();
      expect(reminder.enabled, isTrue);
      expect(reminder.hour, 20);
      expect(reminder.minute, 30);
    },
  );
}
