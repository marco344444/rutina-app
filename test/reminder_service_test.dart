import 'package:flutter_test/flutter_test.dart';
import 'package:routine_app/models/reminder_settings.dart';
import 'package:routine_app/services/reminder_service.dart';

void main() {
  test('daily and test notifications use independent IDs', () {
    expect(
      ReminderService.reminderId,
      isNot(ReminderService.testNotificationId),
    );
    expect(
      ReminderService.dailyChannelId,
      isNot(ReminderService.testChannelId),
    );
  });

  test('changing reminder time preserves enabled state and new time', () {
    final updated = ReminderSettings.defaults.copyWith(
      enabled: true,
      hour: 21,
      minute: 30,
    );

    expect(updated.enabled, isTrue);
    expect(updated.hour, 21);
    expect(updated.minute, 30);
  });
}
