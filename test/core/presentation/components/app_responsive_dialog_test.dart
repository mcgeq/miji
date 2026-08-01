import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miji/core/presentation/components/app_responsive_dialog.dart';
import 'package:miji/core/theme/app_theme.dart';

void main() {
  testWidgets(
    'expanded compact sheet keeps a stable frame and visible actions when keyboard opens',
    (tester) async {
      addTearDown(tester.view.reset);
      tester.view.physicalSize = const Size(390, 800);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = FakeViewPadding.zero;

      await _pumpHost(tester);
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      final beforeKeyboard = _measureSheet(tester);

      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      await tester.pumpAndSettle();

      final afterKeyboard = _measureSheet(tester);

      expect(afterKeyboard.outerTopLeft.dy, beforeKeyboard.outerTopLeft.dy);
      expect(afterKeyboard.height, beforeKeyboard.height);
      expect(afterKeyboard.cancelBottom, lessThan(800 - 280));
    },
  );

  testWidgets(
    'expanded compact sheet scrolls the focused bottom field above keyboard',
    (tester) async {
      addTearDown(tester.view.reset);
      tester.view.physicalSize = const Size(390, 800);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = FakeViewPadding.zero;

      await _pumpHost(tester);
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -900),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('notes-field')));
      await tester.pump();

      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      await tester.pumpAndSettle();

      final visibleBottom = _visibleContentBottom(tester);
      final notesBottom = tester
          .getBottomLeft(find.byKey(const Key('notes-field')))
          .dy;

      expect(notesBottom, lessThanOrEqualTo(visibleBottom));
    },
  );
}

Future<void> _pumpHost(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: Builder(
          builder: (context) {
            return Center(
              child: ElevatedButton(
                onPressed: () {
                  showAppResponsiveDialog<void>(
                    context: context,
                    expandCompactSheet: true,
                    builder: (context) {
                      return AppDialogScaffold(
                        title: '记支出',
                        body: const Column(
                          children: [
                            TextField(key: Key('amount-field')),
                            SizedBox(height: 900),
                            TextField(key: Key('notes-field')),
                          ],
                        ),
                        actions: [
                          TextButton(onPressed: null, child: Text('取消')),
                        ],
                      );
                    },
                  );
                },
                child: const Text('open'),
              ),
            );
          },
        ),
      ),
    ),
  );
}

_MeasuredSheet _measureSheet(WidgetTester tester) {
  final sheetFinder = find.byType(AppDialogScaffold);
  final cancelFinder = find.text('取消');
  return _MeasuredSheet(
    outerTopLeft: tester.getTopLeft(sheetFinder),
    height: tester.getSize(sheetFinder).height,
    cancelBottom: tester.getBottomLeft(cancelFinder).dy,
  );
}

double _visibleContentBottom(WidgetTester tester) {
  final keyboardTop = 800 - tester.view.viewInsets.bottom;
  final footerTop = tester.getTopLeft(find.text('取消')).dy - 16;
  return footerTop < keyboardTop ? footerTop : keyboardTop;
}

class _MeasuredSheet {
  const _MeasuredSheet({
    required this.outerTopLeft,
    required this.height,
    required this.cancelBottom,
  });

  final Offset outerTopLeft;
  final double height;
  final double cancelBottom;
}
