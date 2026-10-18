import 'package:flutter/material.dart';

import 'package:miji/core/theme/app_design_tokens.dart';

/// 记账键盘的键位色调。
///
/// * [digit] —— 数字与小数点，占绝大多数；
/// * [neutral] —— AC / 退格 / 括号这类「功能性」键；
/// * [operator] —— 运算符，用主色 container 区分，避免误按。
enum MoneyKeyTone { digit, neutral, operator }

/// 一个按键的定义。
@immutable
class MoneyKeySpec {
  const MoneyKeySpec(
    this.label,
    this.onTap, {
    this.tone = MoneyKeyTone.digit,
    this.flex = 1,
    this.semanticLabel,
  });

  final String label;

  /// 为 null 表示禁用（例如没有可删字符时的退格）。
  final VoidCallback? onTap;
  final MoneyKeyTone tone;

  /// 相对宽度。`0` 键、以及快速记账里的「保存」这类宽键用得上。
  final int flex;

  /// 读屏文案；`⌫`、`AC` 这类符号键必须给，否则读屏念不出来。
  final String? semanticLabel;

  MoneyKeySpec copyWith({
    String? label,
    VoidCallback? onTap,
    MoneyKeyTone? tone,
    int? flex,
    String? semanticLabel,
  }) {
    return MoneyKeySpec(
      label ?? this.label,
      onTap ?? this.onTap,
      tone: tone ?? this.tone,
      flex: flex ?? this.flex,
      semanticLabel: semanticLabel ?? this.semanticLabel,
    );
  }
}

/// 单个按键。
///
/// 抽出来是因为键盘在项目里有两处形状不同的用途：金额计算器面板（全键位 +
/// 括号与运算符）与「快速记账」的一屏界面（纯数字 + 退格 + 保存）。两者只有
/// 键位表不同，按键的样子、触感与配色必须是同一套，所以样式放这里、布局交给调用方。
class MoneyKeyButton extends StatelessWidget {
  const MoneyKeyButton({super.key, required this.spec, this.height = 52});

  final MoneyKeySpec spec;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final radius = theme.radiusTokens;
    final enabled = spec.onTap != null;

    final isOperator = spec.tone == MoneyKeyTone.operator;
    final background = switch (spec.tone) {
      MoneyKeyTone.operator => colorScheme.primaryContainer,
      MoneyKeyTone.neutral => colorScheme.surfaceContainerHighest,
      MoneyKeyTone.digit => colorScheme.surfaceContainerHigh,
    };
    final foreground = isOperator
        ? colorScheme.onPrimaryContainer
        : colorScheme.onSurface;

    return Expanded(
      flex: spec.flex,
      child: SizedBox(
        height: height,
        child: Material(
          color: enabled ? background : background.withValues(alpha: 0.5),
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius.md),
          ),
          child: InkWell(
            onTap: spec.onTap,
            child: Center(
              child: Semantics(
                button: true,
                enabled: enabled,
                label: spec.semanticLabel,
                child: Text(
                  spec.label,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: enabled
                        ? foreground
                        : foreground.withValues(alpha: 0.4),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 一行按键（自动在键之间留间距）。
class MoneyKeyRow extends StatelessWidget {
  const MoneyKeyRow({
    super.key,
    required this.specs,
    this.height = 52,
    this.spacing = 8,
  });

  final List<MoneyKeySpec> specs;
  final double height;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < specs.length; i++) ...[
          if (i > 0) SizedBox(width: spacing),
          MoneyKeyButton(spec: specs[i], height: height),
        ],
      ],
    );
  }
}

/// 多行键盘：行内与行间的间距统一在这里，调用方只给键位表。
class MoneyKeypad extends StatelessWidget {
  const MoneyKeypad({
    super.key,
    required this.rows,
    this.height = 52,
    this.spacing = 8,
    this.rowSpacing = 8,
  });

  final List<List<MoneyKeySpec>> rows;
  final double height;
  final double spacing;
  final double rowSpacing;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) SizedBox(height: rowSpacing),
          MoneyKeyRow(specs: rows[i], height: height, spacing: spacing),
        ],
      ],
    );
  }
}
