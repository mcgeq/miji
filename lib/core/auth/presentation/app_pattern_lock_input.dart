import 'dart:math' as math;

import 'package:flutter/material.dart';

class AppPatternLockInput extends StatefulWidget {
  const AppPatternLockInput({
    required this.onChanged,
    super.key,
    this.onCompleted,
    this.enabled = true,
  });

  final ValueChanged<List<int>> onChanged;
  final ValueChanged<List<int>>? onCompleted;
  final bool enabled;

  @override
  State<AppPatternLockInput> createState() => _AppPatternLockInputState();
}

class _AppPatternLockInputState extends State<AppPatternLockInput> {
  final List<int> _selected = <int>[];
  Offset? _pointer;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          return GestureDetector(
            onPanStart: widget.enabled
                ? (details) => _update(details.localPosition, size, reset: true)
                : null,
            onPanUpdate: widget.enabled
                ? (details) => _update(details.localPosition, size)
                : null,
            onPanEnd: widget.enabled ? (_) => _finish() : null,
            onTapDown: widget.enabled
                ? (details) => _update(details.localPosition, size, reset: true)
                : null,
            onTapUp: widget.enabled ? (_) => _finish() : null,
            child: CustomPaint(
              painter: _PatternLockPainter(
                selected: _selected,
                pointer: _pointer,
                enabled: widget.enabled,
                colorScheme: Theme.of(context).colorScheme,
              ),
            ),
          );
        },
      ),
    );
  }

  void _update(Offset position, Size size, {bool reset = false}) {
    final node = _nodeAt(position, size);
    setState(() {
      if (reset) {
        _selected.clear();
      }
      _pointer = position;
      if (node != null && !_selected.contains(node)) {
        _selected.add(node);
        widget.onChanged(List<int>.unmodifiable(_selected));
      }
    });
  }

  void _finish() {
    setState(() {
      _pointer = null;
    });
    final pattern = List<int>.unmodifiable(_selected);
    widget.onChanged(pattern);
    widget.onCompleted?.call(pattern);
  }

  int? _nodeAt(Offset position, Size size) {
    final centers = _nodeCenters(size);
    final radius = size.shortestSide / 10;
    for (var index = 0; index < centers.length; index += 1) {
      if ((centers[index] - position).distance <= radius) {
        return index;
      }
    }
    return null;
  }
}

class _PatternLockPainter extends CustomPainter {
  const _PatternLockPainter({
    required this.selected,
    required this.pointer,
    required this.enabled,
    required this.colorScheme,
  });

  final List<int> selected;
  final Offset? pointer;
  final bool enabled;
  final ColorScheme colorScheme;

  @override
  void paint(Canvas canvas, Size size) {
    final centers = _nodeCenters(size);
    final activeColor = enabled
        ? colorScheme.primary
        : colorScheme.onSurfaceVariant.withValues(alpha: 0.42);
    final inactiveColor = colorScheme.outlineVariant;
    final linePaint = Paint()
      ..color = activeColor.withValues(alpha: 0.72)
      ..strokeWidth = math.max(3, size.shortestSide / 70)
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < selected.length - 1; i += 1) {
      canvas.drawLine(
        centers[selected[i]],
        centers[selected[i + 1]],
        linePaint,
      );
    }
    if (selected.isNotEmpty && pointer != null) {
      canvas.drawLine(centers[selected.last], pointer!, linePaint);
    }

    final outerRadius = size.shortestSide / 15;
    final innerRadius = size.shortestSide / 42;
    for (var index = 0; index < centers.length; index += 1) {
      final center = centers[index];
      final isSelected = selected.contains(index);
      final ringPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = isSelected ? activeColor : inactiveColor;
      final fillPaint = Paint()
        ..color = isSelected
            ? activeColor.withValues(alpha: 0.14)
            : colorScheme.surfaceContainerHighest.withValues(alpha: 0.72);
      canvas
        ..drawCircle(center, outerRadius, fillPaint)
        ..drawCircle(center, outerRadius, ringPaint);
      if (isSelected) {
        canvas.drawCircle(center, innerRadius, Paint()..color = activeColor);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PatternLockPainter oldDelegate) {
    return oldDelegate.selected != selected ||
        oldDelegate.pointer != pointer ||
        oldDelegate.enabled != enabled ||
        oldDelegate.colorScheme != colorScheme;
  }
}

List<Offset> _nodeCenters(Size size) {
  final gapX = size.width / 4;
  final gapY = size.height / 4;
  return [
    for (var row = 1; row <= 3; row += 1)
      for (var column = 1; column <= 3; column += 1)
        Offset(gapX * column, gapY * row),
  ];
}
