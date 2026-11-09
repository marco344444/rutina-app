import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:routine_app/models/inventory_movement.dart';
import 'package:routine_app/models/product.dart';
import 'package:routine_app/models/shopping_item.dart';
import 'package:routine_app/services/local_storage_service.dart';
import 'package:routine_app/utils/purchase_recommendations.dart';
import 'package:routine_app/utils/inventory_statistics.dart';

Product _product({
  required String id,
  required double current,
  double minimum = 10,
  double target = 60,
  bool active = true,
}) {
  return Product(
    id: id,
    name: id,
    category: 'Otros',
    unit: 'unidad',
    currentQuantity: current,
    minimumQuantity: minimum,
    targetQuantity: target,
    active: active,
  );
}

void main() {
  test('recommends only active products below minimum', () {
    final result = PurchaseRecommendations.forProducts([
      _product(id: 'low', current: 6),
      _product(id: 'minimum', current: 10),
      _product(id: 'above', current: 20),
      _product(id: 'inactive', current: 0, active: false),
      _product(id: 'empty', current: 0),
    ]);

    expect(result.map((item) => item.product.id), ['low', 'empty']);
    expect(result.first.quantity, 54);
  });

  test(
    'does not recommend a negative quantity when target is below current',
    () {
      final result = PurchaseRecommendations.forProducts([
        _product(id: 'target-reached', current: 20, minimum: 30, target: 10),
      ]);

      expect(result, isEmpty);
    },
  );

  test('uses consumption history when weekly demand exceeds target', () {
    final result = PurchaseRecommendations.forProducts(
      [_product(id: 'eggs', current: 1, minimum: 10, target: 3)],
      movements: [
        InventoryMovement(
          productId: 'eggs',
          type: InventoryMovementType.consume,
          quantity: 10,
          date: DateTime(2026, 9, 1),
        ),
        InventoryMovement(
          productId: 'eggs',
          type: InventoryMovementType.consume,
          quantity: 10,
          date: DateTime(2026, 9, 2),
        ),
      ],
      referenceDate: DateTime(2026, 9, 6),
    );

    expect(result.single.quantity, closeTo(11 / 3, .001));
    expect(result.single.prediction, isNotNull);
  });

  test('keeps the target calculation without sufficient history', () {
    final result = PurchaseRecommendations.forProducts([
      _product(id: 'eggs', current: 6, minimum: 10, target: 60),
    ]);

    expect(result.single.quantity, 54);
    expect(result.single.prediction, isNull);
  });

  test(
    'partial purchase updates inventory and recalculates recommendation',
    () async {
      SharedPreferences.setMockInitialValues({});
      final storage = await LocalStorageService.create();
      final product = _product(id: 'eggs', current: 6);
      await storage.saveProducts([product]);

      final updated = await storage.applyInventoryMovement(
        product: product,
        type: InventoryMovementType.add,
        quantity: 2,
      );
      final recommendation = PurchaseRecommendations.forProducts([updated]);

      expect(updated.currentQuantity, 8);
      expect(recommendation.single.quantity, 52);
      expect((await storage.loadInventoryMovements()).single.quantity, 2);
    },
  );

  test(
    'a completed purchase is not recommended again once above minimum',
    () async {
      SharedPreferences.setMockInitialValues({});
      final storage = await LocalStorageService.create();
      final product = _product(id: 'eggs', current: 6);
      const item = ShoppingItem(
        id: 'product_eggs',
        name: 'eggs',
        productId: 'eggs',
        quantity: 54,
        unit: 'unidad',
      );
      await storage.saveProducts([product]);
      await storage.saveShopping([item]);

      final updated = await storage.registerPurchase(
        item: item,
        product: product,
        quantity: 54,
      );

      expect(PurchaseRecommendations.forProducts([updated]), isEmpty);
      expect(await storage.loadShopping(), isEmpty);
      expect(
        (await storage.loadInventoryMovements()).single.type,
        InventoryMovementType.add,
      );
      expect(
        InventoryStatistics.metrics(
          movements: await storage.loadInventoryMovements(),
          productId: 'eggs',
        ).last7Days,
        isNull,
      );
    },
  );
}
