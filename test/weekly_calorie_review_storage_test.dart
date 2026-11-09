import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:routine_app/models/weekly_calorie_review.dart';
import 'package:routine_app/services/local_storage_service.dart';

void main() {
  test('persists review status across storage service recreation', () async {
    SharedPreferences.setMockInitialValues({});
    final first = await LocalStorageService.create();
    final review = WeeklyCalorieReview(
      weekStart: DateTime(2026, 8, 31),
      reviewedAt: DateTime(2026, 9, 6),
      proposedCalories: 2100,
      status: WeeklyReviewStatus.pending,
    );

    await first.saveWeeklyCalorieReview(review);
    final second = await LocalStorageService.create();
    final loaded = await second.loadWeeklyCalorieReview();

    expect(loaded?.weekStart, review.weekStart);
    expect(loaded?.proposedCalories, 2100);
    expect(loaded?.status, WeeklyReviewStatus.pending);
  });

  test('supports applied and dismissed states', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = await LocalStorageService.create();
    final review = WeeklyCalorieReview(
      weekStart: DateTime(2026, 8, 31),
      reviewedAt: DateTime(2026, 9, 6),
      proposedCalories: 2100,
      status: WeeklyReviewStatus.pending,
    );

    await storage.saveWeeklyCalorieReview(
      review.copyWith(status: WeeklyReviewStatus.applied),
    );
    expect(
      (await storage.loadWeeklyCalorieReview())?.status,
      WeeklyReviewStatus.applied,
    );
    await storage.saveWeeklyCalorieReview(
      review.copyWith(status: WeeklyReviewStatus.dismissed),
    );
    expect(
      (await storage.loadWeeklyCalorieReview())?.status,
      WeeklyReviewStatus.dismissed,
    );
  });
}
