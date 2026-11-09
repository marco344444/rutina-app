import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/journal_entry.dart';
import '../models/inventory_movement.dart';
import '../models/calorie_settings.dart';
import '../models/daily_step_counter_state.dart';
import '../models/product.dart';
import '../models/purchase_record.dart';
import '../models/shopping_item.dart';
import '../models/task.dart';
import '../models/weight_entry.dart';
import '../models/weekly_calorie_review.dart';
import '../models/weekly_calorie_history.dart';
import '../models/reminder_settings.dart';

class LocalStorageService {
  LocalStorageService._(this._preferences);

  final SharedPreferences _preferences;

  static const _tasksPrefix = 'tasks_';
  static const _habitsKey = 'habits';
  static const _weightsKey = 'weights';
  static const _journalKey = 'journal';
  static const _shoppingKey = 'shopping';
  static const _productsKey = 'products';
  static const _inventoryMovementsKey = 'inventoryMovements';
  static const _purchaseHistoryKey = 'purchaseHistory';
  static const _heightKey = 'height';
  static const _calorieSettingsKey = 'calorieSettings';
  static const _weeklyCalorieReviewKey = 'weeklyCalorieReview';
  static const _weeklyCalorieHistoryKey = 'weeklyCalorieHistory';
  static const _reminderSettingsKey = 'reminderSettings';
  static const _stepCounterDateKey = 'stepCounterDate';
  static const _stepCounterInitialKey = 'stepCounterInitial';
  static const _stepCounterCurrentKey = 'stepCounterCurrent';
  static const _manualStepsKey = 'manualSteps';
  static const _sensorInitializedKey = 'stepSensorInitialized';

  static Future<LocalStorageService> create() async {
    return LocalStorageService._(await SharedPreferences.getInstance());
  }

  Future<List<Task>> loadTasks(String dayKey) async {
    final raw = _preferences.getString('$_tasksPrefix$dayKey');
    if (raw == null) return [];
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((item) => Task.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveTasks(String dayKey, List<Task> tasks) {
    return _preferences.setString(
      '$_tasksPrefix$dayKey',
      jsonEncode(tasks.map((task) => task.toJson()).toList()),
    );
  }

  Future<List<Task>> loadHabits() async {
    return _loadList(_habitsKey, Task.fromJson);
  }

  bool get hasSavedHabits => _preferences.containsKey(_habitsKey);

  Future<void> saveHabits(List<Task> habits) {
    return _saveList(
      _habitsKey,
      habits.map((habit) => habit.toJson()).toList(),
    );
  }

  Future<Map<String, List<Task>>> loadTaskHistory() async {
    final history = <String, List<Task>>{};
    for (final key in _preferences.getKeys()) {
      if (!key.startsWith(_tasksPrefix)) continue;
      final dayKey = key.substring(_tasksPrefix.length);
      history[dayKey] = await loadTasks(dayKey);
    }
    return history;
  }

  Future<List<WeightEntry>> loadWeights() async {
    return _loadList(_weightsKey, WeightEntry.fromJson);
  }

  Future<void> saveWeights(List<WeightEntry> entries) {
    return _saveList(
      _weightsKey,
      entries.map((entry) => entry.toJson()).toList(),
    );
  }

  Future<CalorieSettings> loadCalorieSettings() async {
    final raw = _preferences.getString(_calorieSettingsKey);
    if (raw == null) return CalorieSettings.defaults;
    return CalorieSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> saveCalorieSettings(CalorieSettings settings) {
    return _preferences.setString(
      _calorieSettingsKey,
      jsonEncode(settings.toJson()),
    );
  }

  Future<WeeklyCalorieReview?> loadWeeklyCalorieReview() async {
    final raw = _preferences.getString(_weeklyCalorieReviewKey);
    if (raw == null) return null;
    return WeeklyCalorieReview.fromJson(
      jsonDecode(raw) as Map<String, dynamic>,
    );
  }

  Future<void> saveWeeklyCalorieReview(WeeklyCalorieReview review) {
    return _preferences.setString(
      _weeklyCalorieReviewKey,
      jsonEncode(review.toJson()),
    );
  }

  Future<List<WeeklyCalorieHistory>> loadWeeklyCalorieHistory() {
    return _loadList(_weeklyCalorieHistoryKey, WeeklyCalorieHistory.fromJson);
  }

  Future<void> saveWeeklyCalorieHistory(List<WeeklyCalorieHistory> history) {
    return _saveList(
      _weeklyCalorieHistoryKey,
      history.map((entry) => entry.toJson()).toList(),
    );
  }

  Future<ReminderSettings> loadReminderSettings() async {
    final raw = _preferences.getString(_reminderSettingsKey);
    if (raw == null) return ReminderSettings.defaults;
    return ReminderSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> saveReminderSettings(ReminderSettings settings) {
    return _preferences.setString(
      _reminderSettingsKey,
      jsonEncode(settings.toJson()),
    );
  }

  Future<List<JournalEntry>> loadJournal() async {
    return _loadList(_journalKey, JournalEntry.fromJson);
  }

  Future<void> saveJournal(List<JournalEntry> entries) {
    return _saveList(
      _journalKey,
      entries.map((entry) => entry.toJson()).toList(),
    );
  }

  Future<DailyStepCounterState?> loadDailyStepCounterState() async {
    final date = _preferences.getString(_stepCounterDateKey);
    final initial = _preferences.getDouble(_stepCounterInitialKey);
    final current = _preferences.getDouble(_stepCounterCurrentKey);
    if (date == null || initial == null || current == null) return null;
    return DailyStepCounterState(
      date: DateTime.parse(date),
      initialCounter: initial,
      currentCounter: current,
      manualSteps: _preferences.getInt(_manualStepsKey) ?? 0,
      sensorInitialized: _preferences.getBool(_sensorInitializedKey) ?? true,
    );
  }

  Future<void> saveDailyStepCounterState(DailyStepCounterState state) async {
    await _preferences.setString(
      _stepCounterDateKey,
      state.date.toIso8601String(),
    );
    await _preferences.setDouble(_stepCounterInitialKey, state.initialCounter);
    await _preferences.setDouble(_stepCounterCurrentKey, state.currentCounter);
    await _preferences.setInt(_manualStepsKey, state.manualSteps);
    await _preferences.setBool(_sensorInitializedKey, state.sensorInitialized);
  }

  Future<List<ShoppingItem>> loadShopping() async {
    return _loadList(_shoppingKey, ShoppingItem.fromJson);
  }

  Future<void> saveShopping(List<ShoppingItem> items) {
    return _saveList(_shoppingKey, items.map((item) => item.toJson()).toList());
  }

  Future<List<PurchaseRecord>> loadPurchaseHistory() {
    return _loadList(_purchaseHistoryKey, PurchaseRecord.fromJson);
  }

  Future<void> savePurchaseHistory(List<PurchaseRecord> records) {
    return _saveList(
      _purchaseHistoryKey,
      records.map((record) => record.toJson()).toList(),
    );
  }

  Future<List<Product>> loadProducts() async {
    return _loadList(_productsKey, Product.fromJson);
  }

  Future<void> saveProducts(List<Product> products) {
    return _saveList(
      _productsKey,
      products.map((product) => product.toJson()).toList(),
    );
  }

  Future<List<InventoryMovement>> loadInventoryMovements() async {
    return _loadList(_inventoryMovementsKey, InventoryMovement.fromJson);
  }

  Future<void> saveInventoryMovements(List<InventoryMovement> movements) {
    return _saveList(
      _inventoryMovementsKey,
      movements.map((movement) => movement.toJson()).toList(),
    );
  }

  Future<Product> applyInventoryMovement({
    required Product product,
    required InventoryMovementType type,
    required double quantity,
  }) async {
    if (quantity <= 0) {
      throw ArgumentError.value(
        quantity,
        'quantity',
        'Debe ser mayor que cero',
      );
    }
    final updatedQuantity = type == InventoryMovementType.add
        ? product.currentQuantity + quantity
        : product.currentQuantity - quantity;
    if (updatedQuantity < 0) {
      throw StateError('No puedes consumir más cantidad de la disponible');
    }

    final updatedProduct = product.copyWith(currentQuantity: updatedQuantity);
    final products = await loadProducts();
    final updatedProducts = products
        .map((item) => item.id == product.id ? updatedProduct : item)
        .toList();
    if (!updatedProducts.any((item) => item.id == product.id)) {
      throw StateError('El producto no existe en el inventario');
    }
    final movements = await loadInventoryMovements();
    movements.add(
      InventoryMovement(
        productId: product.id,
        type: type,
        quantity: quantity,
        date: DateTime.now(),
      ),
    );
    await saveProducts(updatedProducts);
    await saveInventoryMovements(movements);
    return updatedProduct;
  }

  Future<Product> registerPurchase({
    required ShoppingItem item,
    required Product product,
    required double quantity,
    DateTime? date,
  }) async {
    final updatedProduct = await applyInventoryMovement(
      product: product,
      type: InventoryMovementType.add,
      quantity: quantity,
    );
    final shoppingItems = await loadShopping();
    await saveShopping(
      shoppingItems.where((current) => current.id != item.id).toList(),
    );
    final history = await loadPurchaseHistory();
    history.add(
      PurchaseRecord(
        productId: product.id,
        productName: product.name,
        quantity: quantity,
        unit: product.unit,
        date: date ?? DateTime.now(),
      ),
    );
    await savePurchaseHistory(history);
    return updatedProduct;
  }

  double? loadHeight() => _preferences.getDouble(_heightKey);

  Future<void> saveHeight(double height) =>
      _preferences.setDouble(_heightKey, height);

  Future<List<T>> _loadList<T>(
    String key,
    T Function(Map<String, dynamic>) fromJson,
  ) async {
    final raw = _preferences.getString(key);
    if (raw == null) return [];
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((item) => fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> _saveList(String key, List<Map<String, dynamic>> values) {
    return _preferences.setString(key, jsonEncode(values));
  }
}
