import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:routine_app/models/calorie_settings.dart';
import 'package:routine_app/services/local_storage_service.dart';

void main() {
  test('loads default calorie settings', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = await LocalStorageService.create();

    expect(await storage.loadCalorieSettings(), CalorieSettings.defaults);
  });

  test('saves and reloads calorie settings', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = await LocalStorageService.create();
    const settings = CalorieSettings(
      currentCalories: 2150,
      targetWeight: 78,
      desiredWeeklyChange: -0.4,
      minimumCalories: 1500,
      maximumCalories: 2800,
    );

    await storage.saveCalorieSettings(settings);
    expect(await storage.loadCalorieSettings(), settings);
  });

  test('preserves settings after creating a new storage service', () async {
    SharedPreferences.setMockInitialValues({});
    final first = await LocalStorageService.create();
    await first.saveCalorieSettings(
      CalorieSettings.defaults.copyWith(currentCalories: 2300),
    );

    final second = await LocalStorageService.create();
    expect((await second.loadCalorieSettings()).currentCalories, 2300);
  });
}
