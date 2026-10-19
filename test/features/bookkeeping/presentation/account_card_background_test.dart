import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miji/core/attachments/attachment_providers.dart';
import 'package:miji/core/attachments/attachment_store.dart';
import 'package:miji/features/bookkeeping/domain/money_account_entity.dart';
import 'package:miji/features/bookkeeping/presentation/accounts/account_form_dialog.dart';
import 'package:miji/features/bookkeeping/presentation/accounts/components/account_card_background.dart';

MoneyAccountEntity _entity({
  String? backgroundStyle,
  String? backgroundColor,
  String? backgroundImage,
}) {
  final now = DateTime.utc(2026, 1, 2);
  return MoneyAccountEntity(
    id: 'a1',
    userId: 'u1',
    name: '测试账户',
    type: MoneyAccountType.cash,
    balanceMinor: 1234567,
    initialBalanceMinor: 0,
    creditLimitMinor: null,
    postedDebtMinor: null,
    frozenCreditMinor: null,
    statementDay: null,
    budgetCycleStartDay: null,
    repaymentDay: null,
    autoRepaymentReminderEnabled: false,
    currencyCode: 'CNY',
    isShared: false,
    isVirtual: false,
    color: null,
    icon: null,
    backgroundStyle: backgroundStyle,
    backgroundColor: backgroundColor,
    backgroundImage: backgroundImage,
    isActive: true,
    isDeleted: false,
    createdAt: now,
    updatedAt: now,
  );
}

Future<File> _writeTempImage(AttachmentStore store, String userId) async {
  // 标准 1x1 透明 PNG（base64 内嵌，避免手写字节无效）。
  final bytes = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAC'
    'hwGA60e6kgAAAABJRU5ErkJggg==',
  );
  final dir = await Directory.systemTemp.createTemp('acct_card_test');
  final file = File('${dir.path}${Platform.pathSeparator}bg.png')
    ..writeAsBytesSync(bytes);
  final relative = await store.importFile(
    userId: userId,
    sourcePath: file.path,
  );
  return store.fileFor(relative);
}

void main() {
  late Directory tempRoot;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('acct_card_test');
  });

  tearDown(() async {
    if (await tempRoot.exists()) {
      await tempRoot.delete(recursive: true);
    }
  });

  AttachmentStore storeWithTempRoot() =>
      AttachmentStore(rootDirectory: () async => tempRoot);

  testWidgets(
    'image background renders inside an unbounded ListView',
    (tester) async {
      final store = storeWithTempRoot();
      // testWidgets 跑在 FakeAsync zone 里，真实文件 IO 永远完不成 ——
      // 准备工作必须包进 runAsync。
      late final String stored;
      await tester.runAsync(() async {
        final file = await _writeTempImage(store, 'u1');
        stored = await store.existingFile(file.path).then((f) => f!.path);
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [attachmentStoreProvider.overrideWithValue(store)],
          child: MaterialApp(
            home: Scaffold(
              body: ListView(
                children: [
                  AccountCardBackground(
                    account: _entity(
                      backgroundStyle: 'image',
                      backgroundColor: '#BAE6FD',
                      backgroundImage: stored,
                    ),
                    child: const Text('余额内容'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      // 文件解析是真实 IO，在 FakeAsync 里不会完成；这里只验证布局不被
      // 无界高度撑爆（回归点：StackFit.expand 曾把整个列表搞崩）。
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('余额内容'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  testWidgets('missing image file degrades to color card', (tester) async {
    final store = storeWithTempRoot();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [attachmentStoreProvider.overrideWithValue(store)],
        child: MaterialApp(
          home: Scaffold(
            body: ListView(
              children: [
                AccountCardBackground(
                  account: _entity(
                    backgroundStyle: 'image',
                    backgroundColor: '#BAE6FD',
                    backgroundImage: 'u1/209901/missing.png',
                  ),
                  child: const Text('余额内容'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('余额内容'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'edit dialog with an image background stays on screen',
    (tester) async {
      // 复现用户场景：编辑账户 → 预览卡带图片背景。
      // 修复前 StackFit.expand 在弹窗的可滚动体里同样抛无限高度，
      // 整张表单一起消失。
      final store = storeWithTempRoot();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [attachmentStoreProvider.overrideWithValue(store)],
          child: MaterialApp(
            home: Scaffold(
              body: AccountFormDialog(
                account: _entity(
                  backgroundStyle: 'image',
                  backgroundColor: '#BAE6FD',
                  backgroundImage: 'u1/209901/missing.png',
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 标题、名称输入框、预览卡都在。
      expect(find.text('编辑账户'), findsOneWidget);
      expect(find.text('账户名称'), findsOneWidget);
      expect(find.text('测试账户'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
