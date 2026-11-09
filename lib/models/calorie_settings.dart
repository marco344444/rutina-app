class CalorieSettings {
  const CalorieSettings({
    required this.currentCalories,
    required this.targetWeight,
    required this.desiredWeeklyChange,
    required this.minimumCalories,
    required this.maximumCalories,
    this.age,
    this.sex,
    this.activityLevel,
  });

  static const defaults = CalorieSettings(
    currentCalories: 2000,
    targetWeight: 80,
    desiredWeeklyChange: -0.5,
    minimumCalories: 1500,
    maximumCalories: 3000,
  );

  final double currentCalories;
  final double targetWeight;
  final double desiredWeeklyChange;
  final double minimumCalories;
  final double maximumCalories;
  final int? age;
  final String? sex;
  final String? activityLevel;

  CalorieSettings copyWith({
    double? currentCalories,
    double? targetWeight,
    double? desiredWeeklyChange,
    double? minimumCalories,
    double? maximumCalories,
    int? age,
    String? sex,
    String? activityLevel,
  }) {
    return CalorieSettings(
      currentCalories: currentCalories ?? this.currentCalories,
      targetWeight: targetWeight ?? this.targetWeight,
      desiredWeeklyChange: desiredWeeklyChange ?? this.desiredWeeklyChange,
      minimumCalories: minimumCalories ?? this.minimumCalories,
      maximumCalories: maximumCalories ?? this.maximumCalories,
      age: age ?? this.age,
      sex: sex ?? this.sex,
      activityLevel: activityLevel ?? this.activityLevel,
    );
  }

  Map<String, dynamic> toJson() => {
    'currentCalories': currentCalories,
    'targetWeight': targetWeight,
    'desiredWeeklyChange': desiredWeeklyChange,
    'minimumCalories': minimumCalories,
    'maximumCalories': maximumCalories,
    'age': age,
    'sex': sex,
    'activityLevel': activityLevel,
  };

  factory CalorieSettings.fromJson(Map<String, dynamic> json) {
    return CalorieSettings(
      currentCalories:
          (json['currentCalories'] as num?)?.toDouble() ??
          defaults.currentCalories,
      targetWeight:
          (json['targetWeight'] as num?)?.toDouble() ?? defaults.targetWeight,
      desiredWeeklyChange:
          (json['desiredWeeklyChange'] as num?)?.toDouble() ??
          defaults.desiredWeeklyChange,
      minimumCalories:
          (json['minimumCalories'] as num?)?.toDouble() ??
          defaults.minimumCalories,
      maximumCalories:
          (json['maximumCalories'] as num?)?.toDouble() ??
          defaults.maximumCalories,
      age: (json['age'] as num?)?.toInt(),
      sex: json['sex'] as String?,
      activityLevel: json['activityLevel'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is CalorieSettings &&
      currentCalories == other.currentCalories &&
      targetWeight == other.targetWeight &&
      desiredWeeklyChange == other.desiredWeeklyChange &&
      minimumCalories == other.minimumCalories &&
      maximumCalories == other.maximumCalories &&
      age == other.age &&
      sex == other.sex &&
      activityLevel == other.activityLevel;

  @override
  int get hashCode => Object.hash(
    currentCalories,
    targetWeight,
    desiredWeeklyChange,
    minimumCalories,
    maximumCalories,
    age,
    sex,
    activityLevel,
  );
}
