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

class AppFormRow extends StatelessWidget {
  const AppFormRow({
    super.key,
    required this.children,
    this.gap = 12,
    this.flexes,
    this.compactBreakpoint,
  });

  final List<Widget> children;
  final double gap;
  final List<int>? flexes;
  final double? compactBreakpoint;

  @override
  Widget build(BuildContext context) {
    final Widget row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _withRowGaps(children, gap, flexes),
    );
    final breakpoint = compactBreakpoint;
    if (breakpoint == null) {
      return row;
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < breakpoint) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: _withGaps(children, gap),
          );
        }
        return row;
      },
    );
  }

  List<Widget> _withRowGaps(
    List<Widget> children,
    double gap,
    List<int>? flexes,
  ) {
    if (children.length < 2) {
      return children;
    }
    final resolvedFlexes = flexes ?? List<int>.filled(children.length, 1);
    final result = <Widget>[];
    for (var index = 0; index < children.length; index += 1) {
      if (index > 0) {
        result.add(SizedBox(width: gap));
      }
      final flex = index < resolvedFlexes.length ? resolvedFlexes[index] : 1;
      result.add(Expanded(flex: flex, child: children[index]));
    }
    return result;
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
