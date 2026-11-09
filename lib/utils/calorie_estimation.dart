import '../models/calorie_settings.dart';

abstract final class CalorieEstimation {
  static double? estimate({
    required CalorieSettings settings,
    required double weightKg,
    required double heightCm,
  }) {
    final age = settings.age;
    final sex = settings.sex;
    final activityLevel = settings.activityLevel;
    if (age == null ||
        age <= 0 ||
        weightKg <= 0 ||
        heightCm <= 0 ||
        sex == null ||
        activityLevel == null) {
      return null;
    }

    final base = sex == 'male'
        ? 10 * weightKg + 6.25 * heightCm - 5 * age + 5
        : 10 * weightKg + 6.25 * heightCm - 5 * age - 161;
    final factor = _activityFactors[activityLevel];
    if (factor == null) return null;
    return base * factor;
  }

  static const _activityFactors = {
    'sedentary': 1.2,
    'light': 1.375,
    'moderate': 1.55,
    'high': 1.725,
  };
}
