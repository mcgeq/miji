import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:miji/core/auth/application/auth_session_controller.dart';
import 'package:miji/core/auth/application/sensitive_access_controller.dart';
import 'package:miji/core/auth/domain/auth_session.dart';
import 'package:miji/core/auth/domain/sensitive_access_session.dart';
import 'package:miji/core/auth/domain/sensitive_access_ttl_option.dart';
import 'package:miji/core/presentation/components/money_text.dart';
import 'package:miji/core/theme/app_theme.dart';
import 'package:miji/features/timeline/application/timeline_providers.dart';
import 'package:miji/features/timeline/domain/timeline_event.dart';
import 'package:miji/features/timeline/presentation/timeline_page.dart';

/// 页面层只钉三件事：分组渲染、未解锁时遮蔽、单路失败不白屏。
void main() {
  final anchor = DateTime.utc(2026, 10, 18);

  TimelineEvent event({
    required String id,
    required TimelineModule module,
    required TimelineNature nature,
    required String title,
    String kind = 'test',
    int? amountMinor,
    bool sensitive = false,
    DateTime? day,
  }) {
    return TimelineEvent(
      id: id,
      occurredOn: day ?? anchor,
      module: module,
      nature: nature,
      kind: kind,
      title: title,
      amountMinor: amountMinor,
      sensitive: sensitive,
    );
  }

  Future<void> pump(
    WidgetTester tester, {
    required List<TimelineEvent> events,
    bool sensitiveVerified = false,
    bool moneyMasked = false,
    bool failHealth = false,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authSessionControllerProvider.overrideWith(() => _Unlocked()),
          sensitiveAccessControllerProvider.overrideWith(
            () => _Sensitive(verified: sensitiveVerified),
          ),
          timelineScopeProvider.overrideWith(_FixedScope.new),
          timelineMoneyReaderProvider.overrideWithValue(
            (ref, window) async => events
                .where((e) => e.module == TimelineModule.money)
                .toList(),
          ),
          timelineTodoReaderProvider.overrideWithValue(
            (ref, window) async => events
                .where((e) => e.module == TimelineModule.action)
                .toList(),
          ),
          timelineHabitReaderProvider.overrideWithValue(
            (ref, window) async => const [],
          ),
          timelineHealthReaderProvider.overrideWithValue((ref, window) async {
            if (failHealth) {
              throw StateError('健康读不出来');
            }
            return events
                .where((e) => e.module == TimelineModule.health)
                .toList();
          }),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: MoneyPrivacy(
            masked: moneyMasked,
            child: const TimelinePage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('按日分组：承诺在上、已发生折叠成一行', (tester) async {
    await pump(
      tester,
      events: [
        event(
          id: 'm1',
          module: TimelineModule.money,
          nature: TimelineNature.commitment,
          title: '房贷自动记账',
          amountMinor: -800000,
        ),
        event(
          id: 'a1',
          module: TimelineModule.action,
          nature: TimelineNature.fact,
          title: '写周报',
        ),
      ],
    );

    // 2026-10-18 是周日。
    expect(find.text('10 月 18 日 周日'), findsOneWidget);
    expect(find.text('房贷自动记账'), findsOneWidget);
    // 已发生默认折叠：标题还没渲染，只有一行「已发生 1」。
    expect(find.text('写周报'), findsNothing);
    expect(find.text('已发生 1'), findsOneWidget);

    await tester.tap(find.text('已发生 1'));
    await tester.pumpAndSettle();
    expect(find.text('写周报'), findsOneWidget);
  });

  testWidgets('未解锁：经期事件连标题都不给', (tester) async {
    await pump(
      tester,
      events: [
        event(
          id: 'h1',
          module: TimelineModule.health,
          nature: TimelineNature.prediction,
          title: '预计经期开始',
          sensitive: true,
        ),
      ],
    );

    expect(find.text('预计经期开始'), findsNothing);
    expect(find.text('健康 · 需解锁'), findsOneWidget);
  });

  testWidgets('金额被全局隐私开关遮蔽', (tester) async {
    await pump(
      tester,
      moneyMasked: true,
      events: [
        event(
          id: 'm1',
          module: TimelineModule.money,
          nature: TimelineNature.fact,
          title: '午餐',
          amountMinor: -3800,
        ),
      ],
    );
    // 事实默认折叠，展开后看金额。
    await tester.tap(find.text('已发生 1'));
    await tester.pumpAndSettle();
    expect(find.text('••••'), findsOneWidget);
    expect(find.textContaining('38.00'), findsNothing);
  });

  testWidgets('健康那一路失败：其余照常，页面上只多一行重试', (tester) async {
    await pump(
      tester,
      failHealth: true,
      events: [
        event(
          id: 'm1',
          module: TimelineModule.money,
          nature: TimelineNature.commitment,
          title: '房贷自动记账',
        ),
      ],
    );

    expect(find.text('房贷自动记账'), findsOneWidget);
    expect(find.text('健康读取失败'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
  });

  testWidgets('没有事件时给空态，不伪造内容', (tester) async {
    await pump(tester, events: const []);
    expect(find.text('这段时间没有安排'), findsOneWidget);
  });
  testWidgets('回顾：按月汇总事实，只出现「已经发生」的那几项', (tester) async {
    await pump(
      tester,
      events: [
        event(
          id: 'm1',
          module: TimelineModule.money,
          nature: TimelineNature.fact,
          kind: 'transaction',
          title: '午餐',
          amountMinor: -3800,
          day: DateTime.utc(2026, 10, 18),
        ),
        event(
          id: 'a1',
          module: TimelineModule.action,
          nature: TimelineNature.fact,
          kind: 'todoCompleted',
          title: '写周报',
          day: DateTime.utc(2026, 10, 17),
        ),
        // 预测与承诺都不该出现在回顾里。
        event(
          id: 'p1',
          module: TimelineModule.health,
          nature: TimelineNature.prediction,
          kind: 'health.predictedPeriod',
          title: '预计经期开始',
          day: DateTime.utc(2026, 10, 20),
        ),
        event(
          id: 'c1',
          module: TimelineModule.money,
          nature: TimelineNature.commitment,
          kind: 'commitment.auto_posting',
          title: '房贷自动记账',
          amountMinor: -800000,
          day: DateTime.utc(2026, 10, 25),
        ),
      ],
    );

    await tester.tap(find.text('回顾'));
    await tester.pumpAndSettle();
    expect(find.text('本月发生了什么'), findsOneWidget);
    expect(find.textContaining('支出'), findsWidgets);
    // 承诺与预测都不在。
    expect(find.text('房贷自动记账'), findsNothing);
    expect(find.text('预计经期开始'), findsNothing);
    // 有内容的两天各一行。
    expect(find.text('10/18'), findsOneWidget);
    expect(find.text('10/17'), findsOneWidget);
  });

  testWidgets('回顾为空时直说「只包含已经发生的事」', (tester) async {
    await pump(
      tester,
      events: [
        event(
          id: 'c1',
          module: TimelineModule.money,
          nature: TimelineNature.commitment,
          title: '房贷自动记账',
        ),
      ],
    );

    await tester.tap(find.text('回顾'));
    await tester.pumpAndSettle();
    expect(find.textContaining('回顾只包含已经发生的事'), findsOneWidget);
  });
}

class _Unlocked extends AuthSessionController {
  @override
  AuthSession build() => const AuthSession(
    userId: 'user-1',
    isUnlocked: true,
    unlockedAt: null,
  );
}

class _Sensitive extends SensitiveAccessController {
  _Sensitive({required this.verified});

  final bool verified;

  @override
  SensitiveAccessSession build() => verified
      ? SensitiveAccessSession(
          ttlOption: SensitiveAccessTtlOption.defaultOption,
          verifiedAt: DateTime.now().toUtc(),
        )
      : const SensitiveAccessSession.locked();
}

class _FixedScope extends TimelineScopeController {
  @override
  TimelineSelection build() => TimelineSelection(
    anchor: DateTime.utc(2026, 10, 18),
    scope: TimelineScope.week,
  );
}
