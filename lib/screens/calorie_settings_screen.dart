import 'package:flutter/material.dart';

import '../models/calorie_settings.dart';
import '../models/weight_entry.dart';
import '../models/weekly_calorie_review.dart';
import '../models/reminder_settings.dart';
import '../services/local_storage_service.dart';
import '../services/reminder_service.dart';
import '../utils/adaptive_calorie_engine.dart';
import '../utils/calorie_estimation.dart';
import '../utils/weekly_calorie_review.dart';

class CalorieSettingsScreen extends StatefulWidget {
  const CalorieSettingsScreen({required this.storage, super.key});

  final LocalStorageService storage;

  @override
  State<CalorieSettingsScreen> createState() => _CalorieSettingsScreenState();
}

class _CalorieSettingsScreenState extends State<CalorieSettingsScreen> {
  final _currentCalories = TextEditingController();
  final _targetWeight = TextEditingController();
  final _weeklyChange = TextEditingController();
  final _minimumCalories = TextEditingController();
  final _maximumCalories = TextEditingController();
  final _age = TextEditingController();
  CalorieSettings _settings = CalorieSettings.defaults;
  List<WeightEntry> _weights = [];
  AdaptiveCalorieResult? _result;
  WeeklyCalorieReview? _weeklyReview;
  ReminderSettings _reminder = ReminderSettings.defaults;
  String? _sex;
  String? _activityLevel;
  double? _height;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final settings = await widget.storage.loadCalorieSettings();
    final weights = await widget.storage.loadWeights()
      ..sort((a, b) => b.date.compareTo(a.date));
    final savedReview = await widget.storage.loadWeeklyCalorieReview();
    final reminder = await widget.storage.loadReminderSettings();
    final height = widget.storage.loadHeight();
    _setControllers(settings);
    if (!mounted) return;
    setState(() {
      _settings = settings;
      _weights = weights;
      _weeklyReview = savedReview;
      _reminder = reminder;
      _height = height;
      _sex = settings.sex;
      _activityLevel = settings.activityLevel;
      _loading = false;
    });
    await _prepareWeeklyReview(settings, weights, savedReview);
  }

  Future<void> _prepareWeeklyReview(
    CalorieSettings settings,
    List<WeightEntry> weights,
    WeeklyCalorieReview? savedReview,
  ) async {
    final proposal = WeeklyCalorieReviews.createProposal(
      entries: weights,
      settings: settings,
    );
    if (proposal == null ||
        !WeeklyCalorieReviews.isNewWeek(
          latestWeek: proposal.weekStart,
          reviewedWeek: savedReview?.weekStart,
        )) {
      return;
    }
    final review = WeeklyCalorieReview(
      weekStart: proposal.weekStart,
      reviewedAt: DateTime.now(),
      proposedCalories: proposal.result.newCalories,
      status: WeeklyReviewStatus.pending,
    );
    await widget.storage.saveWeeklyCalorieReview(review);
    if (mounted) setState(() => _weeklyReview = review);
  }

  void _setControllers(CalorieSettings settings) {
    _currentCalories.text = _format(settings.currentCalories);
    _targetWeight.text = _format(settings.targetWeight);
    _weeklyChange.text = _format(settings.desiredWeeklyChange);
    _minimumCalories.text = _format(settings.minimumCalories);
    _maximumCalories.text = _format(settings.maximumCalories);
    _age.text = settings.age?.toString() ?? '';
    _sex = settings.sex;
    _activityLevel = settings.activityLevel;
  }

  double? _number(TextEditingController controller) =>
      double.tryParse(controller.text.trim().replaceAll(',', '.'));

  CalorieSettings? _readSettings() {
    final values = [
      _number(_currentCalories),
      _number(_targetWeight),
      _number(_weeklyChange),
      _number(_minimumCalories),
      _number(_maximumCalories),
    ];
    if (values.any((value) => value == null) ||
        values[0]! <= 0 ||
        values[1]! <= 0 ||
        values[3]! <= 0 ||
        values[4]! < values[3]!) {
      return null;
    }
    return CalorieSettings(
      currentCalories: values[0]!,
      targetWeight: values[1]!,
      desiredWeeklyChange: values[2]!,
      minimumCalories: values[3]!,
      maximumCalories: values[4]!,
      age: int.tryParse(_age.text.trim()),
      sex: _sex,
      activityLevel: _activityLevel,
    );
  }

  Future<void> _saveSettings() async {
    final settings = _readSettings();
    if (settings == null) return;
    await widget.storage.saveCalorieSettings(settings);
    if (mounted) {
      setState(() {
        _settings = settings;
        _result = null;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Configuración guardada')));
    }
  }

  void _calculate() {
    final settings = _readSettings();
    if (settings == null) return;
    try {
      final result = AdaptiveCalorieEngine.calculate(
        entries: _weights,
        targetWeight: settings.targetWeight,
        desiredWeeklyChange: settings.desiredWeeklyChange,
        currentCalories: settings.currentCalories,
        minimumCalories: settings.minimumCalories,
        maximumCalories: settings.maximumCalories,
      );
      setState(() => _result = result);
    } on ArgumentError {
      setState(() => _result = null);
    }
  }

  Future<void> _applyResult() async {
    final result = _result;
    if (result == null || result.trend == WeightTrend.insufficientData) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Aplicar nuevo objetivo'),
        content: Text(
          'Guardar ${_format(result.newCalories)} kcal/día como nuevo objetivo?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Aplicar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final updated = _settings.copyWith(currentCalories: result.newCalories);
    await widget.storage.saveCalorieSettings(updated);
    if (mounted) {
      _setControllers(updated);
      setState(() {
        _settings = updated;
        _result = null;
      });
    }
  }

  Future<void> _applyWeeklyReview() async {
    final review = _weeklyReview;
    if (review == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Aplicar revisión semanal'),
        content: Text(
          'Guardar ${_format(review.proposedCalories)} kcal/día como objetivo?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Aplicar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final updated = _settings.copyWith(
      currentCalories: review.proposedCalories,
    );
    await widget.storage.saveCalorieSettings(updated);
    await widget.storage.saveWeeklyCalorieReview(
      review.copyWith(status: WeeklyReviewStatus.applied),
    );
    if (mounted) {
      _setControllers(updated);
      setState(() {
        _settings = updated;
        _weeklyReview = review.copyWith(status: WeeklyReviewStatus.applied);
      });
    }
  }

  Future<void> _dismissWeeklyReview() async {
    final review = _weeklyReview;
    if (review == null) return;
    final dismissed = review.copyWith(status: WeeklyReviewStatus.dismissed);
    await widget.storage.saveWeeklyCalorieReview(dismissed);
    if (mounted) setState(() => _weeklyReview = dismissed);
  }

  Future<bool> _enableReminder(ReminderSettings updated) async {
    final granted = await ReminderService.instance.requestPermission();
    if (!granted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Permiso de notificaciones rechazado. Actívalo en Ajustes de Android.',
            ),
          ),
        );
      }
      return false;
    }
    final scheduled = await ReminderService.instance.schedule(updated);
    if (!scheduled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Android no confirmó la programación del recordatorio.',
            ),
          ),
        );
      }
      return false;
    }
    await widget.storage.saveReminderSettings(updated);
    if (!mounted) return true;
    setState(() => _reminder = updated);
    final now = TimeOfDay.now();
    final isTomorrow =
        updated.hour < now.hour ||
        (updated.hour == now.hour && updated.minute <= now.minute);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Recordatorio diario programado a '
          '${updated.hour.toString().padLeft(2, '0')}:'
          '${updated.minute.toString().padLeft(2, '0')}'
          '${isTomorrow ? ' mañana' : ' hoy'}.',
        ),
      ),
    );
    return true;
  }

  Future<void> _disableReminder() async {
    final updated = _reminder.copyWith(enabled: false);
    await widget.storage.saveReminderSettings(updated);
    await ReminderService.instance.schedule(updated);
    if (mounted) {
      setState(() => _reminder = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recordatorio desactivado.')),
      );
    }
  }

  Future<void> _testReminder() async {
    final granted = await ReminderService.instance.requestPermission();
    if (!granted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permiso de notificaciones rechazado.')),
        );
      }
      return;
    }
    final scheduled = await ReminderService.instance.scheduleTestNotification();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            scheduled
                ? 'Prueba programada: aparecerá en aproximadamente 1 minuto.'
                : 'Android no confirmó la prueba de notificación.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Objetivo calórico')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  'Objetivo actual: ${_format(_settings.currentCalories)} kcal/día',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text('Peso objetivo: ${_format(_settings.targetWeight)} kg'),
                Text(
                  'Ritmo deseado: ${_format(_settings.desiredWeeklyChange)} kg/semana',
                ),
                const SizedBox(height: 24),
                _field(_currentCalories, 'Calorías actuales (kcal/día)'),
                _field(_targetWeight, 'Peso objetivo (kg)'),
                _field(_weeklyChange, 'Cambio deseado (kg/semana)'),
                _field(_minimumCalories, 'Mínimo de calorías'),
                _field(_maximumCalories, 'Máximo de calorías'),
                _field(_age, 'Edad'),
                DropdownButtonFormField<String>(
                  initialValue: _sex,
                  decoration: const InputDecoration(labelText: 'Sexo'),
                  items: const [
                    DropdownMenuItem(value: 'male', child: Text('Hombre')),
                    DropdownMenuItem(value: 'female', child: Text('Mujer')),
                  ],
                  onChanged: (value) => setState(() => _sex = value),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _activityLevel,
                  decoration: const InputDecoration(
                    labelText: 'Nivel de actividad',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'sedentary',
                      child: Text('Sedentario'),
                    ),
                    DropdownMenuItem(
                      value: 'light',
                      child: Text('Ligero (1-3 días/semana)'),
                    ),
                    DropdownMenuItem(
                      value: 'moderate',
                      child: Text('Moderado (3-5 días/semana)'),
                    ),
                    DropdownMenuItem(
                      value: 'high',
                      child: Text('Alto (6-7 días/semana)'),
                    ),
                  ],
                  onChanged: (value) => setState(() => _activityLevel = value),
                ),
                const SizedBox(height: 8),
                _estimationCard(),
                FilledButton(
                  onPressed: _saveSettings,
                  child: const Text('Guardar configuración'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: _calculate,
                  child: const Text('Calcular siguiente objetivo'),
                ),
                const SizedBox(height: 24),
                _weeklyReviewSection(),
                const SizedBox(height: 16),
                _reminderSection(),
                if (_result != null) ...[
                  const SizedBox(height: 20),
                  _resultCard(_result!),
                ],
              ],
            ),
    );
  }

  Widget _estimationCard() {
    final weight = _weights.isEmpty ? null : _weights.first.weight;
    final estimate = weight == null || _height == null
        ? null
        : CalorieEstimation.estimate(
            settings: _settings.copyWith(
              age: int.tryParse(_age.text.trim()),
              sex: _sex,
              activityLevel: _activityLevel,
            ),
            weightKg: weight,
            heightCm: _height!,
          );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Estimación inicial',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              estimate == null
                  ? 'Completa edad, sexo, actividad, altura y peso para estimar tu mantenimiento.'
                  : 'Mantenimiento estimado: ${_format(estimate)} kcal/día',
            ),
            if (estimate != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () =>
                      setState(() => _currentCalories.text = _format(estimate)),
                  child: const Text('Usar como objetivo actual'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _weeklyReviewSection() {
    final review = _weeklyReview;
    if (review == null) {
      return const Card(
        child: ListTile(
          title: Text('Revisión semanal'),
          subtitle: Text(
            'Aún no hay suficientes datos para realizar la revisión.',
          ),
        ),
      );
    }

    if (review.status != WeeklyReviewStatus.pending) {
      return const Card(
        child: ListTile(
          title: Text('Revisión semanal'),
          subtitle: Text('No hay una nueva revisión disponible.'),
        ),
      );
    }

    final proposal = WeeklyCalorieReviews.createProposal(
      entries: _weights,
      settings: _settings,
    );
    if (proposal == null) {
      return const Card(
        child: ListTile(
          title: Text('Revisión semanal'),
          subtitle: Text(
            'Aún no hay suficientes datos para realizar la revisión.',
          ),
        ),
      );
    }

    final result = proposal.result;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Revisión semanal',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              'Peso promedio anterior: '
              '${_format(result.previousWeeklyAverage!)} kg',
            ),
            Text(
              'Peso promedio actual: '
              '${_format(result.currentWeeklyAverage!)} kg',
            ),
            Text('Cambio: ${_format(result.weightChange!)} kg'),
            Text('Objetivo actual: ${_format(result.currentCalories)} kcal'),
            Text(
              'Ajuste sugerido: '
              '${result.recommendedAdjustment >= 0 ? '+' : ''}'
              '${_format(result.recommendedAdjustment)} kcal',
            ),
            Text(
              'Nuevo objetivo sugerido: ${_format(result.newCalories)} kcal',
            ),
            Row(
              children: [
                FilledButton(
                  onPressed: _applyWeeklyReview,
                  child: const Text('Aplicar'),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: _dismissWeeklyReview,
                  child: const Text('Descartar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _reminderSection() {
    final time =
        '${_reminder.hour.toString().padLeft(2, '0')}:'
        '${_reminder.minute.toString().padLeft(2, '0')}';
    return Card(
      child: Column(
        children: [
          ListTile(
            title: const Text('Recordarme registrar mi día'),
            subtitle: Text(_reminder.enabled ? time : 'Desactivado'),
            trailing: Switch(
              value: _reminder.enabled,
              onChanged: (enabled) async {
                if (enabled) {
                  await _enableReminder(_reminder.copyWith(enabled: true));
                } else {
                  await _disableReminder();
                }
              },
            ),
            onTap: () async {
              final selected = await showTimePicker(
                context: context,
                initialTime: TimeOfDay(
                  hour: _reminder.hour,
                  minute: _reminder.minute,
                ),
              );
              if (selected == null) return;
              await _enableReminder(
                _reminder.copyWith(
                  enabled: true,
                  hour: selected.hour,
                  minute: selected.minute,
                ),
              );
            },
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: OutlinedButton.icon(
                onPressed: _testReminder,
                icon: const Icon(Icons.notifications_outlined),
                label: const Text('Probar notificación en 1 minuto'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController controller, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: label),
      ),
    );
  }

  Widget _resultCard(AdaptiveCalorieResult result) {
    if (result.trend == WeightTrend.insufficientData) {
      return const Card(
        child: ListTile(
          title: Text('Datos insuficientes para calcular un nuevo objetivo.'),
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Peso promedio anterior: ${_format(result.previousWeeklyAverage!)} kg',
            ),
            Text(
              'Peso promedio actual: ${_format(result.currentWeeklyAverage!)} kg',
            ),
            Text('Tendencia: ${_trendLabel(result.trend)}'),
            const SizedBox(height: 8),
            Text('Objetivo actual: ${_format(result.currentCalories)} kcal'),
            Text(
              'Ajuste recomendado: ${result.recommendedAdjustment >= 0 ? '+' : ''}'
              '${_format(result.recommendedAdjustment)} kcal',
            ),
            Text('Siguiente objetivo: ${_format(result.newCalories)} kcal'),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _applyResult,
              child: const Text('Aplicar nuevo objetivo'),
            ),
          ],
        ),
      ),
    );
  }

  String _trendLabel(WeightTrend trend) => switch (trend) {
    WeightTrend.losing => 'perdiendo',
    WeightTrend.stable => 'estable',
    WeightTrend.gaining => 'ganando',
    WeightTrend.insufficientData => 'datos insuficientes',
  };

  String _format(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');

  @override
  void dispose() {
    for (final controller in [
      _currentCalories,
      _targetWeight,
      _weeklyChange,
      _minimumCalories,
      _maximumCalories,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }
}
