import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miji/core/presentation/components/app_bottom_sheet_keyboard_inset.dart';
import 'package:miji/core/presentation/components/app_filter_sheet.dart';
import 'package:miji/core/theme/app_theme.dart';
import 'package:miji/shared/widgets/app_text_field.dart';

/// 贴底面板的键盘避让：Flutter 的 showModalBottomSheet 默认不为键盘让位，
/// 面板贴底 + 内部有输入框时下面那截会被盖住。
void main() {
  const screenHeight = 844.0;
  const keyboardInset = 320.0;
  const keyboardTop = screenHeight - keyboardInset;

  Future<void> pumpHost(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(390 * 3, screenHeight * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(viewInsets: const EdgeInsets.only(bottom: keyboardInset)),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  useSafeArea: true,
                  builder: (_) => child,
                ),
                child: const Text('打开'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
  }

  testWidgets('lifts the sheet above the keyboard and caps its height', (
    tester,
  ) async {
    await pumpHost(
      tester,
      AppBottomSheetKeyboardInset(
        maxHeight: 560,
        child: Container(
          key: const ValueKey('content'),
          color: Colors.white,
          child: const SizedBox(height: 900, width: double.infinity),
        ),
      ),
    );

    final rect = tester.getRect(find.byKey(const ValueKey('content')));
    // 面板整体在键盘上方，且高度被压到可用空间。
    expect(rect.bottom, lessThanOrEqualTo(keyboardTop));
    expect(rect.height, lessThanOrEqualTo(keyboardTop));
    expect(rect.height, greaterThan(180));
  });

  testWidgets('keeps the content above the keyboard without a max height', (
    tester,
  ) async {
    await pumpHost(
      tester,
      AppBottomSheetKeyboardInset(
        child: Container(
          key: const ValueKey('content'),
          color: Colors.white,
          child: const SizedBox(height: 900, width: double.infinity),
        ),
      ),
    );

    final rect = tester.getRect(find.byKey(const ValueKey('content')));
    expect(rect.bottom, lessThanOrEqualTo(keyboardTop));
    expect(rect.height, lessThanOrEqualTo(keyboardTop));
  });

  testWidgets('filter sheet keeps its text fields above the keyboard', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390 * 3, screenHeight * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(viewInsets: const EdgeInsets.only(bottom: keyboardInset)),
          child: child!,
        ),
        home: Scaffold(
          body: AppFilterSheetTrigger(
            title: '高级筛选',
            children: [
              // 抽屉里的输入框：之前就是它被键盘盖住。
              AppTextField(
                controller: controller,
                hintText: '搜索备注',
                prefixIcon: const Icon(Icons.search_rounded),
              ),
              const SizedBox(height: 600),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('高级筛选'));
    await tester.pumpAndSettle();

    final field = tester.getRect(find.byType(TextField).last);
    expect(field.bottom, lessThanOrEqualTo(keyboardTop));
  });
}
