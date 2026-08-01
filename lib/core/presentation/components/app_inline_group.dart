import 'package:flutter/material.dart';

class AppInlineGroup extends StatelessWidget {
  const AppInlineGroup({
    required this.children,
    super.key,
    this.spacing = 12,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.mainAxisSize = MainAxisSize.min,
  });

  final List<Widget> children;
  final double spacing;
  final CrossAxisAlignment crossAxisAlignment;
  final MainAxisSize mainAxisSize;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) {
      return const SizedBox.shrink();
    }

    return Row(
      mainAxisSize: mainAxisSize,
      crossAxisAlignment: crossAxisAlignment,
      children: _withGaps(children, spacing),
    );
  }
}

List<Widget> _withGaps(List<Widget> children, double spacing) {
  if (children.length < 2) {
    return children;
  }

  final result = <Widget>[];
  for (var index = 0; index < children.length; index += 1) {
    if (index > 0) {
      result.add(SizedBox(width: spacing));
    }
    result.add(children[index]);
  }
  return result;
}
