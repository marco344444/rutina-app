import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/weight_entry.dart';
import '../services/local_storage_service.dart';
import '../models/calorie_settings.dart';
import '../utils/weekly_activity.dart';

class WeightScreen extends StatefulWidget {
  const WeightScreen({required this.storage, super.key});
  final LocalStorageService storage;

  @override
  State<WeightScreen> createState() => _WeightScreenState();
}

class _WeightScreenState extends State<WeightScreen> {
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  List<WeightEntry> _entries = [];
  double? _height;
  bool _loading = true;
  CalorieSettings _calorieSettings = CalorieSettings.defaults;
  WeeklyActivitySummary? _activity;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final entries = await widget.storage.loadWeights();
    final height = widget.storage.loadHeight();
    final calorieSettings = await widget.storage.loadCalorieSettings();
    final activity = WeeklyActivity.summarize(
      history: await widget.storage.loadTaskHistory(),
    );
    if (!mounted) return;
    setState(() {
      _entries = entries..sort((a, b) => b.date.compareTo(a.date));
      _height = height;
      _calorieSettings = calorieSettings;
      _activity = activity;
      _heightController.text = height?.toString() ?? '';
      _loading = false;
    });
  }

  Future<void> _saveWeight() async {
    final value = double.tryParse(_weightController.text.replaceAll(',', '.'));
    if (value == null || value <= 0) return;
    final entries = [
      ..._entries.where(
        (entry) => !DateUtils.isSameDay(entry.date, DateTime.now()),
      ),
      WeightEntry(date: DateTime.now(), weight: value),
    ]..sort((a, b) => b.date.compareTo(a.date));
    await widget.storage.saveWeights(entries);
    _weightController.clear();
    if (mounted) setState(() => _entries = entries);
  }

  Future<void> _saveHeight() async {
    final value = double.tryParse(_heightController.text.replaceAll(',', '.'));
    if (value == null || value <= 0) return;
    await widget.storage.saveHeight(value);
    if (mounted) setState(() => _height = value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Peso y altura')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  'Datos personales',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _heightController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Altura (cm)',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _saveHeight(),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton(
                    onPressed: _saveHeight,
                    child: const Text('Guardar altura'),
                  ),
                ),
                if (_height != null)
                  Text('Altura guardada: ${_height!.toStringAsFixed(0)} cm'),
                const SizedBox(height: 28),
                Text(
                  'Registrar peso',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _weightController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Peso (kg)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: _saveWeight,
                  child: const Text('Guardar peso de hoy'),
                ),
                const SizedBox(height: 20),
                _calorieSummary(),
                const SizedBox(height: 20),
                ..._entries.map(
                  (entry) => ListTile(
                    leading: const Icon(Icons.monitor_weight_outlined),
                    title: Text('${entry.weight.toStringAsFixed(1)} kg'),
                    subtitle: Text(
                      DateFormat('d MMM yyyy', 'es').format(entry.date),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _calorieSummary() {
    final activity = _activity;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Objetivo calórico configurado',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              '${_calorieSettings.currentCalories.toStringAsFixed(0)} kcal/día',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 4),
            Text(
              'Este valor es configurable y todavía no es una estimación '
              'personalizada.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (activity != null) ...[
              const SizedBox(height: 8),
              Text('Actividad semana anterior'),
              Text('Entrenamiento: ${activity.trainingDays}/7 días'),
              Text('10.000 pasos: ${activity.stepsDays}/7 días'),
            ],
            if (_entries.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Peso promedio: ${_entries.first.weight.toStringAsFixed(1)} kg',
              ),
            ],
            const SizedBox(height: 8),
            const Text('Próxima actualización: Domingo'),
          ],
        ),
      ),
    );
  }
}
