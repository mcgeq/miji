import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miji/core/presentation/components/app_palette_picker.dart';
import 'package:miji/core/theme/app_palette.dart';
import 'package:miji/core/theme/app_palette_providers.dart';
import 'package:miji/core/theme/app_theme.dart';

void main() {
  Future<ProviderContainer> pumpPicker(WidgetTester tester) async {
    // 卡片铺 3/4 列，用默认 800×600 会宽到 4 列；钉一个手机视口，
    // 顺带覆盖窄屏 3 列那条分支。
    tester.view.physicalSize = const Size(420, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light(AppPalettes.defaultId),
          home: const Scaffold(body: AppPalettePicker()),
        ),
      ),
    );
    await tester.pump();
    return ProviderScope.containerOf(
      tester.element(find.byType(AppPalettePicker)),
    );
  }

  /// 卡片内的名字（排除头部右侧那枚「当前配色」文字）。
  Finder tileName(String paletteId) => find.descendant(
    of: find.byKey(paletteTileKey(paletteId)),
    matching: find.text(AppPalettes.byId(paletteId).name),
  );

  testWidgets('九套配色全列出来，当前那套标成选中', (tester) async {
    await pumpPicker(tester);

    for (final palette in AppPalettes.all) {
      expect(
        find.byKey(paletteTileKey(palette.id)),
        findsOneWidget,
        reason: '${palette.id} 没出现在选择器里',
      );
      expect(
        tileName(palette.id),
        findsOneWidget,
        reason: '${palette.id} 的卡片没显示名字',
      );
    }

    // 头部右侧和下方说明都跟着当前选中项走。
    final selected = AppPalettes.byId(AppPalettes.defaultId);
    expect(find.text(selected.name), findsNWidgets(2), reason: '头部 + 卡片各一处');
    expect(find.text(selected.tagline), findsOneWidget);

    // 只有默认那套右上角有勾。
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
  });

  testWidgets('点一张卡就切换，说明文案同步更新', (tester) async {
    final container = await pumpPicker(tester);
    expect(container.read(themePaletteIdProvider), AppPalettes.defaultId);

    await tester.tap(find.byKey(paletteTileKey('celadon')));
    await tester.pump();

    expect(container.read(themePaletteIdProvider), 'celadon');
    expect(find.text(AppPalettes.byId('celadon').tagline), findsOneWidget);
    // 勾挪到青瓷那张，默认那张不再有。
    expect(
      find.descendant(
        of: find.byKey(paletteTileKey('celadon')),
        matching: find.byIcon(Icons.check_circle_rounded),
      ),
      findsOneWidget,
    );
  });

  testWidgets('再点当前那套不会反复刷状态', (tester) async {
    final container = await pumpPicker(tester);
    final before = container.read(themePaletteIdProvider);

    await tester.tap(find.byKey(paletteTileKey(before)));
    await tester.pump();

    // 同一个 id 直接 return：否则每点一次都要重放一遍 420ms 主题过渡。
    expect(container.read(themePaletteIdProvider), before);
  });

  testWidgets('挤到 200 逻辑宽也不溢出，列数退到 2', (tester) async {
    // 卡片里的三色点是定宽内容，容器一窄就会顶破 Row。宁可等比缩小 + 退列，
    // 也不要画黄黑溢出条（曾在这种宽度下实测到 17px 溢出）。
    tester.view.physicalSize = const Size(200, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light(AppPalettes.defaultId),
          home: const Scaffold(
            body: Padding(
              padding: EdgeInsets.all(16),
              child: AppPalettePicker(),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    for (final palette in AppPalettes.all) {
      expect(find.byKey(paletteTileKey(palette.id)), findsOneWidget);
    }
    // 200 − 32(padding) = 168 宽；2 列、间距 8 → 每张 80。
    expect(
      tester.getSize(find.byKey(paletteTileKey('ink'))).width,
      closeTo(80, 0.5),
    );
  });

  testWidgets('未知存档退回默认，不会抛异常', (tester) async {
    // SharedPreferences 在单测里没有实现，控制器读写都会走进 catch 分支 ——
    // 正好验证「存储不可用时配色仍是默认值」。
    final container = await pumpPicker(tester);
    container.read(themePaletteIdProvider.notifier).select('not-a-palette');
    await tester.pump();
    expect(container.read(themePaletteIdProvider), AppPalettes.defaultId);
  });
}
