import 'package:flutter/services.dart';

import '../models/daily_step_counter_state.dart';
import 'local_storage_service.dart';

class StepCounterResult {
  const StepCounterResult({
    required this.status,
    this.steps,
    this.sensorSteps,
    this.manualSteps,
    this.message,
  });

  final NativeStepCounterStatus status;
  final int? steps;
  final int? sensorSteps;
  final int? manualSteps;
  final String? message;
}

enum NativeStepCounterStatus {
  connected,
  permissionRequired,
  sensorUnavailable,
  error,
  manualOnly,
}

class NativeStepCounterService {
  NativeStepCounterService({
    required this._storage,
    MethodChannel? channel,
    EventChannel? eventChannel,
  }) : _channel = channel ?? const MethodChannel('routine_app/step_counter'),
       _eventChannel =
           eventChannel ??
           const EventChannel('routine_app/step_counter_events');

  final LocalStorageService _storage;
  final MethodChannel _channel;
  final EventChannel _eventChannel;

  Future<void> _lastSensorRead = Future.value();

  /// Serializa las lecturas del sensor para evitar invocaciones concurrentes
  /// que el nativo rechaza con SENSOR_BUSY al apagar/reanudar la app.
  Future<T> _serialize<T>(Future<T> Function() action) {
    final run = _lastSensorRead.then((_) => action());
    _lastSensorRead = run.then<void>((_) {}, onError: (_) {});
    return run;
  }

  Future<StepCounterResult> getTodaySteps({
    bool requestPermission = false,
  }) {
    return _serialize(() => _readSensor(requestPermission: requestPermission));
  }

  Future<StepCounterResult> _readSensor({
    bool requestPermission = false,
  }) async {
    try {
      final available =
          await _channel.invokeMethod<bool>('hasStepCounter') ?? false;
      if (!available) {
        return await _persistedResult(
          NativeStepCounterStatus.sensorUnavailable,
          'Este dispositivo no tiene sensor de pasos.',
        );
      }

      var granted =
          await _channel.invokeMethod<bool>('hasActivityRecognition') ?? false;
      if (!granted && requestPermission) {
        await _channel.invokeMethod<bool>('requestActivityRecognition');
        granted =
            await _channel.invokeMethod<bool>('hasActivityRecognition') ??
            false;
      }
      if (!granted) {
        return await _persistedResult(
          NativeStepCounterStatus.permissionRequired,
          'Se necesita permiso de actividad física.',
        );
      }

      final counter = (await _channel.invokeMethod<num>('getStepCounter'))
          ?.toDouble();
      if (counter == null) {
        return await _persistedResult(
          NativeStepCounterStatus.error,
          'No se pudo obtener el contador del sensor.',
        );
      }

      return await _saveCounter(counter);
    } on PlatformException catch (error) {
      return _persistedResult(
        NativeStepCounterStatus.error,
        error.message ?? error.code,
      );
    }
  }

  /// Total persistido de hoy sin tocar el sensor: la pantalla lo muestra
  /// mientras el sensor se reconecta, para que nunca caiga a cero por un
  /// fallo temporal de lectura.
  Future<StepCounterResult> readPersistedToday() {
    return _persistedResult(
      NativeStepCounterStatus.manualOnly,
      'Se cargó el último contador guardado.',
    );
  }

  Future<StepCounterResult> addManualSteps(int steps) async {
    if (steps <= 0) {
      throw ArgumentError.value(steps, 'steps', 'Debe ser mayor que cero');
    }

    final state = await _storage.loadDailyStepCounterState();
    final today = DateTime.now();
    final date = DateTime(today.year, today.month, today.day);
    final updated = DailyStepCounterState(
      date: state != null && _dateOnly(state.date) == date ? state.date : date,
      initialCounter: state != null && _dateOnly(state.date) == date
          ? state.initialCounter
          : 0,
      currentCounter: state != null && _dateOnly(state.date) == date
          ? state.currentCounter
          : 0,
      manualSteps: state != null && _dateOnly(state.date) == date
          ? state.manualSteps + steps
          : steps,
      sensorInitialized:
          state != null &&
          _dateOnly(state.date) == date &&
          state.sensorInitialized,
    );
    await _storage.saveDailyStepCounterState(updated);
    return StepCounterResult(
      status: NativeStepCounterStatus.manualOnly,
      steps: updated.stepsToday,
      sensorSteps: updated.sensorSteps,
      manualSteps: updated.manualSteps,
      message: 'Pasos manuales añadidos.',
    );
  }

  Future<StepCounterResult> _persistedResult(
    NativeStepCounterStatus status,
    String message,
  ) async {
    final state = await _storage.loadDailyStepCounterState();
    final today = DateTime.now();
    final date = DateTime(today.year, today.month, today.day);
    final current = state != null && _dateOnly(state.date) == date
        ? state
        : null;
    return StepCounterResult(
      status: status,
      steps: current?.stepsToday ?? 0,
      sensorSteps: current?.sensorSteps ?? 0,
      manualSteps: current?.manualSteps ?? 0,
      message: message,
    );
  }

  Stream<StepCounterResult> watchTodaySteps({
    bool requestPermission = false,
  }) async* {
    final initial = await getTodaySteps(requestPermission: requestPermission);
    yield initial;
    if (initial.status == NativeStepCounterStatus.permissionRequired ||
        initial.status == NativeStepCounterStatus.sensorUnavailable) {
      return;
    }
    // Un fallo transitorio (error) no detiene el listener: el siguiente
    // evento del sensor reconecta solo sin recrear ni duplicar listeners.
    await for (final value in _eventChannel.receiveBroadcastStream()) {
      yield await _saveCounter((value as num).toDouble());
    }
  }

  Future<StepCounterResult> _saveCounter(double counter) async {
    final today = DateTime.now();
    final date = DateTime(today.year, today.month, today.day);
    final previous = await _storage.loadDailyStepCounterState();
    final sameDay = previous != null && _dateOnly(previous.date) == date;

    if (!sameDay) {
      // Día nuevo real: se reinicia solo el estado del día actual.
      final state = DailyStepCounterState(
        date: date,
        initialCounter: counter,
        currentCounter: counter,
        manualSteps: 0,
        sensorInitialized: true,
      );
      await _storage.saveDailyStepCounterState(state);
      return _connectedResult(state);
    }

    if (!previous.sensorInitialized || counter < previous.currentCounter) {
      // Lectura degradada (apagado/reinicio del dispositivo o contador
      // reiniciado): se conserva el último estado válido en vez de que un
      // cero o un valor menor sobrescriban los pasos reales del día.
      return _connectedResult(
        previous,
        message: 'Se mantiene el último valor válido del sensor.',
      );
    }

    final state = DailyStepCounterState(
      date: date,
      initialCounter: previous.initialCounter,
      currentCounter: counter,
      manualSteps: previous.manualSteps,
      sensorInitialized: true,
    );
    await _storage.saveDailyStepCounterState(state);
    return _connectedResult(state);
  }

  StepCounterResult _connectedResult(
    DailyStepCounterState state, {
    String message = 'Sensor de pasos conectado.',
  }) {
    return StepCounterResult(
      status: NativeStepCounterStatus.connected,
      steps: state.stepsToday,
      sensorSteps: state.sensorSteps,
      manualSteps: state.manualSteps,
      message: message,
    );
  }

  DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);
}
