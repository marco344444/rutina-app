import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:routine_app/main.dart';
import 'package:routine_app/services/local_storage_service.dart';

void main() {
  testWidgets('shows the daily checklist', (WidgetTester tester) async {
    await initializeDateFormatting('es');
    SharedPreferences.setMockInitialValues({});
    final storage = await LocalStorageService.create();

    await tester.pumpWidget(RoutineApp(storage: storage));
    await tester.pump();

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
