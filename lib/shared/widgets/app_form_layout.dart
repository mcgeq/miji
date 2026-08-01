import 'package:flutter/material.dart';

class AppFormColumn extends StatelessWidget {
  const AppFormColumn({
    required this.children,
    super.key,
    this.gap = 14,
    this.mainAxisSize = MainAxisSize.min,
  });

  final List<Widget> children;
  final double gap;
  final MainAxisSize mainAxisSize;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: mainAxisSize,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: _withGaps(children, gap),
    );
  }
}

List<Widget> _withGaps(List<Widget> children, double gap) {
  if (children.length < 2) {
    return children;
  }

  final result = <Widget>[];
  for (var index = 0; index < children.length; index += 1) {
    if (index > 0) {
      result.add(SizedBox(height: gap));
    }
    result.add(children[index]);
  }
  return result;
}
