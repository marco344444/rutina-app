enum WeeklyReviewStatus { pending, applied, dismissed }

class WeeklyCalorieReview {
  const WeeklyCalorieReview({
    required this.weekStart,
    required this.reviewedAt,
    required this.proposedCalories,
    required this.status,
  });

  final DateTime weekStart;
  final DateTime reviewedAt;
  final double proposedCalories;
  final WeeklyReviewStatus status;

  Map<String, dynamic> toJson() => {
    'weekStart': weekStart.toIso8601String(),
    'reviewedAt': reviewedAt.toIso8601String(),
    'proposedCalories': proposedCalories,
    'status': status.name,
  };

  factory WeeklyCalorieReview.fromJson(Map<String, dynamic> json) {
    return WeeklyCalorieReview(
      weekStart: DateTime.parse(json['weekStart'] as String),
      reviewedAt: DateTime.parse(json['reviewedAt'] as String),
      proposedCalories: (json['proposedCalories'] as num).toDouble(),
      status: WeeklyReviewStatus.values.firstWhere(
        (value) => value.name == json['status'],
        orElse: () => WeeklyReviewStatus.pending,
      ),
    );
  }

  WeeklyCalorieReview copyWith({WeeklyReviewStatus? status}) {
    return WeeklyCalorieReview(
      weekStart: weekStart,
      reviewedAt: reviewedAt,
      proposedCalories: proposedCalories,
      status: status ?? this.status,
    );
  }
}
