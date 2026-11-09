import '../models/task.dart';

class WeeklyActivitySummary {
  const WeeklyActivitySummary({
    required this.weekStart,
    required this.trainingDays,
    required this.stepsDays,
    required this.daysInWeek,
  });

  final DateTime weekStart;
  final int trainingDays;
  final int stepsDays;
  final int daysInWeek;

  double get trainingRate => trainingDays / daysInWeek;
  double get stepsRate => stepsDays / daysInWeek;
  double get combinedRate => (trainingRate + stepsRate) / 2;
}

abstract final class WeeklyActivity {
  static WeeklyActivitySummary summarize({
    required Map<String, List<Task>> history,
    DateTime? referenceDate,
    String trainingId = 'training',
    String stepsId = 'steps',
  }) {
    final reference = _dateOnly(referenceDate ?? DateTime.now());
    final currentMonday = _mondayOf(reference);
    final weekStart = currentMonday.subtract(const Duration(days: 7));
    var trainingDays = 0;
    var stepsDays = 0;
    for (var day = 0; day < 7; day++) {
      final date = weekStart.add(Duration(days: day));
      final tasks = history[_key(date)] ?? const <Task>[];
      if (tasks.any((task) => task.id == trainingId && task.completed)) {
        trainingDays++;
      }
      if (tasks.any((task) => task.id == stepsId && task.completed)) {
        stepsDays++;
      }
    }
    return WeeklyActivitySummary(
      weekStart: weekStart,
      trainingDays: trainingDays,
      stepsDays: stepsDays,
      daysInWeek: 7,
    );
  }

  static DateTime _mondayOf(DateTime date) =>
      date.subtract(Duration(days: date.weekday - DateTime.monday));

  static DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static String _key(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
