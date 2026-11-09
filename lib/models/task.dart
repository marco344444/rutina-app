class Task {
  const Task({
    required this.id,
    required this.title,
    this.completed = false,
    this.target,
    this.value,
  });

  final String id;
  final String title;
  final bool completed;
  final double? target;
  final double? value;

  bool get isQuantitative => target != null;

  Task copyWith({bool? completed, double? target, double? value}) {
    return Task(
      id: id,
      title: title,
      completed: completed ?? this.completed,
      target: target ?? this.target,
      value: value ?? this.value,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'completed': completed,
    'target': target,
    'value': value,
  };

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'] as String,
      title: json['title'] as String,
      completed: json['completed'] as bool? ?? false,
      target: (json['target'] as num?)?.toDouble(),
      value: (json['value'] as num?)?.toDouble(),
    );
  }
}
