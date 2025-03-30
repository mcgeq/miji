// web_notification_stub.dart（非 Web 平台使用）

class WebNotification {
  static Future<void> requestPermission() async =>
      throw UnsupportedError('Not supported on this platform');

  static void scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) => throw UnsupportedError('Not supported on this platform');

  static void cancelNotification(int id) =>
      throw UnsupportedError('Not supported on this platform');
}
