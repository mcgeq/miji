import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:miji/core/attachments/attachment_providers.dart';
import 'package:miji/core/attachments/attachment_store.dart';
import 'package:miji/core/presentation/app_color_utils.dart';
import 'package:miji/core/theme/app_design_tokens.dart';
import 'package:miji/features/bookkeeping/domain/money_account_entity.dart';

/// 卡片内容在自定义背景上的前景色。
///
/// 自定义背景（纯色 / 图片）下，主题的 onSurface 未必读得清 —— 内容组件
/// （身份行、余额、额度条、⋯菜单）通过它拿「该用什么颜色画字」；不在
/// 自定义背景里时返回 null，组件回退到各自原本的主题色。
class AccountCardScope extends InheritedWidget {
  const AccountCardScope({
    super.key,
    required this.onColor,
    required super.child,
  });

  /// 正文前景色，已保证与背景对比 ≥4.5:1。
  final Color onColor;

  /// 次级文字（标签、辅助信息）用 [onColor] 降不透明度。
  ///
  /// 0.78 与 `AppHeroGradient.secondaryOpacity` 同一求解上限：再淡一档，
  /// 在最亮的停靠点上会掉到 4.5:1 以下。
  static const secondaryOpacity = 0.78;

  static AccountCardScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AccountCardScope>();
  }

  /// 正文色：自定义背景上返回 [onColor]，否则回退 [fallback]。
  static Color textColorOf(BuildContext context, {required Color fallback}) {
    return maybeOf(context)?.onColor ?? fallback;
  }

  @override
  bool updateShouldNotify(AccountCardScope oldWidget) {
    return onColor != oldWidget.onColor;
  }
}

/// 账户卡的背景容器：按账户设置渲染 默认 / 纯色 / 图片 三种外观。
///
/// 降级链（对齐 `MoneyAccountEntity.effectiveBackgroundStyle`）：
/// 图片文件读不到 → 背景色；背景色也没配 → 默认外观。背景图只在本机
/// 落盘（附件不参与同步），换设备后这里就是静默降级，不渲染破图。
class AccountCardBackground extends ConsumerStatefulWidget {
  const AccountCardBackground({
    super.key,
    required this.account,
    required this.child,
  });

  final MoneyAccountEntity account;
  final Widget child;

  @override
  ConsumerState<AccountCardBackground> createState() =>
      _AccountCardBackgroundState();
}

class _AccountCardBackgroundState extends ConsumerState<AccountCardBackground> {
  /// 路径 → 文件是否存在。缓存判定结果，避免每次 rebuild 都打一次磁盘。
  final Map<String, bool> _existenceCache = <String, bool>{};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = BorderRadius.circular(theme.radiusTokens.md);
    final style = widget.account.effectiveBackgroundStyle();

    switch (style) {
      case MoneyAccountBackgroundStyle.defaultStyle:
        return _DefaultCard(radius: radius, child: widget.child);
      case MoneyAccountBackgroundStyle.color:
        final base = appColorFromHex(widget.account.backgroundColor);
        return _ColorCard(radius: radius, base: base, child: widget.child);
      case MoneyAccountBackgroundStyle.image:
        final storedPath = widget.account.backgroundImage;
        if (storedPath == null) {
          return _DefaultCard(radius: radius, child: widget.child);
        }
        final exists = _existenceCache[storedPath];
        if (exists == false) {
          return _fallbackFor(storedPath, radius: radius);
        }
        return _ImageCard(
          radius: radius,
          storedPath: storedPath,
          exists: exists,
          onExistenceResolved: (value) {
            _existenceCache[storedPath] = value;
            if (!value) {
              setState(() {});
            }
          },
          child: widget.child,
        );
    }
  }

  /// 图片不可用时的降级：有背景色用背景色，否则回默认。
  Widget _fallbackFor(String storedPath, {required BorderRadius radius}) {
    final style = widget.account.effectiveBackgroundStyle(
      backgroundImageExists: false,
    );
    if (style == MoneyAccountBackgroundStyle.color) {
      return _ColorCard(
        radius: radius,
        base: appColorFromHex(widget.account.backgroundColor),
        child: widget.child,
      );
    }
    return _DefaultCard(radius: radius, child: widget.child);
  }
}

/// 默认外观：与 `AppListItemPanel` 同一底、同一边框，保证未自定义的
/// 账户卡和升级前逐像素一致。
class _DefaultCard extends StatelessWidget {
  const _DefaultCard({required this.radius, required this.child});

  final BorderRadius radius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: radius,
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.42),
        ),
      ),
      child: child,
    );
  }
}

/// 纯色卡：仿 `AppHeroGradient` 的做法，用三档停靠点控制渐变走向
/// （两端插值会经过一段发灰的中间色），文字走 `appOnColor`。
class _ColorCard extends StatelessWidget {
  const _ColorCard({
    required this.radius,
    required this.base,
    required this.child,
  });

  final BorderRadius radius;
  final Color base;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color.lerp(base, Colors.white, 0.18)!,
        base,
        Color.lerp(base, Colors.black, 0.16)!,
      ],
    );
    final onColor = appOnColor(base);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: gradient,
        boxShadow: [
          BoxShadow(
            color: base.withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 8),
            spreadRadius: -12,
          ),
        ],
      ),
      child: AccountCardScope(onColor: onColor, child: child),
    );
  }
}

/// 图片卡：图片铺满 + 主题感知 scrim（亮色主题压白、暗色主题压黑），
/// 保证任何用户图片上文字可读。
class _ImageCard extends ConsumerStatefulWidget {
  const _ImageCard({
    required this.radius,
    required this.storedPath,
    required this.exists,
    required this.onExistenceResolved,
    required this.child,
  });

  final BorderRadius radius;
  final String storedPath;

  /// null = 还没查过磁盘；false = 查过、不存在（父级已接手降级）。
  final bool? exists;
  final ValueChanged<bool> onExistenceResolved;
  final Widget child;

  @override
  ConsumerState<_ImageCard> createState() => _ImageCardState();
}

class _ImageCardState extends ConsumerState<_ImageCard> {
  Future<File?>? _resolveFuture;

  Future<File?> _resolve(AttachmentStore store) {
    return store.existingFile(widget.storedPath);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = widget.radius;
    final store = ref.watch(attachmentStoreProvider);

    // 已确认文件不存在：父级还没来得及重建时先按 scrim 兜底渲染。
    if (widget.exists == false) {
      return _ScrimmedCard(radius: radius, child: widget.child);
    }

    _resolveFuture ??= _resolve(store).then((file) {
      widget.onExistenceResolved(file != null);
      return file;
    });

    return FutureBuilder<File?>(
      future: _resolveFuture,
      builder: (context, snapshot) {
        final file = snapshot.data;
        final hasImage = file != null;
        final onColor = _onColorFor(theme);

        final content = AccountCardScope(onColor: onColor, child: widget.child);

        return ClipRRect(
          borderRadius: radius,
          // **不能**用 `StackFit.expand`：这棵树挂在 ListView 里，主轴高度
          // 无界，expand 会把无限高度直接灌给子项（"forces an infinite
          // height"），整张卡布局崩溃、整个列表都渲染不出来。
          // 正确做法：由内容（Padding+child）撑起 Stack 的尺寸，
          // 底色 / 图片 / scrim 全部用 Positioned.fill 覆盖。
          child: Stack(
            children: [
              // 图片没就绪（首帧 / 读取中）先用 scrim 底色顶住，避免闪空。
              Positioned.fill(child: ColoredBox(color: _scrimBaseColor(theme))),
              if (hasImage)
                Positioned.fill(
                  child: Image.file(
                    file,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                    // 列表里卡片被快速复用/刷新时不要闪解析动画。
                    filterQuality: FilterQuality.medium,
                  ),
                ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(gradient: _scrimGradient(theme)),
                ),
              ),
              Padding(padding: const EdgeInsets.all(12), child: content),
            ],
          ),
        );
      },
    );
  }

  /// scrim 底色：亮色主题白、暗色主题黑。
  static Color _scrimBaseColor(ThemeData theme) {
    return theme.brightness == Brightness.light
        ? const Color(0xFFE8EAEE)
        : const Color(0xFF15181D);
  }

  /// 自上而下加深的 scrim：顶部轻、底部重，金额区（下半）对比最足。
  static LinearGradient _scrimGradient(ThemeData theme) {
    final isLight = theme.brightness == Brightness.light;
    final scrim = isLight ? Colors.white : Colors.black;
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        scrim.withValues(alpha: isLight ? 0.58 : 0.52),
        scrim.withValues(alpha: isLight ? 0.72 : 0.68),
      ],
    );
  }

  /// 图片卡上的正文色：亮 scrim 配深字、暗 scrim 配白字。
  static Color _onColorFor(ThemeData theme) {
    return theme.brightness == Brightness.light
        ? const Color(0xFF1A1D23)
        : Colors.white;
  }
}

/// 占位 scrim 卡（文件不存在时父级降级前的短暂状态）。
class _ScrimmedCard extends StatelessWidget {
  const _ScrimmedCard({required this.radius, required this.child});

  final BorderRadius radius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ClipRRect(
      borderRadius: radius,
      child: ColoredBox(
        color: _ImageCardState._scrimBaseColor(theme),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: AccountCardScope(
            onColor: _ImageCardState._onColorFor(theme),
            child: child,
          ),
        ),
      ),
    );
  }
}
