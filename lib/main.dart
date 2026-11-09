import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'screens/home_screen.dart';
import 'services/local_storage_service.dart';
import 'services/reminder_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es');
  await ReminderService.instance.initialize();
  final storage = await LocalStorageService.create();
  final reminderSettings = await storage.loadReminderSettings();
  await ReminderService.instance.schedule(reminderSettings);
  runApp(RoutineApp(storage: storage));
}

class RoutineApp extends StatelessWidget {
  const RoutineApp({required this.storage, super.key});

  final LocalStorageService storage;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rutina',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: HomeScreen(storage: storage),
    );
  }
}
