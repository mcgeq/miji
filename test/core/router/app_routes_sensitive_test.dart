import 'package:flutter_test/flutter_test.dart';

import 'package:miji/core/router/app_routes.dart';

/// 时间线同时展示经期与金额，必须和记账 / 健康 / 打卡一样走二次验证。
/// 这条用例的意义是：以后有人改了 `sensitiveRoutes`，这里会先红。
void main() {
  test('时间线是敏感路由，子路径也算', () {
    expect(AppRoutes.isSensitivePath(AppRoutes.timeline), isTrue);
    expect(AppRoutes.isSensitivePath('${AppRoutes.timeline}/detail'), isTrue);
  });

  test('不相关的路径不会被误伤', () {
    expect(AppRoutes.isSensitivePath(AppRoutes.home), isFalse);
    expect(AppRoutes.isSensitivePath(AppRoutes.settings), isFalse);
  });

  test('原有的三个敏感模块仍在名单里', () {
    for (final path in [
      AppRoutes.bookkeeping,
      AppRoutes.health,
      AppRoutes.gtd,
    ]) {
      expect(AppRoutes.isSensitivePath(path), isTrue, reason: path);
    }
  });
}
