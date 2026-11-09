import '../models/task.dart';

enum ProgressPeriod { week, month, quarter, year }

class ProgressAggregate {
  const ProgressAggregate({required this.label, required this.value});

  final String label;
  final double? value;
}

abstract final class ProgressAggregation {
  static List<ProgressAggregate> aggregate({
    required Map<String, List<Task>> history,
    required ProgressPeriod period,
    DateTime? referenceDate,
  }) {
    final date = _dateOnly(referenceDate ?? DateTime.now());
    return switch (period) {
      ProgressPeriod.week => _week(history, date),
      ProgressPeriod.month => _month(history, date),
      ProgressPeriod.quarter => _months(history, date, _quarterStart(date), 3),
      ProgressPeriod.year => _months(history, date, DateTime(date.year), 12),
    };
  }

  static List<ProgressAggregate> _week(
    Map<String, List<Task>> history,
    DateTime date,
  ) {
    final monday = date.subtract(Duration(days: date.weekday - 1));
    const labels = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
    return List.generate(7, (index) {
      final day = monday.add(Duration(days: index));
      return ProgressAggregate(
        label: labels[index],
        value: _forDates(history, [day]),
      );
    });
  }

  static List<ProgressAggregate> _month(
    Map<String, List<Task>> history,
    DateTime date,
  ) {
    final first = DateTime(date.year, date.month);
    final last = DateTime(date.year, date.month + 1, 0);
    final firstMonday = first.subtract(
      Duration(days: first.weekday - DateTime.monday),
    );
    final lastMonday = last.subtract(
      Duration(days: last.weekday - DateTime.monday),
    );
    final count = lastMonday.difference(firstMonday).inDays ~/ 7 + 1;

    return List.generate(count, (index) {
      final monday = firstMonday.add(Duration(days: index * 7));
      final days = List.generate(7, (dayIndex) {
        final day = monday.add(Duration(days: dayIndex));
        return day.month == date.month ? day : null;
      }).whereType<DateTime>();
      return ProgressAggregate(
        label: 'S${index + 1}',
        value: _forDates(history, days),
      );
    });
  }

  static List<ProgressAggregate> _months(
    Map<String, List<Task>> history,
    DateTime date,
    DateTime start,
    int count,
  ) {
    return List.generate(count, (index) {
      final month = DateTime(start.year, start.month + index);
      return ProgressAggregate(
        label: _monthLabel(month.month),
        value: _forMonth(history, month),
      );
    });
  }

  static double? _forMonth(Map<String, List<Task>> history, DateTime month) {
    final days = history.keys
        .map(DateTime.tryParse)
        .whereType<DateTime>()
        .where((date) => date.year == month.year && date.month == month.month);
    return _forDates(history, days);
  }

  static double? _forDates(
    Map<String, List<Task>> history,
    Iterable<DateTime> dates,
  ) {
    var score = 0.0;
    var possible = 0;
    for (final date in dates) {
      final tasks = history[_key(date)];
      if (tasks == null || tasks.isEmpty) continue;
      possible += tasks.length;
      for (final task in tasks) {
        if (task.isQuantitative) {
          // Las tareas cuantitativas (p. ej. 10.000 pasos) aportan su
          // fracción de progreso real (8.000/10.000 = 0,8), no solo 0 o 1.
          final target = task.target ?? 1;
          final achieved = task.value ?? (task.completed ? target : 0);
          score += (achieved / target).clamp(0.0, 1.0);
        } else {
          score += task.completed ? 1 : 0;
        }
      }
    }
    return possible == 0 ? null : score / possible;
  }

  static DateTime _quarterStart(DateTime date) {
    final month = ((date.month - 1) ~/ 3) * 3 + 1;
    return DateTime(date.year, month);
  }

  static DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static String _key(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  static String _monthLabel(int month) {
    const labels = [
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
    ];
    return labels[month - 1];
  }
}
