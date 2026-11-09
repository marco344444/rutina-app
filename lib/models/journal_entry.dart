class JournalEntry {
  const JournalEntry({required this.date, required this.text, this.mood})
    : assert(mood == null || (mood >= 1 && mood <= 10));

  final DateTime date;
  final String text;
  final int? mood;

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    'text': text,
    if (mood != null) 'mood': mood,
  };

  factory JournalEntry.fromJson(Map<String, dynamic> json) {
    final rawMood = json['mood'];
    final mood = rawMood is num && rawMood >= 1 && rawMood <= 10
        ? rawMood.toInt()
        : null;
    return JournalEntry(
      date: DateTime.parse(json['date'] as String),
      text: json['text'] as String,
      mood: mood,
    );
  }
}
