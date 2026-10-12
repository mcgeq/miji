import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miji/core/auth/domain/sensitive_access_ttl_option.dart';
import 'package:miji/core/preferences/domain/user_preferences_entity.dart';
import 'package:miji/core/preferences/providers/preferences_providers.dart';
import 'package:miji/features/home/application/home_preference_providers.dart';
import 'package:miji/features/home/domain/home_block.dart';

UserPreferencesEntity prefs({
  String? visibility,
  String? order,
  String? layoutMode,
  bool? pagerTabs,
}) {
  final now = DateTime.utc(2026, 10, 12);
  return UserPreferencesEntity(
    userId: 'u1',
    themeMode: AppThemeModePreference.system,
    sensitiveAccessTtl: SensitiveAccessTtlOption.tenMinutes,
    homeBlockVisibility: visibility,
    homeBlockOrder: order,
    homeLayoutMode: layoutMode ?? 'pager',
    homePagerTabs: pagerTabs ?? false,
    createdAt: now,
    updatedAt: now,
  );
}

Future<ProviderContainer> containerWith(UserPreferencesEntity value) async {
  final container = ProviderContainer(
    overrides: [
      currentUserPreferencesProvider.overrideWith((ref) async => value),
    ],
  );
  addTearDown(container.dispose);
  // 预解析 future，让下游同步 provider 读到已加载的值。
  await container.read(currentUserPreferencesProvider.future);
  return container;
}

void main() {
  test('layout provider reads stored layout', () async {
    final container = await containerWith(
      prefs(visibility: '{"action.habit":false}'),
    );
    final layout = container.read(homeBlockLayoutProvider);
    expect(layout.isVisible(HomeBlockId.actionHabit), isFalse);
    expect(layout.isVisible(HomeBlockId.actionTodo), isTrue);
  });

  test('health block defaults on when nothing stored', () async {
    final container = await containerWith(prefs());
    expect(container.read(homeShowHealthStripProvider), isTrue);
  });

  test('layout mode defaults to pager, pager tabs default off', () async {
    final container = await containerWith(prefs());
    expect(container.read(homeLayoutModeProvider), HomeLayoutMode.pager);
    expect(container.read(homePagerTabsProvider), isFalse);
  });

  test('explicit list mode and pager tabs are honored', () async {
    final container = await containerWith(
      prefs(layoutMode: 'list', pagerTabs: true),
    );
    expect(container.read(homeLayoutModeProvider), HomeLayoutMode.list);
    expect(container.read(homePagerTabsProvider), isTrue);
  });

  test('block visibility overrides health block', () async {
    final container = await containerWith(
      prefs(visibility: '{"health.cycle":false}'),
    );
    expect(container.read(homeShowHealthStripProvider), isFalse);
  });
}
