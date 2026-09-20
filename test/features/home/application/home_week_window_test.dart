import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miji/features/home/application/home_money_dashboard_providers.dart';

/// 首页「支出趋势」的窗口规则：
///
/// - 当前月：以**今天为中心**的滚动 7 天窗口，今天永远落在第 4 根柱子上；
/// - 历史月份：按月份内的自然周（周一起始）切分。
///
/// 旧的「当前月锚在 今天-3 天」实现会让窗口漂到别的月份，于是切周会连带
/// 切换月份，首页数据全空；现在的窗口不会离开本月（只要本月还有空间）。
void main() {
  group('homeWeekCountForMonth', () {
    test('counts Monday-based weeks overlapping the month', () {
      expect(homeWeekCountForMonth(DateTime(2026, 9)), 5);
      expect(homeWeekCountForMonth(DateTime(2026, 10)), 5);
      expect(homeWeekCountForMonth(DateTime(2026, 6)), 5);
      expect(homeWeekCountForMonth(DateTime(2026, 2)), 5);
    });
  });

  group('homeWeekStartForMonth', () {
    test('returns Monday of each week of the month', () {
      expect(
        homeWeekStartForMonth(DateTime(2026, 10), 0),
        DateTime(2026, 9, 28),
      );
      expect(
        homeWeekStartForMonth(DateTime(2026, 9), 0),
        DateTime(2026, 8, 31),
      );
      expect(
        homeWeekStartForMonth(DateTime(2026, 9), 4),
        DateTime(2026, 9, 28),
      );
    });

    test('every week start is a Monday', () {
      final month = DateTime(2026, 9);
      for (var i = 0; i < homeWeekCountForMonth(month); i++) {
        expect(homeWeekStartForMonth(month, i).weekday, DateTime.monday);
      }
    });
  });

  group('homeRollingBlockCount', () {
    test('counts only windows that still start inside the month', () {
      // 2026-09-20 -> 本周起点 09-17，往前 09-10 / 09-03 仍在本月，09-27 不是。
      expect(homeRollingBlockCount(DateTime(2026, 9), DateTime(2026, 9, 20)), 3);
      // 月初时只剩本周一个窗口。
      expect(homeRollingBlockCount(DateTime(2026, 9), DateTime(2026, 9, 2)), 1);
      expect(homeRollingBlockCount(DateTime(2026, 9), DateTime(2026, 9, 1)), 1);
    });

    test('caps the number of windows', () {
      expect(
        homeRollingBlockCount(DateTime(2026, 9), DateTime(2026, 9, 30)),
        lessThanOrEqualTo(homeTrendMaxBlocks),
      );
    });
  });

  group('homeTrendWindowProvider', () {
    test('keeps today centred in the current month', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final window = container.read(homeTrendWindowProvider);

      expect(window.rolling, isTrue);
      expect(window.offset, 0);
      // 今天必须落在固定位置（第 4 根柱子）。
      final todayIndex = today.difference(window.start).inDays;
      expect(todayIndex, homeTrendTodayIndex);
      expect(window.start, today.subtract(const Duration(days: 3)));
    });

    test('does not shift the month when the window moves back', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final monthBefore = container.read(homeMoneySelectedMonthProvider);
      for (var offset = 0; offset < 3; offset++) {
        container.read(homeWeekOffsetProvider.notifier).set(offset);
        expect(
          container.read(homeMoneySelectedMonthProvider),
          monthBefore,
          reason: '切换窗口不应改动选中月份',
        );
        // 窗口整体往回移 7 天，今天仍然居中。
        final window = container.read(homeTrendWindowProvider);
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        expect(today.difference(window.start).inDays, homeTrendTodayIndex + offset * 7);
      }
    });

    test('uses calendar weeks for a past month', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container
          .read(homeMoneySelectedMonthProvider.notifier)
          .set(DateTime(2000, 1));

      final window = container.read(homeTrendWindowProvider);
      expect(window.rolling, isFalse);
      expect(window.start.weekday, DateTime.monday);
      expect(window.blockCount, homeWeekCountForMonth(DateTime(2000, 1)));
      expect(window.blockLabels.first, '第 1 周');
    });

    test('labels the rolling windows from the current week backwards', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final window = container.read(homeTrendWindowProvider);
      expect(window.blockLabels.first, '本周');
      if (window.blockCount > 1) {
        expect(window.blockLabels[1], '上周');
      }
      if (window.blockCount > 2) {
        expect(window.blockLabels[2], '2 周前');
      }
    });
  });

  group('homeWeekOffsetProvider', () {
    test('resets when the selected month changes', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(homeWeekOffsetProvider.notifier).set(2);
      expect(container.read(homeWeekOffsetProvider), 2);

      container
          .read(homeMoneySelectedMonthProvider.notifier)
          .set(DateTime(2000, 1));
      expect(container.read(homeWeekOffsetProvider), 0);
    });
  });
}
