import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../models/task.dart';
import '../services/local_storage_service.dart';
import '../utils/progress_aggregation.dart';
import 'journal_screen.dart';
import 'shopping_screen.dart';
import 'weight_screen.dart';
import 'calorie_settings_screen.dart';
import '../utils/automatic_calorie_review.dart';
import '../services/native_step_counter_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({required this.storage, super.key});
  final LocalStorageService storage;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  static const _defaultHabits = [
    Task(id: 'training', title: 'Entrenamiento'),
    Task(id: 'steps', title: '10.000 pasos', target: 10000),
    Task(id: 'kovaaks', title: 'Kovaaks'),
    Task(id: 'journal', title: 'Diario'),
    Task(id: 'sleep', title: 'Dormir 7+ horas'),
  ];

  int _selectedIndex = 0;
  ProgressPeriod _period = ProgressPeriod.week;
  late String _dayKey;
  List<Task> _habits = [];
  List<Task> _todayTasks = [];
  Map<String, List<Task>> _history = {};
  bool _loading = true;
  int? _stepsToday;
  late final NativeStepCounterService _nativeSteps;
  int? _nativeStepsToday;
  int _manualStepsToday = 0;
  NativeStepCounterStatus? _nativeStepsStatus;
  String? _nativeStepsMessage;
  StreamSubscription<StepCounterResult>? _nativeStepsSubscription;
  Timer? _clockTimer;
  int _greetingPeriod = -1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _dayKey = _key(DateTime.now());
    _nativeSteps = NativeStepCounterService(storage: widget.storage);
    _clockTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _checkClock(),
    );
    _load(requestPermission: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _nativeStepsSubscription?.cancel();
    _clockTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkClock();
      if (_key(DateTime.now()) == _dayKey) {
        _syncNativeSteps();
        // Si el listener murió por un error transitorio, se recrea uno solo
        // (nunca se apilan listeners duplicados).
        if (_nativeStepsSubscription == null) {
          _setupNativeStepsListener();
        }
      }
    }
  }

  void _checkClock() {
    if (!mounted) return;
    final now = DateTime.now();
    final currentDay = _key(now);
    if (currentDay != _dayKey) {
      _dayKey = currentDay;
      _load(requestPermission: false);
    }
    final period = now.hour < 12
        ? 0
        : now.hour < 18
        ? 1
        : 2;
    if (period != _greetingPeriod) {
      setState(() => _greetingPeriod = period);
    }
  }

  String _key(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

  Future<void> _load({bool requestPermission = false}) async {
    var habits = await widget.storage.loadHabits();
    if (!widget.storage.hasSavedHabits) {
      habits = List.of(_defaultHabits);
      await widget.storage.saveHabits(habits);
    }
    habits = habits
        .map(
          (habit) => habit.id == 'steps' && !habit.isQuantitative
              ? habit.copyWith(target: 10000)
              : habit,
        )
        .toList();
    await widget.storage.saveHabits(habits);
    var today = await widget.storage.loadTasks(_dayKey);
    today = _mergeHabits(habits, today);
    // Muestra primero el último total válido persistido mientras el sensor
    // se reconecta: un fallo temporal nunca deja la pantalla en cero.
    final persisted = await _nativeSteps.readPersistedToday();
    today = _applyNativeSteps(today, persisted);
    await widget.storage.saveTasks(_dayKey, today);
    final history = await widget.storage.loadTaskHistory();
    history[_dayKey] = today;
    await _processAutomaticCalorieReview(history);
    if (!mounted) return;
    setState(() {
      _habits = habits;
      _todayTasks = today;
      _history = history;
      _loading = false;
    });
    _setupNativeStepsListener(requestPermission: requestPermission);
  }

  Future<void> _syncNativeSteps({bool requestPermission = false}) async {
    final result = await _nativeSteps.getTodaySteps(
      requestPermission: requestPermission,
    );
    await _handleNativeSteps(result);
  }

  Future<void> _connectNativeSteps() async {
    await _syncNativeSteps(requestPermission: true);
    if (_nativeStepsSubscription == null) _setupNativeStepsListener();
  }

  void _setupNativeStepsListener({bool requestPermission = false}) {
    // Cancela el listener previo antes de crear el nuevo: garantiza que
    // nunca haya dos suscripciones al EventChannel a la vez.
    _nativeStepsSubscription?.cancel();
    _nativeStepsSubscription = _nativeSteps
        .watchTodaySteps(requestPermission: requestPermission)
        .listen(
          _handleNativeSteps,
          onError: (Object _) {
            _nativeStepsSubscription?.cancel();
            _nativeStepsSubscription = null;
          },
          onDone: () {
            _nativeStepsSubscription = null;
          },
        );
  }

  Future<void> _addManualSteps() async {
    final controller = TextEditingController();
    final value = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Añadir pasos'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Cantidad'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, int.tryParse(controller.text.trim())),
            child: const Text('Añadir'),
          ),
        ],
      ),
    );
    Future<void>.delayed(const Duration(milliseconds: 300), controller.dispose);
    if (value == null || value <= 0) return;
    try {
      final result = await _nativeSteps.addManualSteps(value);
      await _handleNativeSteps(result);
      if (result.status != NativeStepCounterStatus.connected &&
          mounted &&
          result.message != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(result.message!)));
      }
    } on ArgumentError {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Introduce una cantidad válida.')),
        );
      }
    }
  }

  List<Task> _applyNativeSteps(List<Task> tasks, StepCounterResult result) {
    // Solo se actualiza el total con valores no nulos: un error temporal
    // (null, cero o sensorUnavailable) nunca sobrescribe pasos válidos.
    if (result.steps != null) {
      _stepsToday = result.steps;
      _manualStepsToday = result.manualSteps ?? _manualStepsToday;
    }
    if (result.status != NativeStepCounterStatus.connected &&
            result.status != NativeStepCounterStatus.manualOnly ||
        result.steps == null) {
      return tasks;
    }
    return tasks
        .map(
          (task) => task.id == 'steps'
              ? task.copyWith(
                  completed: result.steps! >= (task.target ?? 10000),
                  value: result.steps!.toDouble(),
                )
              : task,
        )
        .toList();
  }

  Future<void> _handleNativeSteps(StepCounterResult result) async {
    final synced = _applyNativeSteps(_todayTasks, result);
    _nativeStepsToday = result.steps;
    _nativeStepsStatus = result.status;
    _nativeStepsMessage = result.message;
    if (result.status == NativeStepCounterStatus.connected ||
        result.status == NativeStepCounterStatus.manualOnly) {
      await widget.storage.saveTasks(_dayKey, synced);
    }
    if (!mounted) return;
    setState(() {
      _todayTasks = synced;
      _history[_dayKey] = synced;
    });
  }

  Future<void> _processAutomaticCalorieReview(
    Map<String, List<Task>> activityHistory,
  ) async {
    final settings = await widget.storage.loadCalorieSettings();
    final weights = await widget.storage.loadWeights();
    final processed = await widget.storage.loadWeeklyCalorieHistory();
    final automatic = AutomaticCalorieReviews.process(
      settings: settings,
      weights: weights,
      activityHistory: activityHistory,
      processedHistory: processed,
    );
    if (automatic == null || automatic.history == null) return;
    await widget.storage.saveCalorieSettings(automatic.settings);
    await widget.storage.saveWeeklyCalorieHistory([
      ...processed,
      automatic.history!,
    ]);
  }

  List<Task> _mergeHabits(List<Task> habits, List<Task> saved) {
    return habits
        .map(
          (habit) =>
              saved
                  .where((task) => task.id == habit.id)
                  .firstOrNull
                  ?.copyWith(target: habit.target) ??
              habit,
        )
        .toList();
  }

  Future<void> _toggleTask(Task task) async {
    final updated = _todayTasks
        .map(
          (item) => item.id == task.id
              ? item.copyWith(completed: !item.completed)
              : item,
        )
        .toList();
    await widget.storage.saveTasks(_dayKey, updated);
    if (mounted) {
      setState(() {
        _todayTasks = updated;
        _history[_dayKey] = updated;
      });
    }
  }

  Future<void> _addHabit() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nuevo hábito'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'Ej. Leer 20 minutos'),
          onSubmitted: (_) => Navigator.pop(context, controller.text.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Crear'),
          ),
        ],
      ),
    );
    final title = name?.trim();
    if (title == null || title.isEmpty) return;
    final habit = Task(
      id: '${DateTime.now().microsecondsSinceEpoch}',
      title: title,
    );
    final habits = [..._habits, habit];
    await widget.storage.saveHabits(habits);
    final today = [..._todayTasks, habit];
    await widget.storage.saveTasks(_dayKey, today);
    if (mounted) {
      setState(() {
        _habits = habits;
        _todayTasks = today;
        _history[_dayKey] = today;
      });
    }
  }

  Future<void> _deleteHabit(Task habit) async {
    final habits = _habits.where((item) => item.id != habit.id).toList();
    final today = _todayTasks.where((item) => item.id != habit.id).toList();
    await widget.storage.saveHabits(habits);
    await widget.storage.saveTasks(_dayKey, today);
    if (mounted) {
      setState(() {
        _habits = habits;
        _todayTasks = today;
        _history[_dayKey] = today;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _buildHome(),
      WeightScreen(storage: widget.storage),
      JournalScreen(storage: widget.storage),
      ShoppingScreen(storage: widget.storage),
    ];
    return Scaffold(
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : pages[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) =>
            setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(Icons.monitor_weight_outlined),
            label: 'Peso',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            label: 'Diario',
          ),
          NavigationDestination(
            icon: Icon(Icons.shopping_cart_outlined),
            label: 'Compras',
          ),
        ],
      ),
    );
  }

  Widget _buildHome() {
    final progress = _todayTasks.isEmpty
        ? 0.0
        : _todayTasks.fold<double>(0, (total, task) {
                if (task.id == 'steps' && task.isQuantitative) {
                  final current = (_stepsToday ?? 0).toDouble();
                  return total +
                      (current / (task.target ?? 10000)).clamp(0.0, 1.0);
                }
                return total + (task.completed ? 1 : 0);
              }) /
              _todayTasks.length;
    final dateLabel = DateFormat(
      'EEEE d MMM',
      'es',
    ).format(DateTime.now()).toUpperCase();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rutina'),
        actions: [
          IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CalorieSettingsScreen(storage: widget.storage),
              ),
            ),
            icon: const Icon(Icons.local_fire_department_outlined),
            tooltip: 'Objetivo calórico',
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.notifications_none_rounded),
            tooltip: 'Recordatorios',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Text(dateLabel, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Text(
            '${_greeting()} 👋',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 20),
          _nativeStepsCard(),
          const SizedBox(height: 14),
          _SectionCard(
            title: 'PROGRESO',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${(progress * 100).round()}%',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 10),
                LinearProgressIndicator(value: progress, minHeight: 9),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _SectionCard(
            title: 'CUMPLIMIENTO',
            child: Column(
              children: [
                SegmentedButton<ProgressPeriod>(
                  segments: const [
                    ButtonSegment(
                      value: ProgressPeriod.week,
                      label: Text('Sem'),
                    ),
                    ButtonSegment(
                      value: ProgressPeriod.month,
                      label: Text('Mes'),
                    ),
                    ButtonSegment(
                      value: ProgressPeriod.quarter,
                      label: Text('Trim'),
                    ),
                    ButtonSegment(
                      value: ProgressPeriod.year,
                      label: Text('Año'),
                    ),
                  ],
                  selected: {_period},
                  onSelectionChanged: (value) =>
                      setState(() => _period = value.first),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 170,
                  child: _ProgressChart(history: _history, period: _period),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _SectionCard(
            title: 'CHECKLIST DEL DÍA',
            trailing: IconButton(
              onPressed: _addHabit,
              icon: const Icon(Icons.add),
              tooltip: 'Crear hábito',
            ),
            child: Column(
              children: [
                ..._todayTasks.map(
                  (task) => Dismissible(
                    key: ValueKey(task.id),
                    direction: DismissDirection.endToStart,
                    confirmDismiss: (_) => _confirmDelete(task),
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 16),
                      color: Theme.of(context).colorScheme.errorContainer,
                      child: const Icon(Icons.delete_outline),
                    ),
                    child: task.isQuantitative
                        ? _quantitativeTaskTile(task)
                        : CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            value: task.completed,
                            title: Text(task.title),
                            controlAffinity: ListTileControlAffinity.leading,
                            onChanged: (_) => _toggleTask(task),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _nativeStepsCard() {
    final steps = _nativeStepsToday ?? 0;
    final progress = (steps / 10000).clamp(0.0, 1.0);
    final status = _nativeStepsStatus;
    return _SectionCard(
      title: 'PASOS DE HOY · SENSOR NATIVO',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$steps / 10.000',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(value: progress),
          const SizedBox(height: 6),
          Text('${(progress * 100).round()}%'),
          if (_manualStepsToday > 0)
            Text(
              'Sensor: ${steps - _manualStepsToday} · Manual: $_manualStepsToday',
            ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _canAddManualSteps(status) ? _addManualSteps : null,
            icon: const Icon(Icons.add),
            label: const Text('Añadir pasos'),
          ),
          const SizedBox(height: 8),
          Text('Estado: ${_nativeStatusLabel(status)}'),
          if (_nativeStepsMessage != null) Text(_nativeStepsMessage!),
          if (status == NativeStepCounterStatus.permissionRequired) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _connectNativeSteps,
              icon: const Icon(Icons.lock_open),
              label: const Text('Conceder permiso'),
            ),
          ],
        ],
      ),
    );
  }

  bool _canAddManualSteps(NativeStepCounterStatus? status) => !_loading;

  String _nativeStatusLabel(NativeStepCounterStatus? status) {
    switch (status) {
      case NativeStepCounterStatus.connected:
        return 'Sensor disponible · Permiso concedido';
      case NativeStepCounterStatus.permissionRequired:
        return 'Permiso requerido';
      case NativeStepCounterStatus.sensorUnavailable:
        return 'Sensor no disponible';
      case NativeStepCounterStatus.error:
        return 'Error';
      case NativeStepCounterStatus.manualOnly:
        return 'Solo pasos manuales';
      case null:
        return 'Sin comprobar';
    }
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Buenos días';
    if (hour < 18) return 'Buenas tardes';
    return 'Buenas noches';
  }

  Widget _quantitativeTaskTile(Task task) {
    final current = task.id == 'steps' ? (_stepsToday ?? 0) : 0;
    final target = task.target!;
    final progress = (current / target).clamp(0.0, 1.0);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        task.completed ? Icons.check_circle : Icons.directions_walk,
        color: task.completed
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      title: Text(task.title),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          LinearProgressIndicator(value: progress),
          const SizedBox(height: 4),
          Text(
            '${current.toStringAsFixed(0)} / ${target.toStringAsFixed(0)} '
            '(${(progress * 100).round()}%)',
          ),
        ],
      ),
    );
  }

  Future<bool> _confirmDelete(Task habit) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar hábito'),
        content: Text('¿Eliminar "${habit.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (result == true) await _deleteHabit(habit);
    return false;
  }
}

class _ProgressChart extends StatelessWidget {
  const _ProgressChart({required this.history, required this.period});
  final Map<String, List<Task>> history;
  final ProgressPeriod period;

  @override
  Widget build(BuildContext context) {
    final aggregates = ProgressAggregation.aggregate(
      history: history,
      period: period,
    );
    return CustomPaint(
      painter: _ProgressPainter(
        aggregates: aggregates,
        color: Theme.of(context).colorScheme.primary,
        trackColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        textColor: Theme.of(context).colorScheme.onSurfaceVariant,
        textDirection: Directionality.of(context),
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _ProgressPainter extends CustomPainter {
  const _ProgressPainter({
    required this.aggregates,
    required this.color,
    required this.trackColor,
    required this.textColor,
    required this.textDirection,
  });
  final List<ProgressAggregate> aggregates;
  final Color color;
  final Color trackColor;
  final Color textColor;
  final TextDirection textDirection;

  @override
  void paint(Canvas canvas, Size size) {
    final chartHeight = size.height - 24;
    final width = size.width / math.max(aggregates.length, 1);
    final paint = Paint()..color = color;
    final trackPaint = Paint()..color = trackColor;
    for (var i = 0; i < aggregates.length; i++) {
      final value = aggregates[i].value;
      final barHeight = value == null ? 0.0 : chartHeight * value;
      final left = i * width + width * .22;
      final rect = Rect.fromLTWH(
        left,
        chartHeight - barHeight,
        width * .56,
        barHeight,
      );
      if (value == null) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(left, chartHeight - 4, width * .56, 4),
            const Radius.circular(5),
          ),
          trackPaint,
        );
        continue;
      }
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(5)),
        paint,
      );
    }
    final textPainter = TextPainter(textDirection: textDirection);
    for (var i = 0; i < aggregates.length; i++) {
      final label = aggregates[i].label;
      textPainter.text = TextSpan(
        text: label,
        style: TextStyle(fontSize: 10, color: textColor),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(i * width + (width - textPainter.width) / 2, chartHeight + 6),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ProgressPainter oldDelegate) =>
      oldDelegate.aggregates != aggregates;
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child, this.trailing});
  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}
