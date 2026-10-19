import 'package:flutter_test/flutter_test.dart';
import 'package:miji/features/bookkeeping/domain/money_account_entity.dart';
import 'package:miji/features/bookkeeping/presentation/accounts/account_icon_catalog.dart';

MoneyAccountEntity _entity({
  String? backgroundStyle,
  String? backgroundColor,
  String? backgroundImage,
  String? icon,
}) {
  final now = DateTime.utc(2026, 1, 2);
  return MoneyAccountEntity(
    id: 'a1',
    userId: 'u1',
    name: '测试账户',
    type: MoneyAccountType.cash,
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
    backgroundStyle: backgroundStyle,
    backgroundColor: backgroundColor,
    backgroundImage: backgroundImage,
    isActive: true,
    isDeleted: false,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('MoneyAccountBackgroundStyle.fromStorageValue', () {
    test('known values map to styles, unknown/null fall back to default', () {
      expect(
        MoneyAccountBackgroundStyle.fromStorageValue('color'),
        MoneyAccountBackgroundStyle.color,
      );
      // 兼容历史语义别名。
      expect(
        MoneyAccountBackgroundStyle.fromStorageValue('solid'),
        MoneyAccountBackgroundStyle.color,
      );
      expect(
        MoneyAccountBackgroundStyle.fromStorageValue('image'),
        MoneyAccountBackgroundStyle.image,
      );
      expect(
        MoneyAccountBackgroundStyle.fromStorageValue(null),
        MoneyAccountBackgroundStyle.defaultStyle,
      );
      expect(
        MoneyAccountBackgroundStyle.fromStorageValue('nonsense'),
        MoneyAccountBackgroundStyle.defaultStyle,
      );
    });
  });

  group('effectiveBackgroundStyle 降级链', () {
    test('image with missing file falls back to color when set', () {
      final entity = _entity(
        backgroundStyle: 'image',
        backgroundColor: '#BAE6FD',
        backgroundImage: 'user_1/202601/abc.jpg',
      );
      expect(
        entity.effectiveBackgroundStyle(backgroundImageExists: false),
        MoneyAccountBackgroundStyle.color,
      );
      expect(
        entity.effectiveBackgroundStyle(backgroundImageExists: true),
        MoneyAccountBackgroundStyle.image,
      );
    });

    test('image without color falls back to default', () {
      final entity = _entity(
        backgroundStyle: 'image',
        backgroundImage: 'user_1/202601/abc.jpg',
      );
      expect(
        entity.effectiveBackgroundStyle(backgroundImageExists: false),
        MoneyAccountBackgroundStyle.defaultStyle,
      );
    });

    test('image style with no path at all falls back through color', () {
      final entity = _entity(
        backgroundStyle: 'image',
        backgroundColor: '#BAE6FD',
      );
      expect(
        entity.effectiveBackgroundStyle(),
        MoneyAccountBackgroundStyle.color,
      );
    });

    test('color style without a color falls back to default', () {
      final entity = _entity(backgroundStyle: 'color');
      expect(
        entity.effectiveBackgroundStyle(),
        MoneyAccountBackgroundStyle.defaultStyle,
      );
    });

    test('fully set styles pass through untouched', () {
      expect(
        _entity(
          backgroundStyle: 'color',
          backgroundColor: '#BAE6FD',
        ).effectiveBackgroundStyle(),
        MoneyAccountBackgroundStyle.color,
      );
      expect(
        _entity().effectiveBackgroundStyle(),
        MoneyAccountBackgroundStyle.defaultStyle,
      );
    });
  });

  group('AccountIconCatalog', () {
    test('forName resolves catalog names and ignores unknown ones', () {
      expect(AccountIconCatalog.forName('diamond'), isNotNull);
      expect(AccountIconCatalog.forName('not_an_icon'), isNull);
      expect(AccountIconCatalog.forName(null), isNull);
      expect(AccountIconCatalog.forName(''), isNull);
    });

    test(
      'forAccount prefers the stored icon and falls back to type default',
      () {
        final custom = _entity(icon: 'diamond');
        expect(
          AccountIconCatalog.forAccount(custom),
          AccountIconCatalog.forName('diamond'),
        );

        // 现金类型的历史默认值也在目录里，能正常解析。
        expect(AccountIconCatalog.forName('payments'), isNotNull);

        // 库里躺着已移除的图标名时回退到类型默认，不渲染失败。
        final unknown = _entity(icon: 'removed_icon_name');
        final fallback = AccountIconCatalog.forAccount(unknown);
        expect(fallback, isNotNull);
        expect(
          fallback,
          isNot(AccountIconCatalog.forName('removed_icon_name')),
        );
      },
    );

    test('custom icon file: values round-trip and never parse as preset', () {
      const path = 'user_1/202601/icon-abc.svg';
      final name = AccountIconCatalog.customIconName(path);

      expect(AccountIconCatalog.isCustomIcon(name), isTrue);
      expect(AccountIconCatalog.customIconPath(name), path);
      // 'file:' 前缀不是合法的预置图标名，预置查找必须忽略它。
      expect(AccountIconCatalog.forName(name), isNull);
      // 预置图标名不是自定义图标。
      expect(AccountIconCatalog.isCustomIcon('diamond'), isFalse);
      expect(AccountIconCatalog.isCustomIcon(null), isFalse);
      expect(AccountIconCatalog.customIconPath('diamond'), isNull);
    });

    test('custom file: icons fall back to the type glyph via forAccount', () {
      final entity = _entity(
        icon: AccountIconCatalog.customIconName('user_1/202601/x.png'),
      );
      // forAccount 只认预置名；file: 值解析不出字形，
      // 渲染层（AccountIconView）负责回退类型默认。
      expect(
        AccountIconCatalog.forAccount(entity),
        AccountIconCatalog.forName('payments'),
      );
    });
  });
}
