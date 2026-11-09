import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:routine_app/models/daily_step_counter_state.dart';
import 'package:routine_app/models/task.dart';
import 'package:routine_app/services/local_storage_service.dart';
import 'package:routine_app/services/native_step_counter_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('calculates daily steps from the initial counter', () {
    final state = DailyStepCounterState(
      date: DateTime(2026, 9, 7),
      initialCounter: 100,
      currentCounter: 350,
    );
    expect(state.stepsToday, 250);
  });

  test('supports zero steps and increments', () {
    final initial = DailyStepCounterState(
      date: DateTime(2026, 9, 7),
      initialCounter: 100,
      currentCounter: 100,
    );
    final incremented = DailyStepCounterState(
      date: DateTime(2026, 9, 7),
      initialCounter: 100,
      currentCounter: 125,
    );
    expect(initial.stepsToday, 0);
    expect(incremented.stepsToday, 25);
  });

  test('adds manual steps without changing the sensor counter', () async {
    final today = DateTime.now();
    SharedPreferences.setMockInitialValues({
      'stepCounterDate': today.toIso8601String(),
      'stepCounterInitial': 1000.0,
      'stepCounterCurrent': 9700.0,
      'manualSteps': 0,
    });

    final storage = await LocalStorageService.create();
    final service = NativeStepCounterService(
      storage: storage,
      channel: const MethodChannel('test/manual_steps'),
    );

    final result = await service.addManualSteps(500);
    final saved = await storage.loadDailyStepCounterState();

    expect(result.status, NativeStepCounterStatus.manualOnly);
    expect(result.steps, 9200);
    expect(result.sensorSteps, 8700);
    expect(result.manualSteps, 500);
    expect(saved?.currentCounter, 9700);
    expect(saved?.manualSteps, 500);
  });

  test('sensor and manual steps can complete the 10000-step goal', () {
    final state = DailyStepCounterState(
      date: DateTime(2026, 9, 8),
      initialCounter: 1000,
      currentCounter: 9700,
      manualSteps: 300,
    );

    expect(state.sensorSteps, 8700);
    expect(state.stepsToday, 9000);
    expect(
      DailyStepCounterState(
        date: state.date,
        initialCounter: state.initialCounter,
        currentCounter: state.currentCounter,
        manualSteps: 1300,
      ).stepsToday,
      10000,
    );
  });

  test('manual steps reset when the persisted day changes', () async {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    SharedPreferences.setMockInitialValues({
      'stepCounterDate': yesterday.toIso8601String(),
      'stepCounterInitial': 1000.0,
      'stepCounterCurrent': 2000.0,
      'manualSteps': 500,
    });
    final storage = await LocalStorageService.create();
    final channel = const MethodChannel('test/manual_day_change');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          switch (call.method) {
            case 'hasStepCounter':
              return true;
            case 'hasActivityRecognition':
              return true;
            case 'getStepCounter':
              return 3000;
            default:
              return null;
          }
        });

    final result = await NativeStepCounterService(
      storage: storage,
      channel: channel,
    ).getTodaySteps();

    expect(result.steps, 0);
    expect(result.manualSteps, 0);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('prevents negative values after a device restart', () {
    final state = DailyStepCounterState(
      date: DateTime(2026, 9, 7),
      initialCounter: 500,
      currentCounter: 10,
    );
    expect(state.stepsToday, 0);
  });

  test('a new day starts from the current counter', () {
    final state = DailyStepCounterState(
      date: DateTime(2026, 9, 8),
      initialCounter: 900,
      currentCounter: 900,
    );
    expect(state.stepsToday, 0);
  });

  test('reports an absent sensor without hardware', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = await LocalStorageService.create();
    final channel = const MethodChannel('test/step_counter_absent');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'hasStepCounter') return false;
          return null;
        });

    final result = await NativeStepCounterService(
      storage: storage,
      channel: channel,
    ).getTodaySteps();

    expect(result.status, NativeStepCounterStatus.sensorUnavailable);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('reports denied activity permission without hardware', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = await LocalStorageService.create();
    final channel = const MethodChannel('test/step_counter_denied');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          switch (call.method) {
            case 'hasStepCounter':
              return true;
            case 'hasActivityRecognition':
              return false;
            default:
              return null;
          }
        });

    final result = await NativeStepCounterService(
      storage: storage,
      channel: channel,
    ).getTodaySteps();

    expect(result.status, NativeStepCounterStatus.permissionRequired);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('emits the initial native reading without a refresh action', () async {
    SharedPreferences.setMockInitialValues({
      'stepCounterDate': DateTime.now().toIso8601String(),
      'stepCounterInitial': 1000.0,
      'stepCounterCurrent': 1000.0,
    });
    final storage = await LocalStorageService.create();
    final channel = const MethodChannel('test/step_counter_stream');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          switch (call.method) {
            case 'hasStepCounter':
              return true;
            case 'hasActivityRecognition':
              return true;
            case 'getStepCounter':
              return 11000;
            default:
              return null;
          }
        });

    final result = await NativeStepCounterService(
      storage: storage,
      channel: channel,
    ).watchTodaySteps().first;

    expect(result.status, NativeStepCounterStatus.connected);
    expect(result.steps, 10000);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('temporary sensor error keeps the last persisted total', () async {
    final today = DateTime.now();
    SharedPreferences.setMockInitialValues({
      'stepCounterDate': today.toIso8601String(),
      'stepCounterInitial': 1000.0,
      'stepCounterCurrent': 9000.0,
      'manualSteps': 200,
      'stepSensorInitialized': true,
    });
    final storage = await LocalStorageService.create();
    final channel = const MethodChannel('test/sensor_error_keeps');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          switch (call.method) {
            case 'hasStepCounter':
              return true;
            case 'hasActivityRecognition':
              return true;
            case 'getStepCounter':
              throw PlatformException(
                code: 'SENSOR_ERROR',
                message: 'Lectura fallida tras apagar la pantalla.',
              );
            default:
              return null;
          }
        });

    final service = NativeStepCounterService(
      storage: storage,
      channel: channel,
    );
    final result = await service.getTodaySteps();
    final saved = await storage.loadDailyStepCounterState();

    expect(result.status, NativeStepCounterStatus.error);
    expect(result.steps, 8200); // 9000-1000 del sensor + 200 manuales.
    expect(result.sensorSteps, 8000);
    expect(result.manualSteps, 200);
    expect(saved?.currentCounter, 9000);
    expect(saved?.manualSteps, 200);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('a zero or regressed counter does not overwrite valid steps', () async {
    final today = DateTime.now();
    SharedPreferences.setMockInitialValues({
      'stepCounterDate': today.toIso8601String(),
      'stepCounterInitial': 1000.0,
      'stepCounterCurrent': 9000.0,
      'manualSteps': 0,
      'stepSensorInitialized': true,
    });
    final storage = await LocalStorageService.create();
    final channel = const MethodChannel('test/sensor_zero_keeps');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          switch (call.method) {
            case 'hasStepCounter':
              return true;
            case 'hasActivityRecognition':
              return true;
            case 'getStepCounter':
              return 0; // Contador reiniciado por el dispositivo.
            default:
              return null;
          }
        });

    final service = NativeStepCounterService(
      storage: storage,
      channel: channel,
    );
    final result = await service.getTodaySteps();
    final saved = await storage.loadDailyStepCounterState();

    expect(result.status, NativeStepCounterStatus.connected);
    expect(result.steps, 8000); // Se conserva el último total válido.
    expect(saved?.currentCounter, 9000);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('after a transient error a later reading resumes from persisted', () async {
    final today = DateTime.now();
    SharedPreferences.setMockInitialValues({
      'stepCounterDate': today.toIso8601String(),
      'stepCounterInitial': 1000.0,
      'stepCounterCurrent': 9000.0,
      'manualSteps': 200,
      'stepSensorInitialized': true,
    });
    final storage = await LocalStorageService.create();
    final channel = const MethodChannel('test/step_recovery');
    var fail = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          switch (call.method) {
            case 'hasStepCounter':
              return true;
            case 'hasActivityRecognition':
              return true;
            case 'getStepCounter':
              if (fail) {
                fail = false;
                throw PlatformException(code: 'SENSOR_BUSY');
              }
              return 9300;
            default:
              return null;
          }
        });

    final service = NativeStepCounterService(
      storage: storage,
      channel: channel,
    );
    final first = await service.getTodaySteps();
    final second = await service.getTodaySteps();

    expect(first.status, NativeStepCounterStatus.error);
    expect(first.steps, 8200);
    expect(second.status, NativeStepCounterStatus.connected);
    expect(second.steps, 8500); // 9300-1000 + 200 manuales.
    expect(second.manualSteps, 200);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('readPersistedToday returns the last valid values without sensor',
      () async {
    final today = DateTime.now();
    SharedPreferences.setMockInitialValues({
      'stepCounterDate': today.toIso8601String(),
      'stepCounterInitial': 500.0,
      'stepCounterCurrent': 7500.0,
      'manualSteps': 150,
      'stepSensorInitialized': true,
    });
    final storage = await LocalStorageService.create();
    final service = NativeStepCounterService(storage: storage);

    final result = await service.readPersistedToday();

    expect(result.status, NativeStepCounterStatus.manualOnly);
    expect(result.steps, 7150);
    expect(result.sensorSteps, 7000);
    expect(result.manualSteps, 150);
  });

  test('a new persisted day keeps the previous day history intact', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = await LocalStorageService.create();
    final yesterday = '2026-09-06';
    await storage.saveTasks(yesterday, [
      Task(
        id: 'steps',
        title: '10.000 pasos',
        target: 10000,
        value: 9200,
      ),
      const Task(id: 'training', title: 'Entrenamiento', completed: true),
    ]);

    final history = await storage.loadTaskHistory();

    expect(history[yesterday], hasLength(2));
    expect(history[yesterday]!.first.value, 9200);
    expect(history[yesterday]!.first.completed, isFalse);
    expect(history[yesterday]!.last.completed, isTrue);
  });
}
