import 'package:flutter_test/flutter_test.dart';

import 'package:routine_app/models/task.dart';
import 'package:routine_app/utils/progress_aggregation.dart';

Task _task(String id, bool completed) {
  return Task(id: id, title: id, completed: completed);
}

Map<String, List<Task>> _history(Map<String, int> completedByDay) {
  return {
    for (final entry in completedByDay.entries)
      entry.key: [
        _task('done-1', entry.value >= 1),
        _task('done-2', entry.value >= 2),
      ],
  };
}

void main() {
  test('weekly view keeps seven daily periods', () {
    final result = ProgressAggregation.aggregate(
      history: _history({'2026-09-01': 2}),
      period: ProgressPeriod.week,
      referenceDate: DateTime(2026, 9, 6),
    );

    expect(result.length, 7);
    expect(result.map((item) => item.label), [
      'L',
      'M',
      'X',
      'J',
      'V',
      'S',
      'D',
    ]);
    expect(result[1].value, 1);
  });

  test('monthly view groups real calendar weeks and clips crossing days', () {
    final result = ProgressAggregation.aggregate(
      history: _history({
        '2026-06-30': 0,
        '2026-07-01': 2,
        '2026-07-02': 2,
        '2026-07-03': 0,
      }),
      period: ProgressPeriod.month,
      referenceDate: DateTime(2026, 7, 15),
    );

    expect(result.length, 5);
    expect(result.first.label, 'S1');
    expect(result.first.value, closeTo(0.667, 0.001));
  });

  test('quarter and year views aggregate by month', () {
    final history = _history({
      '2026-01-10': 2,
      '2026-02-10': 1,
      '2026-03-10': 0,
      '2026-04-10': 2,
      '2026-12-10': 1,
    });
    final quarter = ProgressAggregation.aggregate(
      history: history,
      period: ProgressPeriod.quarter,
      referenceDate: DateTime(2026, 2, 1),
    );
    final year = ProgressAggregation.aggregate(
      history: history,
      period: ProgressPeriod.year,
      referenceDate: DateTime(2026, 2, 1),
    );

    expect(quarter.length, 3);
    expect(quarter.map((item) => item.label), ['Ene', 'Feb', 'Mar']);
    expect(year.length, 12);
    expect(year[0].value, 1);
    expect(year[1].value, closeTo(0.5, 0.001));
    expect(year[5].value, isNull);
  });

  test(
    'leap-day data is included in February and missing periods stay null',
    () {
      final result = ProgressAggregation.aggregate(
        history: _history({'2024-02-29': 2}),
        period: ProgressPeriod.month,
        referenceDate: DateTime(2024, 2, 29),
      );

      expect(result.length, 5);
      expect(result.last.value, 1);
      expect(
        ProgressAggregation.aggregate(
          history: const {},
          period: ProgressPeriod.week,
          referenceDate: DateTime(2026, 9, 6),
        ).every((item) => item.value == null),
        isTrue,
      );
    },
  );

  test('quantitative tasks contribute their real progress fraction', () {
    final result = ProgressAggregation.aggregate(
      history: {
        '2026-09-01': [
          const Task(id: 'steps', title: 'Pasos', target: 10000, value: 8000),
          _task('done-1', true),
        ],
      },
      period: ProgressPeriod.week,
      referenceDate: DateTime(2026, 9, 6),
    );

    // 8.000/10.000 aporta 0,8 y el booleano 1,0 → media (0,8 + 1) / 2 = 0,9.
    expect(result[1].value, closeTo(0.9, 0.001));
  });

  test('a fully reached quantitative day counts as one', () {
    final result = ProgressAggregation.aggregate(
      history: {
        '2026-09-01': [
          const Task(
            id: 'steps',
            title: 'Pasos',
            target: 10000,
            value: 10000,
          ),
        ],
      },
      period: ProgressPeriod.week,
      referenceDate: DateTime(2026, 9, 6),
    );

    expect(result[1].value, 1);
  });

  test('an unreached quantitative target is not counted as complete', () {
    final result = ProgressAggregation.aggregate(
      history: {
        '2026-09-01': [
          const Task(id: 'steps', title: 'Pasos', target: 10000, value: 2500),
        ],
      },
      period: ProgressPeriod.week,
      referenceDate: DateTime(2026, 9, 6),
    );

    expect(result[1].value, closeTo(0.25, 0.001));
  });

  test('falls back to the persisted completion flag when no value exists', () {
    final result = ProgressAggregation.aggregate(
      history: {
        '2026-09-01': [
          const Task(
            id: 'steps',
            title: 'Pasos',
            target: 10000,
            completed: true,
          ),
        ],
      },
      period: ProgressPeriod.week,
      referenceDate: DateTime(2026, 9, 6),
    );

    expect(result[1].value, 1);
  });
}
