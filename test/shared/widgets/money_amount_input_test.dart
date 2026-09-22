import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miji/shared/widgets/app_amount_field.dart';
import 'package:miji/shared/widgets/money_amount_input.dart';
import 'package:miji/shared/widgets/money_keypad.dart';

/// [MoneyAmountInput]：移动端停靠键盘 / 宽屏输入框 / 与 controller 同步。
void main() {
  testWidgets('docks the keypad on a narrow surface', (tester) async {
    final input = MoneyAmountInput(initialAmountMinor: 3850);
    addTearDown(input.dispose);

    await _pump(tester, input, width: 390);

    expect(find.byType(MoneyKeypad), findsOneWidget);
    expect(find.byType(AppAmountField), findsNothing);
    // 初始金额已经写好，便于编辑场景直接看到。
    expect(input.controller.text, '38.50');

    await tester.tap(find.text('7'));
    await tester.pumpAndSettle();
    // 编辑态第一次按键覆盖原值。
    expect(input.controller.text, '7');
  });

  testWidgets('uses a normal field on a wide surface', (tester) async {
    final input = MoneyAmountInput(initialAmountMinor: 3850);
    addTearDown(input.dispose);

    await _pump(tester, input, width: 900);

    expect(find.byType(AppAmountField), findsOneWidget);
    expect(find.byType(MoneyKeypad), findsNothing);
  });

  testWidgets('yields to the system keyboard when it is up', (tester) async {
    final input = MoneyAmountInput();
    addTearDown(input.dispose);

    await _pump(tester, input, width: 390, systemKeyboardInset: 300);

    expect(find.byType(MoneyKeypad), findsNothing);
    expect(find.byType(AppAmountField), findsOneWidget);
  });

  testWidgets('supports chained calculation and writes the result back', (
    tester,
  ) async {
    final input = MoneyAmountInput();
    addTearDown(input.dispose);

    await _pump(tester, input, width: 390);

    for (final key in ['3', '8', '＋', '1', '2', '=']) {
      await tester.tap(find.text(key));
      await tester.pumpAndSettle();
    }

    expect(input.controller.text, '50.00');
    expect(input.isEmpty, isFalse);
  });

  testWidgets('clear resets both the calculator and the controller', (
    tester,
  ) async {
    final input = MoneyAmountInput(initialAmountMinor: 100);
    addTearDown(input.dispose);

    await _pump(tester, input, width: 390);
    expect(input.controller.text, '1.00');

    input.clear();
    await tester.pumpAndSettle();

    expect(input.controller.text, '');
    expect(input.isEmpty, isTrue);
  });
}

Future<void> _pump(
  WidgetTester tester,
  MoneyAmountInput input, {
  required double width,
  double systemKeyboardInset = 0,
}) async {
  tester.view.physicalSize = Size(width * 3, 900 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(viewInsets: EdgeInsets.only(bottom: systemKeyboardInset)),
        child: child!,
      ),
      home: Scaffold(
        resizeToAvoidBottomInset: false,
        body: _Host(input: input),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _Host extends StatefulWidget {
  const _Host({required this.input});

  final MoneyAmountInput input;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  @override
  Widget build(BuildContext context) {
    final input = widget.input;
    final dock = input.shouldDock(context);
    return HeaderFooterLayout(
      dock: dock ? input.buildDock(context, onChanged: () {}) : null,
      body: dock ? const SizedBox.shrink() : input.buildField(),
    );
  }
}

/// 用 Column + Expanded 模拟 AppDialogScaffold 的停靠布局。
class HeaderFooterLayout extends StatelessWidget {
  const HeaderFooterLayout({super.key, required this.body, this.dock});

  final Widget body;
  final Widget? dock;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(child: SingleChildScrollView(child: body)),
        ?dock,
      ],
    );
  }
}
