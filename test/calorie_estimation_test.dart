import 'package:flutter_test/flutter_test.dart';

import 'package:routine_app/models/calorie_settings.dart';
import 'package:routine_app/utils/calorie_estimation.dart';

void main() {
  test('estimates maintenance calories with Mifflin-St Jeor', () {
    const settings = CalorieSettings(
      currentCalories: 2000,
      targetWeight: 80,
      desiredWeeklyChange: -0.5,
      minimumCalories: 1500,
      maximumCalories: 3000,
      age: 30,
      sex: 'male',
      activityLevel: 'sedentary',
    );

    expect(
      CalorieEstimation.estimate(
        settings: settings,
        weightKg: 90,
        heightCm: 173,
      ),
      closeTo((10 * 90 + 6.25 * 173 - 5 * 30 + 5) * 1.2, 0.001),
    );
  });

  test('does not estimate without the required personal data', () {
    expect(
      CalorieEstimation.estimate(
        settings: CalorieSettings.defaults,
        weightKg: 90,
        heightCm: 173,
      ),
      isNull,
    );
  });
}
