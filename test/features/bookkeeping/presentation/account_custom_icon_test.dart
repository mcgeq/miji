import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miji/core/attachments/attachment_providers.dart';
import 'package:miji/core/attachments/attachment_store.dart';
import 'package:miji/features/bookkeeping/domain/money_account_entity.dart';
import 'package:miji/features/bookkeeping/presentation/accounts/account_form_dialog.dart';
import 'package:miji/features/bookkeeping/presentation/accounts/account_icon_catalog.dart';

/// 同步返回（或返回 null）的附件仓库。
///
/// 为什么不能用真 `AttachmentStore`：`existingFile` 是真实的 dart:io 调用，
/// 而 `testWidgets` 跑在 FakeAsync zone 里，IO 永远完不成，FutureBuilder
/// 会一直停在等待态，断言就落不到渲染结果上。
class _ImmediateAttachmentStore extends AttachmentStore {
  _ImmediateAttachmentStore({required this.file})
    : super(rootDirectory: () async => file!.parent);

  final File? file;

  @override
  Future<File?> existingFile(String storedPath) async => file;
}

MoneyAccountEntity _entity({String? icon}) {
  final now = DateTime.utc(2026, 1, 2);
  return MoneyAccountEntity(
    id: 'a1',
    userId: 'u1',
    name: '招商银行',
    type: MoneyAccountType.bank,
    balanceMinor: 0,
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
    icon: icon,
    isActive: true,
    isDeleted: false,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  late Directory tempRoot;
  late File iconFile;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('acct_icon_test');
    iconFile = File(
      '${tempRoot.path}${Platform.pathSeparator}logo.png',
    )..writeAsBytesSync(
        base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAC'
          'hwGA60e6kgAAAABJRU5ErkJggg==',
        ),
      );
  });

  tearDown(() async {
    if (await tempRoot.exists()) {
      await tempRoot.delete(recursive: true);
    }
  });

  Widget host(Widget child, AttachmentStore store) {
    return ProviderScope(
      overrides: [attachmentStoreProvider.overrideWithValue(store)],
      child: MaterialApp(home: Scaffold(body: Center(child: child))),
    );
  }

  test('usesCustomImage 只认 file: 前缀的图标', () {
    expect(
      AccountIconView.usesCustomImage(_entity(icon: 'file:u1/2099/logo.png')),
      isTrue,
    );
    expect(AccountIconView.usesCustomImage(_entity(icon: 'credit_card')), isFalse);
    expect(AccountIconView.usesCustomImage(_entity()), isFalse);
  });

  test('卡片 logo 尺寸落在「比字形大、比槽位小」之间', () {
    // 42 = 铺满槽位（过大，用户反馈偏大），21 = 老的字形尺寸（过小）。
    expect(accountCardLogoSize, lessThan(42));
    expect(accountCardLogoSize, greaterThan(21));
  });

  testWidgets('自定义图标按 imageSize 绘制', (tester) async {
    final store = _ImmediateAttachmentStore(file: iconFile);
    await tester.pumpWidget(
      host(
        AccountIconView(
          account: _entity(icon: 'file:u1/2099/logo.png'),
          size: 21,
          imageSize: accountCardLogoSize,
        ),
        store,
      ),
    );
    await tester.pumpAndSettle();

    // 品牌 logo 不该被压成 21 的字形大小 —— 那是「小图 + 大壳」的观感来源。
    final image = tester.widget<Image>(find.byType(Image));
    expect(image.width, accountCardLogoSize);
    expect(image.height, accountCardLogoSize);
    expect(image.fit, BoxFit.contain);
    expect(tester.takeException(), isNull);
  });

  testWidgets('未指定 imageSize 时退回 size', (tester) async {
    final store = _ImmediateAttachmentStore(file: iconFile);
    await tester.pumpWidget(
      host(
        AccountIconView(
          account: _entity(icon: 'file:u1/2099/logo.png'),
          size: 20,
        ),
        store,
      ),
    );
    await tester.pumpAndSettle();

    final image = tester.widget<Image>(find.byType(Image));
    expect(image.width, 20);
    expect(tester.takeException(), isNull);
  });

  testWidgets('自定义图标文件丢失时回退类型字形', (tester) async {
    // 换设备后附件不同步：渲染层必须安静地退回默认图标，不能出破图。
    final store = _ImmediateAttachmentStore(file: null);
    await tester.pumpWidget(
      host(
        AccountIconView(
          account: _entity(icon: 'file:u1/2099/logo.png'),
          size: 21,
          imageSize: accountCardLogoSize,
        ),
        store,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Image), findsNothing);
    final icon = tester.widget<Icon>(find.byType(Icon));
    expect(icon.size, 21);
    expect(tester.takeException(), isNull);
  });

  testWidgets('编辑弹窗识别并渲染自定义图标', (tester) async {
    final store = _ImmediateAttachmentStore(file: iconFile);
    await tester.pumpWidget(
      host(
        AccountFormDialog(account: _entity(icon: 'file:u1/2099/logo.png')),
        store,
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('编辑账户'), findsOneWidget);
    expect(find.text('账户图标 · 自定义'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
