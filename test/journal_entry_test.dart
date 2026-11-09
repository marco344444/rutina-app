import 'package:flutter_test/flutter_test.dart';
import 'package:routine_app/models/journal_entry.dart';

void main() {
  final date = DateTime(2026, 9, 7);

  test('saves and loads mood', () {
    final restored = JournalEntry.fromJson(
      JournalEntry(date: date, text: 'Bien', mood: 7).toJson(),
    );
    expect(restored.mood, 7);
  });

  test('supports mood boundaries', () {
    expect(
      JournalEntry.fromJson(
        JournalEntry(date: date, text: '', mood: 1).toJson(),
      ).mood,
      1,
    );
    expect(
      JournalEntry.fromJson(
        JournalEntry(date: date, text: '', mood: 10).toJson(),
      ).mood,
      10,
    );
  });

  test('normalizes invalid mood to null', () {
    final json = {'date': date.toIso8601String(), 'text': 'x', 'mood': 11};
    expect(JournalEntry.fromJson(json).mood, isNull);
  });

  test('keeps entries without mood compatible', () {
    final restored = JournalEntry.fromJson({
      'date': date.toIso8601String(),
      'text': 'Entrada antigua',
    });
    expect(restored.mood, isNull);
  });
}
