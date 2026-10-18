import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miji/core/router/app_module_nav.dart';

/// 面板清单（二级路由）是外壳、页面、选择器三处共用的唯一真相。
/// 这里把它钉住：清单本身、旧 id 的兼容、落点判定、会话态记忆。
void main() {
  group('面板清单', () {
    test('三个模块的面板数与默认面板', () {
      expect(bookkeepingModuleNav.sections, hasLength(9));
      expect(bookkeepingModuleNav.defaultSectionId, 'transactions');
      expect(bookkeepingModuleNav.sections.map((section) => section.label), [
        '流水',
        '账户',
        '预算',
        '统计',
        '分类',
        '分期',
        '自动记账',
        '提醒',
        '时薪',
      ]);

      expect(gtdModuleNav.sections, hasLength(5));
      expect(gtdModuleNav.defaultSectionId, 'today');

      expect(healthModuleNav.sections, hasLength(4));
      expect(healthModuleNav.defaultSectionId, 'today');
    });

    test('id 与 label 一一对应，没有重名 id', () {
      for (final spec in appModuleNavSpecs) {
        final ids = spec.sections.map((section) => section.id).toSet();
        expect(ids.length, spec.sections.length, reason: '${spec.id} 有重复 id');
        for (final section in spec.sections) {
          expect(section.label.trim(), isNotEmpty);
        }
      }
    });
  });

  group('解析 ?section=', () {
    test('合法 id 原样返回', () {
      expect(bookkeepingModuleNav.resolveSectionId('budgets'), 'budgets');
      expect(gtdModuleNav.resolveSectionId('habits'), 'habits');
      expect(healthModuleNav.resolveSectionId('trends'), 'trends');
    });

    test('旧的 more 仍然接受，落到流水', () {
      expect(bookkeepingModuleNav.resolveSectionId('more'), 'transactions');
    });

    test('空值与非法值退到默认面板，不抛错', () {
      expect(bookkeepingModuleNav.resolveSectionId(null), 'transactions');
      expect(bookkeepingModuleNav.resolveSectionId(''), 'transactions');
      expect(bookkeepingModuleNav.resolveSectionId('nope'), 'transactions');
      expect(healthModuleNav.resolveSectionId('nope'), 'today');
    });

    test('面板下标与地址', () {
      expect(bookkeepingModuleNav.indexOf('statistics'), 3);
      expect(bookkeepingModuleNav.indexOf('lifeEnergy'), 8);
      expect(bookkeepingModuleNav.indexOf('nope'), 0);
      expect(
        bookkeepingModuleNav.uriFor('budgets').toString(),
        '/app/bookkeeping?section=budgets',
      );
      expect(gtdModuleNav.uriFor(null).toString(), '/app/gtd?section=today');
    });
  });

  group('按地址找模块', () {
    test('根地址落到模块，子页面只在「归属」查询里命中', () {
      expect(appModuleNavSpecForPath('/app/bookkeeping')?.id, 'bookkeeping');
      expect(appModuleNavSpecForPath('/app/gtd'), isNotNull);
      // 子页面不是模块根：底栏此时该退回模块根，而不是弹选择器。
      expect(appModuleNavSpecForPath('/app/gtd/plans/create'), isNull);
      expect(appModuleNavSpecForLocation('/app/gtd/plans')?.id, 'gtd');
    });

    test('子页面不算模块根（再点底栏应退回模块根，而不是弹选择器）', () {
      expect(appModuleNavSpecForPath('/app/gtd/plans/create'), isNull);
      expect(gtdModuleNav.owns('/app/gtd/plans'), isTrue);
      expect(gtdModuleNav.isRootOf('/app/gtd/plans'), isFalse);
    });

    test('首页与设置没有面板这层', () {
      expect(appModuleNavSpecForPath('/app/home'), isNull);
      expect(appModuleNavSpecForPath('/app/settings'), isNull);
      expect(appModuleNavSpecForLocation('/app/settings/security'), isNull);
    });
  });

  group('后端落点判定', () {
    test('不在模块里：跳到记忆的面板；没记忆就用默认面板', () {
      expect(
        resolveModuleEntry(
          spec: bookkeepingModuleNav,
          currentLocation: '/app/home',
          rememberedSectionId: 'accounts',
        ),
        '/app/bookkeeping?section=accounts',
      );
      expect(
        resolveModuleEntry(
          spec: bookkeepingModuleNav,
          currentLocation: '/app/home',
        ),
        '/app/bookkeeping?section=transactions',
      );
    });

    test('已经在模块根上：返回 null，调用方应当弹选择器', () {
      expect(
        resolveModuleEntry(
          spec: bookkeepingModuleNav,
          currentLocation: '/app/bookkeeping',
        ),
        isNull,
      );
    });

    test('在模块的子页面里：退回模块根（带记忆的面板）', () {
      expect(
        resolveModuleEntry(
          spec: gtdModuleNav,
          currentLocation: '/app/gtd/plans/create',
          rememberedSectionId: 'habits',
        ),
        '/app/gtd?section=habits',
      );
    });
  });

  group('会话态：上次停在哪个面板', () {
    test('从模块地址拍快照，非模块地址不动它', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final last = container.read(appModuleLastSectionProvider.notifier);

      last.rememberUri(Uri.parse('/app/bookkeeping?section=accounts'));
      expect(last.sectionOf('bookkeeping'), 'accounts');

      // 非法 / 缺失 section 都归一到默认面板，避免记住一个不存在的面板。
      last.rememberUri(Uri.parse('/app/bookkeeping'));
      expect(last.sectionOf('bookkeeping'), 'transactions');
      last.rememberUri(Uri.parse('/app/health?section=nope'));
      expect(last.sectionOf('health'), 'today');

      // 首页 / 设置没有面板：不该被写进记忆。
      last.rememberUri(Uri.parse('/app/home'));
      last.rememberUri(Uri.parse('/app/settings/appearance'));
      expect(container.read(appModuleLastSectionProvider).keys, [
        'bookkeeping',
        'health',
      ]);
    });

    test('同一个面板重复写入不触发状态更新', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final last = container.read(appModuleLastSectionProvider.notifier);

      last.remember('gtd', 'tasks');
      final before = container.read(appModuleLastSectionProvider);
      last.remember('gtd', 'tasks');
      expect(
        identical(before, container.read(appModuleLastSectionProvider)),
        isTrue,
      );
    });
  });
}
