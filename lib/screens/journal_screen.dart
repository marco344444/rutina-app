import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/journal_entry.dart';
import '../services/local_storage_service.dart';

class JournalScreen extends StatefulWidget {
  const JournalScreen({required this.storage, super.key});
  final LocalStorageService storage;

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  final _controller = TextEditingController();
  List<JournalEntry> _entries = [];
  double? _mood;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final entries = await widget.storage.loadJournal();
    if (!mounted) return;
    setState(() {
      _entries = entries..sort((a, b) => b.date.compareTo(a.date));
      _loading = false;
    });
  }

  Future<void> _save() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final today = DateTime.now();
    final entries = [
      ..._entries.where((entry) => !DateUtils.isSameDay(entry.date, today)),
      JournalEntry(date: today, text: text, mood: _mood?.round()),
    ]..sort((a, b) => b.date.compareTo(a.date));
    await widget.storage.saveJournal(entries);
    _controller.clear();
    _mood = null;
    if (mounted) setState(() => _entries = entries);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Diario')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  '¿Cómo estuvo tu día?',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _controller,
                  minLines: 5,
                  maxLines: 8,
                  decoration: const InputDecoration(
                    hintText: 'Escribe lo que quieras recordar...',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '¿Cómo te sentiste hoy?',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Slider(
                  value: _mood ?? 5,
                  min: 1,
                  max: 10,
                  divisions: 9,
                  label: (_mood ?? 5).round().toString(),
                  onChanged: (value) => setState(() => _mood = value),
                ),
                Text(
                  _mood == null
                      ? 'Sin ánimo registrado'
                      : 'Ánimo: ${_mood!.round()} / 10',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Guardar entrada de hoy'),
                ),
                const SizedBox(height: 24),
                Text(
                  'Historial',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                ..._entries.map(
                  (entry) => Card(
                    child: ListTile(
                      title: Text(
                        DateFormat('d MMM yyyy', 'es').format(entry.date),
                      ),
                      subtitle: Text(
                        '${entry.text}'
                        '${entry.mood == null ? '' : '\nÁnimo: ${entry.mood} / 10'}',
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
