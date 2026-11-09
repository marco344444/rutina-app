import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:routine_app/models/inventory_movement.dart';
import 'package:routine_app/models/product.dart';
import 'package:routine_app/models/shopping_item.dart';
import 'package:routine_app/services/local_storage_service.dart';
import 'package:routine_app/utils/inventory_statistics.dart';

void main() {
  test(
    'persists products and inventory movements without touching existing data',
    () async {
      SharedPreferences.setMockInitialValues({
        'height': 178.0,
        'habits': '[{"id":"steps","title":"10.000 pasos","completed":false}]',
      });
      final storage = await LocalStorageService.create();
      const product = Product(
        id: 'eggs',
        name: 'Huevos',
        category: 'Proteínas',
        unit: 'unidad',
        currentQuantity: 60,
        minimumQuantity: 12,
        targetQuantity: 60,
      );
      final movement = InventoryMovement(
        productId: 'eggs',
        type: InventoryMovementType.consume,
        quantity: 4,
        date: DateTime(2026, 9, 6, 20),
      );

      await storage.saveProducts([product]);
      await storage.saveInventoryMovements([movement]);

      expect((await storage.loadProducts()).single.toJson(), product.toJson());
      expect(
        (await storage.loadInventoryMovements()).single.toJson(),
        movement.toJson(),
      );
      final metric = InventoryStatistics.metrics(
        movements: await storage.loadInventoryMovements(),
        productId: 'eggs',
        referenceDate: DateTime(2026, 9, 6),
      );
      expect(metric.last7Days, 4);
      expect(metric.last30Days, 4);
      expect(storage.loadHeight(), 178.0);
      expect((await storage.loadHabits()).single.id, 'steps');
    },
  );

  test(
    'updates quantity, records movement, and rejects negative inventory',
    () async {
      SharedPreferences.setMockInitialValues({});
      final storage = await LocalStorageService.create();
      const product = Product(
        id: 'berries',
        name: 'Moras',
        category: 'Frutas',
        unit: 'g',
        currentQuantity: 5,
        minimumQuantity: 10,
        targetQuantity: 500,
      );
      await storage.saveProducts([product]);

      final updated = await storage.applyInventoryMovement(
        product: product,
        type: InventoryMovementType.consume,
        quantity: 4,
      );

      expect(updated.currentQuantity, 1);
      expect((await storage.loadProducts()).single.currentQuantity, 1);
      expect((await storage.loadInventoryMovements()).single.quantity, 4);
      await expectLater(
        storage.applyInventoryMovement(
          product: updated,
          type: InventoryMovementType.consume,
          quantity: 2,
        ),
        throwsA(isA<StateError>()),
      );
    },
  );

  test('registers a purchase in inventory, add movements, shopping history, and persistence', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = await LocalStorageService.create();
    const product = Product(
      id: 'rice',
      name: 'Arroz',
      category: 'Carbohidratos',
      unit: 'kg',
      currentQuantity: 2,
      minimumQuantity: 1,
      targetQuantity: 5,
    );
    const item = ShoppingItem(
      id: 'product_rice',
      name: 'Arroz',
      productId: 'rice',
      quantity: 3,
      unit: 'kg',
    );
    await storage.saveProducts([product]);
    await storage.saveShopping([item]);

    final updated = await storage.registerPurchase(
      item: item,
      product: product,
      quantity: 3,
      date: DateTime(2026, 9, 7),
    );

    expect(updated.currentQuantity, 5);
    expect(await storage.loadShopping(), isEmpty);
    expect(
      (await storage.loadInventoryMovements()).single.type,
      InventoryMovementType.add,
    );
    expect((await storage.loadInventoryMovements()).single.quantity, 3);
    final history = await storage.loadPurchaseHistory();
    expect(history.single.productName, 'Arroz');
    expect(history.single.quantity, 3);
    expect(history.single.unit, 'kg');
    expect(history.single.date, DateTime(2026, 9, 7));

    final reloaded = await LocalStorageService.create();
    expect((await reloaded.loadProducts()).single.currentQuantity, 5);
    expect((await reloaded.loadPurchaseHistory()).single.productId, 'rice');
  });
}
