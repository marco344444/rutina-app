import 'package:flutter_test/flutter_test.dart';

import 'package:routine_app/models/task.dart';

void main() {
  test('persists quantitative habit targets', () {
    const task = Task(id: 'steps', title: '10.000 pasos', target: 10000);
    final restored = Task.fromJson(task.toJson());

    expect(restored.isQuantitative, isTrue);
    expect(restored.target, 10000);
    expect(restored.completed, isFalse);
  });

  test('keeps regular habits boolean by default', () {
    const task = Task(id: 'journal', title: 'Diario');

    expect(task.isQuantitative, isFalse);
    expect(task.target, isNull);
  });

  test('persists the achieved value of quantitative habits', () {
    final task = Task(
      id: 'steps',
      title: '10.000 pasos',
      target: 10000,
      value: 8750,
    );
    final restored = Task.fromJson(task.toJson());

    expect(restored.value, 8750);
    expect(restored.copyWith(value: 10000).value, 10000);
  });
}
