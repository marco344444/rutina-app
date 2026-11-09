import 'package:flutter/material.dart';

import '../models/inventory_movement.dart';
import '../models/product.dart';
import '../models/shopping_item.dart';
import '../services/local_storage_service.dart';
import '../utils/purchase_recommendations.dart';
import '../utils/inventory_statistics.dart';
import '../utils/inventory_prediction.dart';
import '../widgets/consumption_chart.dart';

class ShoppingScreen extends StatefulWidget {
  const ShoppingScreen({required this.storage, super.key});

  final LocalStorageService storage;

  @override
  State<ShoppingScreen> createState() => _ShoppingScreenState();
}

class _ShoppingScreenState extends State<ShoppingScreen> {
  static const _categories = [
    'Frutas',
    'Verduras',
    'Proteínas',
    'Lácteos',
    'Carbohidratos',
    'Otros',
  ];
  static const _units = ['unidad', 'g', 'kg', 'ml', 'L'];

  List<Product> _products = [];
  List<ShoppingItem> _shoppingItems = [];
  List<InventoryMovement> _movements = [];
  String? _selectedStatisticsProductId;
  bool _showInactive = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final products = await widget.storage.loadProducts();
    final shoppingItems = await widget.storage.loadShopping();
    final movements = await widget.storage.loadInventoryMovements();
    if (!mounted) return;
    setState(() {
      _products = products;
      _shoppingItems = shoppingItems;
      _movements = movements;
      _loading = false;
    });
  }

  Future<void> _saveProduct(Product product) async {
    final products = [
      ..._products.where((item) => item.id != product.id),
      product,
    ];
    await widget.storage.saveProducts(products);
    if (mounted) setState(() => _products = products);
  }

  Future<void> _showProductForm([Product? existing]) async {
    final product = await showDialog<Product>(
      context: context,
      builder: (_) => _ProductDialog(
        product: existing,
        categories: _categories,
        units: _units,
      ),
    );
    if (product != null) await _saveProduct(product);
  }

  Future<void> _changeQuantity(Product product, double quantity) async {
    final type = quantity < 0
        ? InventoryMovementType.consume
        : InventoryMovementType.add;
    try {
      final updated = await widget.storage.applyInventoryMovement(
        product: product,
        type: type,
        quantity: quantity.abs(),
      );
      if (mounted) {
        final movements = await widget.storage.loadInventoryMovements();
        setState(() {
          _products = _products
              .map((item) => item.id == updated.id ? updated : item)
              .toList();
          _movements = movements;
        });
      }
    } on StateError catch (error) {
      if (mounted) _showMessage(error.message);
    } on ArgumentError catch (error) {
      if (mounted) _showMessage(error.message ?? 'Cantidad inválida');
    }
  }

  Future<void> _showCustomMovement(Product product) async {
    final result = await showDialog<_MovementRequest>(
      context: context,
      builder: (_) => _MovementDialog(product: product),
    );
    if (result == null) return;
    await _changeQuantity(
      product,
      result.type == InventoryMovementType.consume
          ? -result.quantity
          : result.quantity,
    );
  }

  Future<void> _addShoppingItem() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Agregar a compras'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Ej. Café'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Agregar'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    final item = ShoppingItem(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name,
    );
    final items = [..._shoppingItems, item];
    await widget.storage.saveShopping(items);
    if (mounted) setState(() => _shoppingItems = items);
  }

  Future<void> _toggleShoppingItem(ShoppingItem item) async {
    if (!item.purchased && item.productId != null) {
      await _confirmRealPurchase(item);
      return;
    }
    final items = _shoppingItems
        .map(
          (current) => current.id == item.id
              ? current.copyWith(purchased: !current.purchased)
              : current,
        )
        .toList();
    await widget.storage.saveShopping(items);
    if (mounted) setState(() => _shoppingItems = items);
  }

  List<PurchaseRecommendation> get _recommendations =>
      PurchaseRecommendations.forProducts(_products, movements: _movements);

  bool _isInShoppingList(String productId) {
    return _shoppingItems.any(
      (item) => item.productId == productId && !item.purchased,
    );
  }

  Future<void> _addRecommendation(PurchaseRecommendation recommendation) async {
    if (_isInShoppingList(recommendation.product.id)) return;
    final items = [
      ..._shoppingItems,
      ShoppingItem(
        id: 'product_${recommendation.product.id}',
        name: recommendation.product.name,
        productId: recommendation.product.id,
        quantity: recommendation.quantity,
        unit: recommendation.product.unit,
      ),
    ];
    await widget.storage.saveShopping(items);
    if (mounted) setState(() => _shoppingItems = items);
  }

  Future<void> _addAllRecommendations() async {
    for (final recommendation in _recommendations) {
      await _addRecommendation(recommendation);
    }
  }

  Future<void> _confirmRealPurchase(ShoppingItem item) async {
    final product = _products.where((p) => p.id == item.productId).firstOrNull;
    if (product == null) return;
    final controller = TextEditingController(
      text: item.quantity?.toString() ?? '',
    );
    final quantity = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Compra de ${product.name}'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Cantidad comprada (${product.unit})',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              context,
              double.tryParse(controller.text.replaceAll(',', '.')),
            ),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    if (quantity == null || quantity <= 0) return;
    final updated = await widget.storage.registerPurchase(
      item: item,
      product: product,
      quantity: quantity,
    );
    final movements = await widget.storage.loadInventoryMovements();
    if (mounted) {
      setState(() {
        _products = _products
            .map((current) => current.id == updated.id ? updated : current)
            .toList();
        _shoppingItems = _shoppingItems
            .where((current) => current.id != item.id)
            .toList();
        _movements = movements;
      });
    }
  }

  Future<void> _showPurchaseHistory() async {
    final history = await widget.storage.loadPurchaseHistory();
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Historial de compras'),
        content: SizedBox(
          width: double.maxFinite,
          child: history.isEmpty
              ? const Text('Todavía no hay compras registradas.')
              : ListView(
                  shrinkWrap: true,
                  children: history.reversed
                      .map(
                        (purchase) => ListTile(
                          title: Text(purchase.productName),
                          subtitle: Text(
                            '${_formatQuantity(purchase.quantity)} ${purchase.unit} · '
                            '${_formatDate(purchase.date)}',
                          ),
                        ),
                      )
                      .toList(),
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Compras'),
          actions: [
            if (!_loading)
              IconButton(
                onPressed: () => _showProductForm(),
                icon: const Icon(Icons.add),
                tooltip: 'Agregar producto',
              ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Inventario'),
              Tab(text: 'Lista'),
              Tab(text: 'Estadísticas'),
            ],
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _buildInventory(),
                  _buildShoppingList(),
                  _buildStatistics(),
                ],
              ),
        floatingActionButton: _loading
            ? null
            : FloatingActionButton(
                onPressed: _addShoppingItem,
                tooltip: 'Agregar a lista',
                child: const Icon(Icons.playlist_add),
              ),
      ),
    );
  }

  Widget _buildInventory() {
    final products = _products
        .where((product) => _showInactive || product.active)
        .toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Mostrar productos inactivos'),
          value: _showInactive,
          onChanged: (value) => setState(() => _showInactive = value),
        ),
        if (products.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 48),
            child: Center(child: Text('No hay productos en el inventario')),
          ),
        ...products.map(_buildProductCard),
      ],
    );
  }

  Widget _buildProductCard(Product product) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    product.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  onPressed: () => _showProductForm(product),
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'Editar producto',
                ),
              ],
            ),
            Text('${_formatQuantity(product.currentQuantity)} ${product.unit}'),
            Text(
              '${product.category} · Mínimo ${_formatQuantity(product.minimumQuantity)} · Objetivo ${_formatQuantity(product.targetQuantity)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final value in [-1.0, -4.0, -10.0, 10.0, 30.0])
                  OutlinedButton(
                    onPressed: () => _changeQuantity(product, value),
                    child: Text(
                      value > 0
                          ? '+${_formatQuantity(value)}'
                          : _formatQuantity(value),
                    ),
                  ),
                OutlinedButton(
                  onPressed: () => _showCustomMovement(product),
                  child: const Text('Personalizar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShoppingList() {
    final pendingItems = _shoppingItems
        .where((item) => !item.purchased)
        .toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
      children: [
        if (_recommendations.isNotEmpty) ...[
          Text(
            'Necesitas comprar',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          ..._recommendations.map(_buildRecommendation),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _addAllRecommendations,
            icon: const Icon(Icons.playlist_add),
            label: const Text('Agregar todas las recomendaciones'),
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 12),
        ],
        Text('Lista de compras', style: Theme.of(context).textTheme.titleLarge),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: _showPurchaseHistory,
            icon: const Icon(Icons.history),
            label: const Text('Historial de compras'),
          ),
        ),
        if (pendingItems.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 48),
            child: Center(child: Text('Tu lista de compras está vacía')),
          ),
        ...pendingItems.map(
          (item) => CheckboxListTile(
            value: item.purchased,
            title: Text(item.name),
            controlAffinity: ListTileControlAffinity.leading,
            onChanged: (_) => _toggleShoppingItem(item),
          ),
        ),
      ],
    );
  }

  Widget _buildStatistics() {
    final activeProducts = _products
        .where((product) => product.active)
        .toList();
    if (activeProducts.isEmpty) {
      return const Center(child: Text('No hay productos activos'));
    }
    final selectedId = _selectedStatisticsProductId ?? activeProducts.first.id;
    final selected = activeProducts.firstWhere(
      (product) => product.id == selectedId,
      orElse: () => activeProducts.first,
    );
    final metrics = InventoryStatistics.metrics(
      movements: _movements,
      productId: selected.id,
    );
    final prediction = InventoryPrediction.forProduct(
      movements: _movements,
      productId: selected.id,
      currentQuantity: selected.currentQuantity,
    );
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
      children: [
        DropdownButtonFormField<String>(
          initialValue: selected.id,
          decoration: const InputDecoration(labelText: 'Producto'),
          items: activeProducts
              .map(
                (product) => DropdownMenuItem(
                  value: product.id,
                  child: Text(product.name),
                ),
              )
              .toList(),
          onChanged: (value) =>
              setState(() => _selectedStatisticsProductId = value),
        ),
        const SizedBox(height: 16),
        _metricCard('Últimos 7 días', metrics.last7Days, selected.unit),
        _metricCard('Últimos 30 días', metrics.last30Days, selected.unit),
        _metricCard('Promedio semanal', metrics.averageWeekly, selected.unit),
        _metricCard('Promedio diario', metrics.averageDaily, selected.unit),
        const SizedBox(height: 8),
        Text('Estimaciones', style: Theme.of(context).textTheme.titleLarge),
        _metricCard(
          'Consumo estimado semanal',
          prediction.estimatedWeeklyConsumption,
          selected.unit,
          emptyLabel: 'Sin estimación',
        ),
        _metricCard(
          'Inventario restante',
          prediction.daysRemaining,
          'días',
          decimals: 1,
          emptyLabel: 'Sin estimación',
        ),
        const SizedBox(height: 16),
        Text(
          'Consumo · ${selected.name}',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 180,
          child: ConsumptionChart(
            buckets: InventoryStatistics.weekly(
              movements: _movements,
              productId: selected.id,
              days: 30,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Mayor consumo (30 días)',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        ...InventoryStatistics.ranking(movements: _movements).entries.map(
          (entry) => ListTile(
            leading: Text(entry.key == selected.id ? '•' : ''),
            title: Text(
              _products
                      .where((product) => product.id == entry.key)
                      .firstOrNull
                      ?.name ??
                  entry.key,
            ),
            trailing: Text(
              '${_formatQuantity(entry.value)} ${_products.where((p) => p.id == entry.key).firstOrNull?.unit ?? ''}',
            ),
          ),
        ),
      ],
    );
  }

  Widget _metricCard(
    String label,
    double? value,
    String unit, {
    int decimals = 2,
    String emptyLabel = 'Sin datos',
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(label),
        trailing: Text(
          value == null
              ? emptyLabel
              : '${_formatQuantity(value, decimals: decimals)} $unit',
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
    );
  }

  Widget _buildRecommendation(PurchaseRecommendation recommendation) {
    final product = recommendation.product;
    final alreadyAdded = _isInShoppingList(product.id);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(product.name),
        subtitle: Text(
          'Actual: ${_formatQuantity(product.currentQuantity)} ${product.unit}\n'
          'Mínimo: ${_formatQuantity(product.minimumQuantity)} ${product.unit}\n'
          'Objetivo: ${_formatQuantity(product.targetQuantity)} ${product.unit}\n'
          '${recommendation.prediction == null ? '' : 'Consumo: ${_formatQuantity(recommendation.prediction!.averageDaily!)} ${product.unit}/día\n'
                    'Duración: ~${_formatQuantity(recommendation.prediction!.daysRemaining!, decimals: 1)} días\n'}'
          'Compra recomendada: ${_formatQuantity(recommendation.quantity)} ${product.unit}',
        ),
        trailing: OutlinedButton(
          onPressed: alreadyAdded
              ? null
              : () => _addRecommendation(recommendation),
          child: Text(alreadyAdded ? 'Agregado' : 'Agregar'),
        ),
      ),
    );
  }

  String _formatQuantity(double value, {int decimals = 2}) {
    return value == value.roundToDouble()
        ? value.toInt().toString()
        : value
              .toStringAsFixed(decimals)
              .replaceFirst(RegExp(r'0+$'), '')
              .replaceFirst(RegExp(r'\.$'), '');
  }

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/'
      '${date.year}';
}

class _ProductDialog extends StatefulWidget {
  const _ProductDialog({
    required this.product,
    required this.categories,
    required this.units,
  });

  final Product? product;
  final List<String> categories;
  final List<String> units;

  @override
  State<_ProductDialog> createState() => _ProductDialogState();
}

class _ProductDialogState extends State<_ProductDialog> {
  late final TextEditingController _name;
  late final TextEditingController _category;
  late final TextEditingController _unit;
  late final TextEditingController _current;
  late final TextEditingController _minimum;
  late final TextEditingController _target;
  late bool _active;

  @override
  void initState() {
    super.initState();
    final product = widget.product;
    _name = TextEditingController(text: product?.name);
    _category = TextEditingController(
      text: product?.category ?? widget.categories.last,
    );
    _unit = TextEditingController(text: product?.unit ?? widget.units.first);
    _current = TextEditingController(text: product?.currentQuantity.toString());
    _minimum = TextEditingController(text: product?.minimumQuantity.toString());
    _target = TextEditingController(text: product?.targetQuantity.toString());
    _active = product?.active ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _category.dispose();
    _unit.dispose();
    _current.dispose();
    _minimum.dispose();
    _target.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    final current = _parse(_current.text);
    final minimum = _parse(_minimum.text);
    final target = _parse(_target.text);
    if (name.isEmpty ||
        current == null ||
        minimum == null ||
        target == null ||
        current < 0 ||
        minimum < 0 ||
        target < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completa cantidades válidas')),
      );
      return;
    }
    final existing = widget.product;
    Navigator.pop(
      context,
      Product(
        id: existing?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        name: name,
        category: _category.text,
        unit: _unit.text,
        currentQuantity: current,
        minimumQuantity: minimum,
        targetQuantity: target,
        active: _active,
      ),
    );
  }

  double? _parse(String value) =>
      double.tryParse(value.trim().replaceAll(',', '.'));

  @override
  Widget build(BuildContext context) {
    final editing = widget.product != null;
    return AlertDialog(
      title: Text(editing ? 'Editar producto' : 'Nuevo producto'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Nombre'),
            ),
            DropdownButtonFormField<String>(
              initialValue: widget.categories.contains(_category.text)
                  ? _category.text
                  : null,
              decoration: const InputDecoration(labelText: 'Categoría'),
              items: widget.categories
                  .map(
                    (category) => DropdownMenuItem(
                      value: category,
                      child: Text(category),
                    ),
                  )
                  .toList(),
              onChanged: (value) =>
                  setState(() => _category.text = value ?? _category.text),
            ),
            DropdownButtonFormField<String>(
              initialValue: widget.units.contains(_unit.text)
                  ? _unit.text
                  : null,
              decoration: const InputDecoration(labelText: 'Unidad'),
              items: widget.units
                  .map(
                    (unit) => DropdownMenuItem(value: unit, child: Text(unit)),
                  )
                  .toList(),
              onChanged: (value) =>
                  setState(() => _unit.text = value ?? _unit.text),
            ),
            TextField(
              controller: _current,
              enabled: !editing,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Cantidad actual',
                helperText: editing
                    ? 'Modifícala desde los botones del inventario'
                    : null,
              ),
            ),
            TextField(
              controller: _minimum,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Cantidad mínima'),
            ),
            TextField(
              controller: _target,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Cantidad objetivo'),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Producto activo'),
              value: _active,
              onChanged: (value) => setState(() => _active = value),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Guardar')),
      ],
    );
  }
}

class _MovementRequest {
  const _MovementRequest({required this.quantity, required this.type});
  final double quantity;
  final InventoryMovementType type;
}

class _MovementDialog extends StatefulWidget {
  const _MovementDialog({required this.product});
  final Product product;

  @override
  State<_MovementDialog> createState() => _MovementDialogState();
}

class _MovementDialogState extends State<_MovementDialog> {
  final _quantity = TextEditingController();
  InventoryMovementType _type = InventoryMovementType.consume;

  @override
  void dispose() {
    _quantity.dispose();
    super.dispose();
  }

  void _submit() {
    final quantity = double.tryParse(
      _quantity.text.trim().replaceAll(',', '.'),
    );
    if (quantity == null || quantity <= 0) return;
    Navigator.pop(context, _MovementRequest(quantity: quantity, type: _type));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Modificar ${widget.product.name}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _quantity,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Cantidad'),
          ),
          DropdownButtonFormField<InventoryMovementType>(
            initialValue: _type,
            decoration: const InputDecoration(labelText: 'Acción'),
            items: const [
              DropdownMenuItem(
                value: InventoryMovementType.consume,
                child: Text('Consumir'),
              ),
              DropdownMenuItem(
                value: InventoryMovementType.add,
                child: Text('Agregar'),
              ),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _type = value);
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Guardar')),
      ],
    );
  }
}
