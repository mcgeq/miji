import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:miji/core/attachments/attachment_providers.dart';
import 'package:miji/features/bookkeeping/domain/money_account_entity.dart';
import 'package:miji/features/bookkeeping/presentation/accounts/account_presentation_helpers.dart';

/// 图标目录里的一项。
class AccountIconEntry {
  const AccountIconEntry({required this.name, required this.iconData});

  /// 存库用的名称（Material 图标名，沿用既有 `icon` 列的口径）。
  final String name;

  final IconData iconData;
}

/// 图标分组，供选择器按类浏览。
class AccountIconGroup {
  const AccountIconGroup({required this.label, required this.entries});

  final String label;
  final List<AccountIconEntry> entries;
}

/// 账户图标目录。
///
/// `money_accounts.icon` 列从第一版就在存 Material 图标名，但 UI 一直没有
/// 选择入口，读侧也直接用类型默认图标 —— 这个目录让该字段真正生效。
///
/// 命名沿用 Material 图标名（如 `payments`），与历史数据、
/// `defaultAccountIconForType` 写入的值同口径；查不到的名字回退类型默认，
/// 所以存量数据、未来被移除的图标名都不会渲染失败。
abstract final class AccountIconCatalog {
  /// 支付与钱包。
  static const _payments = <AccountIconEntry>[
    AccountIconEntry(name: 'payments', iconData: Icons.payments_rounded),
    AccountIconEntry(
      name: 'account_balance_wallet',
      iconData: Icons.account_balance_wallet_rounded,
    ),
    AccountIconEntry(name: 'wallet', iconData: Icons.wallet_rounded),
    AccountIconEntry(name: 'credit_card', iconData: Icons.credit_card_rounded),
    AccountIconEntry(
      name: 'credit_score',
      iconData: Icons.credit_score_rounded,
    ),
    AccountIconEntry(
      name: 'card_giftcard',
      iconData: Icons.card_giftcard_rounded,
    ),
    AccountIconEntry(name: 'qr_code', iconData: Icons.qr_code_rounded),
    AccountIconEntry(
      name: 'qr_code_scanner',
      iconData: Icons.qr_code_scanner_rounded,
    ),
    AccountIconEntry(
      name: 'tap_and_play',
      iconData: Icons.tap_and_play_rounded,
    ),
  ];

  /// 银行与储蓄。
  static const _banking = <AccountIconEntry>[
    AccountIconEntry(
      name: 'account_balance',
      iconData: Icons.account_balance_rounded,
    ),
    AccountIconEntry(name: 'savings', iconData: Icons.savings_rounded),
    AccountIconEntry(name: 'paid', iconData: Icons.paid_rounded),
    AccountIconEntry(
      name: 'currency_exchange',
      iconData: Icons.currency_exchange_rounded,
    ),
    AccountIconEntry(name: 'percent', iconData: Icons.percent_rounded),
    AccountIconEntry(
      name: 'request_quote',
      iconData: Icons.request_quote_rounded,
    ),
    AccountIconEntry(
      name: 'receipt_long',
      iconData: Icons.receipt_long_rounded,
    ),
  ];

  /// 生活消费。
  static const _life = <AccountIconEntry>[
    AccountIconEntry(
      name: 'shopping_bag',
      iconData: Icons.shopping_bag_rounded,
    ),
    AccountIconEntry(
      name: 'shopping_cart',
      iconData: Icons.shopping_cart_rounded,
    ),
    AccountIconEntry(name: 'storefront', iconData: Icons.storefront_rounded),
    AccountIconEntry(name: 'restaurant', iconData: Icons.restaurant_rounded),
    AccountIconEntry(name: 'local_cafe', iconData: Icons.local_cafe_rounded),
    AccountIconEntry(name: 'fastfood', iconData: Icons.fastfood_rounded),
    AccountIconEntry(name: 'home', iconData: Icons.home_rounded),
    AccountIconEntry(name: 'roofing', iconData: Icons.roofing_rounded),
    AccountIconEntry(name: 'pets', iconData: Icons.pets_rounded),
    AccountIconEntry(
      name: 'fitness_center',
      iconData: Icons.fitness_center_rounded,
    ),
    AccountIconEntry(
      name: 'medical_services',
      iconData: Icons.medical_services_rounded,
    ),
    AccountIconEntry(name: 'school', iconData: Icons.school_rounded),
    AccountIconEntry(
      name: 'sports_esports',
      iconData: Icons.sports_esports_rounded,
    ),
    AccountIconEntry(name: 'movie', iconData: Icons.movie_rounded),
    AccountIconEntry(name: 'flight', iconData: Icons.flight_rounded),
  ];

  /// 交通与出行。
  static const _transport = <AccountIconEntry>[
    AccountIconEntry(
      name: 'directions_bus',
      iconData: Icons.directions_bus_rounded,
    ),
    AccountIconEntry(
      name: 'directions_subway',
      iconData: Icons.directions_subway_rounded,
    ),
    AccountIconEntry(
      name: 'directions_car',
      iconData: Icons.directions_car_rounded,
    ),
    AccountIconEntry(
      name: 'electric_bike',
      iconData: Icons.electric_bike_rounded,
    ),
    AccountIconEntry(name: 'two_wheeler', iconData: Icons.two_wheeler_rounded),
    AccountIconEntry(name: 'local_taxi', iconData: Icons.local_taxi_rounded),
    AccountIconEntry(name: 'ev_station', iconData: Icons.ev_station_rounded),
  ];

  /// 投资与保障。
  static const _invest = <AccountIconEntry>[
    AccountIconEntry(name: 'show_chart', iconData: Icons.show_chart_rounded),
    AccountIconEntry(
      name: 'candlestick_chart',
      iconData: Icons.candlestick_chart_rounded,
    ),
    AccountIconEntry(name: 'trending_up', iconData: Icons.trending_up_rounded),
    AccountIconEntry(name: 'pie_chart', iconData: Icons.pie_chart_rounded),
    AccountIconEntry(name: 'diamond', iconData: Icons.diamond_rounded),
    AccountIconEntry(
      name: 'health_and_safety',
      iconData: Icons.health_and_safety_rounded,
    ),
    AccountIconEntry(
      name: 'verified_user',
      iconData: Icons.verified_user_rounded,
    ),
  ];

  /// 其他。
  static const _misc = <AccountIconEntry>[
    AccountIconEntry(name: 'more_horiz', iconData: Icons.more_horiz_rounded),
    AccountIconEntry(name: 'chat', iconData: Icons.chat_bubble_rounded),
    AccountIconEntry(name: 'star', iconData: Icons.star_rounded),
    AccountIconEntry(name: 'favorite', iconData: Icons.favorite_rounded),
    AccountIconEntry(name: 'work', iconData: Icons.work_rounded),
    AccountIconEntry(name: 'groups', iconData: Icons.groups_rounded),
    AccountIconEntry(name: 'lightbulb', iconData: Icons.lightbulb_rounded),
  ];

  static const groups = <AccountIconGroup>[
    AccountIconGroup(label: '支付与钱包', entries: _payments),
    AccountIconGroup(label: '银行与储蓄', entries: _banking),
    AccountIconGroup(label: '生活消费', entries: _life),
    AccountIconGroup(label: '交通出行', entries: _transport),
    AccountIconGroup(label: '投资与保障', entries: _invest),
    AccountIconGroup(label: '其他', entries: _misc),
  ];

  // static final 而不是 const：const 集合不支持 for 元素展开分组。
  static final Map<String, IconData> _byName = <String, IconData>{
    for (final group in groups)
      for (final entry in group.entries) entry.name: entry.iconData,
  };

  /// 按存储名解析图标；查不到（存量数据、历史图标名）回退类型默认。
  static IconData? forName(String? name) {
    if (name == null || name.isEmpty) {
      return null;
    }
    return _byName[name];
  }

  /// 账户实际应显示的图标：icon 字段优先，回退类型默认。
  static IconData forAccount(MoneyAccountEntity account) {
    return forName(account.icon) ?? accountIconDataForType(account.type);
  }

  /// 自定义图标在 `icon` 列里的存储格式：`file:<附件相对路径>`。
  ///
  /// 不加列、不迁移 —— `icon` 本来就是自由文本，前缀区分两种来源：
  /// 无前缀 = Material 图标名（历史数据），`file:` = 用户自己的图片/SVG。
  /// 附件文件不参与同步，其他设备读不到文件时渲染层回退类型默认图标。
  static const customIconPrefix = 'file:';

  static bool isCustomIcon(String? name) =>
      name != null && name.startsWith(customIconPrefix);

  /// 自定义图标的附件相对路径；非自定义图标返回 null。
  static String? customIconPath(String? name) {
    if (!isCustomIcon(name)) {
      return null;
    }
    return name!.substring(customIconPrefix.length);
  }

  /// 打包成存储值。
  static String customIconName(String attachmentRelativePath) =>
      '$customIconPrefix$attachmentRelativePath';
}

/// 自定义品牌 logo 在「42 图标槽位」里的绘制边长。
///
/// 铺满 42 会把整个槽位占满、比旁边 21 的字形重一大截；退回 21 又变成
/// 「小图 + 大壳」的老问题。34 是折中值：四周各留 4，logo 依然清楚。
const double accountCardLogoSize = 34;

/// 账户图标的统一渲染入口：预置字形或用户自定义图片 / SVG。
///
/// 为什么不是返回 `IconData` 的函数：自定义图标是磁盘上的文件，解析是
/// 异步的，`IconData` 表达不了。所有展示位（账户卡、选择器、快速记账
/// chip、流水汇总）都画这个组件，保证同一账户在哪儿长得都一样；
/// 自定义文件读不到时静默回退类型默认字形，不渲染破图。
class AccountIconView extends ConsumerStatefulWidget {
  const AccountIconView({
    super.key,
    required this.account,
    required this.size,
    this.imageSize,
    this.color,
  });

  final MoneyAccountEntity account;

  /// 字形尺寸（与 `Icon(size:)` 同口径）。自定义图片未指定 [imageSize]
  /// 时也按此尺寸等比适配。
  final double size;

  /// 自定义图片 / SVG 的绘制边长，默认等于 [size]。
  ///
  /// 品牌 logo 通常自带透明底、本身就是一块完整图形，和需要浅底衬托的
  /// 字形图标不是一回事：调用方若提供了图标槽位（如 42 的方形块），
  /// 应把槽位边长传进来，让 logo 铺满槽位，而不是缩到字形大小。
  final double? imageSize;

  /// 字形着色；自定义图片不上色（用户自己的素材）。
  final Color? color;

  /// 该账户的图标是否为用户自定义图片 / SVG。
  ///
  /// 展示位据此决定要不要套「浅色圆角底壳」：底壳是给字形图标用的，
  /// 品牌 logo 套上会变成「小图 + 大壳」。
  static bool usesCustomImage(MoneyAccountEntity account) =>
      AccountIconCatalog.isCustomIcon(account.icon);

  @override
  ConsumerState<AccountIconView> createState() => _AccountIconViewState();
}

class _AccountIconViewState extends ConsumerState<AccountIconView> {
  Future<File?>? _resolveFuture;
  String? _resolvedFor;

  @override
  Widget build(BuildContext context) {
    final stored = widget.account.icon;
    if (!AccountIconCatalog.isCustomIcon(stored)) {
      return Icon(
        AccountIconCatalog.forAccount(widget.account),
        size: widget.size,
        color: widget.color,
      );
    }

    final path = AccountIconCatalog.customIconPath(stored);
    final store = ref.watch(attachmentStoreProvider);
    if (_resolvedFor != path) {
      _resolvedFor = path;
      _resolveFuture = store.existingFile(path!);
    }

    final imageSize = widget.imageSize ?? widget.size;

    return FutureBuilder<File?>(
      future: _resolveFuture,
      builder: (context, snapshot) {
        final file = snapshot.data;
        // 还没解析完 / 文件丢了：先用类型默认字形顶住，避免闪空块。
        if (file == null) {
          return Icon(
            accountIconDataForType(widget.account.type),
            size: widget.size,
            color: widget.color,
          );
        }
        final lowerPath = file.path.toLowerCase();
        if (lowerPath.endsWith('.svg')) {
          return SvgPicture.file(
            file,
            width: imageSize,
            height: imageSize,
            fit: BoxFit.contain,
          );
        }
        return Image.file(
          file,
          width: imageSize,
          height: imageSize,
          fit: BoxFit.contain,
          gaplessPlayback: true,
          filterQuality: FilterQuality.medium,
        );
      },
    );
  }
}
