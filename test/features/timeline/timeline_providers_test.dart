import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:miji/core/auth/application/auth_session_controller.dart';
import 'package:miji/core/auth/domain/auth_session.dart';
import 'package:miji/features/timeline/application/timeline_providers.dart';
import 'package:miji/features/timeline/domain/timeline_event.dart';

/// 聚合层的两条硬要求：
/// 1. 四路数据合到一起，按窗口切成天；
/// 2. **某一路失败时，其余三路照常出结果**，只记一条失败记录。
void main() {
  final anchor = DateTime.utc(2026, 10, 18);

  TimelineEvent event({
    required String id,
    required DateTime day,
    required TimelineModule module,
    TimelineNature nature = TimelineNature.fact,
    String title = '事件',
  }) {
    return TimelineEvent(
      id: id,
      occurredOn: day,
      module: module,
      nature: nature,
      kind: 'test',
      title: title,
    );
  }

  ProviderContainer container({
    required List<TimelineEvent> money,
    required List<TimelineEvent> todo,
    required List<TimelineEvent> habit,
    required List<TimelineEvent> health,
    List<TimelineEvent> lifeEnergy = const [],
    bool failHealth = false,
  }) {
    final container = ProviderContainer(
      overrides: [
        // 会话：聚合只对已解锁的用户取数。
        authSessionControllerProvider.overrideWith(() => _UnlockedSession()),
        timelineScopeProvider.overrideWith(_FixedScope.new),
        timelineMoneyReaderProvider.overrideWithValue(
          (ref, window) async => money,
        ),
        timelineTodoReaderProvider.overrideWithValue(
          (ref, window) async => todo,
        ),
        timelineHabitReaderProvider.overrideWithValue(
          (ref, window) async => habit,
        ),
        timelineHealthReaderProvider.overrideWithValue((ref, window) async {
          if (failHealth) {
            throw StateError('健康模块读不出来');
          }
          return health;
        }),
        timelineLifeEnergyReaderProvider.overrideWithValue(
          (ref, window) async => lifeEnergy,
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('四路合到一起，按天分组', () async {
    final c = container(
      money: [event(id: 'm1', day: anchor, module: TimelineModule.money)],
      todo: [
        event(
          id: 'a1',
          day: anchor,
          module: TimelineModule.action,
          nature: TimelineNature.commitment,
        ),
      ],
      habit: [event(id: 'h1', day: anchor, module: TimelineModule.action)],
      health: [event(id: 'x1', day: anchor, module: TimelineModule.health)],
    );

    final result = await c.read(timelineProvider.future);
    expect(result.failures, isEmpty);
    final day = result.timeline.days.single;
    expect(day.commitments, hasLength(1));
    expect(day.facts, hasLength(3));
  });

  test('健康那一路失败：其余三路照常，失败被单独记下来', () async {
    final c = container(
      money: [event(id: 'm1', day: anchor, module: TimelineModule.money)],
      todo: [
        event(
          id: 'a1',
          day: anchor,
          module: TimelineModule.action,
          nature: TimelineNature.commitment,
        ),
      ],
      habit: const [],
      health: const [],
      failHealth: true,
    );

    final result = await c.read(timelineProvider.future);
    expect(result.hasFailures, isTrue);
    expect(result.failedModuleNamed(TimelineModule.health), isNotNull);
    // 关键：时间线本身没有变成错误页。
    expect(result.timeline.days.single.facts, hasLength(1));
    expect(result.timeline.days.single.commitments, hasLength(1));
  });

  test('未解锁时什么都不取；窗口仍按选中范围给出', () async {
    final c = ProviderContainer(
      overrides: [
        authSessionControllerProvider.overrideWith(() => _LockedSession()),
        timelineScopeProvider.overrideWith(_FixedScope.new),
        timelineMoneyReaderProvider.overrideWithValue(
          (ref, window) async => fail('未解锁不该去读数据'),
        ),
        timelineTodoReaderProvider.overrideWithValue(
          (ref, window) async => const [],
        ),
        timelineHabitReaderProvider.overrideWithValue(
          (ref, window) async => const [],
        ),
        timelineHealthReaderProvider.overrideWithValue(
          (ref, window) async => const [],
        ),
        timelineLifeEnergyReaderProvider.overrideWithValue(
          (ref, window) async => const [],
        ),
      ],
    );
    addTearDown(c.dispose);

    final result = await c.read(timelineProvider.future);
    expect(result.timeline.days, isEmpty);
    final window = c.read(timelineWindowProvider);
    expect(window.start, DateTime.utc(2026, 10, 12));
    expect(window.end, DateTime.utc(2026, 10, 18));
  });
  test('时薪那一路：薪水变化与冷却结束都能进来', () async {
    final c = container(
      money: const [],
      todo: const [],
      habit: const [],
      health: const [],
      lifeEnergy: [
        event(
          id: 'salary:segment:1',
          day: anchor,
          module: TimelineModule.lifeEnergy,
        ),
      ],
    );

    final result = await c.read(timelineProvider.future);
    expect(result.failures, isEmpty);
    expect(result.timeline.days.single.facts, hasLength(1));
    expect(
      result.timeline.days.single.facts.single.module,
      TimelineModule.lifeEnergy,
    );
  });
}

class _UnlockedSession extends AuthSessionController {
  @override
  AuthSession build() =>
      const AuthSession(userId: 'user-1', isUnlocked: true, unlockedAt: null);
}

class _LockedSession extends AuthSessionController {
  @override
  AuthSession build() => const AuthSession.locked();
}

/// 固定在 10/18 这一周，避免用例依赖「今天」。
class _FixedScope extends TimelineScopeController {
  @override
  TimelineSelection build() => TimelineSelection(
    anchor: DateTime.utc(2026, 10, 18),
    scope: TimelineScope.week,
  );
}
