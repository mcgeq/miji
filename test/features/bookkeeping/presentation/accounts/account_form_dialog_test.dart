import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miji/features/bookkeeping/domain/money_account_entity.dart';
import 'package:miji/features/bookkeeping/presentation/accounts/account_form_dialog.dart';
import 'package:miji/shared/widgets/form_dropdown.dart';

void main() {
  testWidgets('credit account form returns budget cycle start day', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    AccountFormResult? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showDialog<AccountFormResult>(
                  context: context,
                  builder: (_) => const AccountFormDialog(),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, '账户名称'), '招行信用卡');
    await tester.tap(find.byType(FormDropdown<MoneyAccountType>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('信用卡').last);
    await tester.pumpAndSettle();

    expect(find.byType(FormDropdown<int>), findsNWidgets(3));
    expect(find.text('账单日'), findsOneWidget);
    expect(find.text('预算周期起始日'), findsOneWidget);
    expect(find.text('还款日'), findsOneWidget);

    await tester.tap(find.byTooltip('创建'));
    await tester.pumpAndSettle();

    expect(result?.draft?.type, MoneyAccountType.creditCard);
    expect(result?.draft?.statementDay, 1);
    expect(result?.draft?.repaymentDay, 10);
    expect(result?.draft?.budgetCycleStartDay, 1);
  });
}
