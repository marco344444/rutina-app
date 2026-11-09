class DailyStepCounterState {
  const DailyStepCounterState({
    required this.date,
    required this.initialCounter,
    required this.currentCounter,
    this.manualSteps = 0,
    this.sensorInitialized = true,
  });

  final DateTime date;
  final double initialCounter;
  final double currentCounter;
  final int manualSteps;
  final bool sensorInitialized;

  int get sensorSteps {
    if (!sensorInitialized) return 0;
    final difference = currentCounter - initialCounter;
    return difference < 0 ? 0 : difference.floor();
  }

  int get stepsToday => sensorSteps + manualSteps;
}
