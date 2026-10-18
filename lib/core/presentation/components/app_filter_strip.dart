import 'package:flutter/material.dart';
import 'package:miji/core/presentation/components/app_inline_group.dart';
import 'package:miji/core/theme/app_design_tokens.dart';

class AppFilterStrip extends StatelessWidget {
  const AppFilterStrip({
    super.key,
    this.children = const <Widget>[],
    this.child,
    this.padding,
    this.spacing = 8,
  });

  final List<Widget> children;
  final Widget? child;
  final EdgeInsetsGeometry? padding;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacingTokens = theme.spacingTokens;

    final child = this.child;
    if (child == null && children.isEmpty) {
      return const SizedBox.shrink();
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      clipBehavior: Clip.none,
      padding:
          padding ?? EdgeInsets.symmetric(vertical: spacingTokens.fieldGap),
      child: child ?? AppInlineGroup(spacing: spacing, children: children),
    );
  }
}
