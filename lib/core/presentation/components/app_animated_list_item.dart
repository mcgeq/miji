import 'package:flutter/material.dart';

class AppAnimatedListItem extends StatefulWidget {
  const AppAnimatedListItem({
    super.key,
    required this.child,
    required this.index,
    this.roundDelay = 8,
    this.delayStep = const Duration(milliseconds: 45),
    this.duration = const Duration(milliseconds: 220),
    this.offset = const Offset(0, 0.08),
    this.curve = Curves.easeOutCubic,
  });

  final Widget child;
  final int index;
  final int roundDelay;
  final Duration delayStep;
  final Duration duration;
  final Offset offset;
  final Curve curve;

  @override
  State<AppAnimatedListItem> createState() => _AppAnimatedListItemState();
}

class _AppAnimatedListItemState extends State<AppAnimatedListItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _animation = CurvedAnimation(parent: _controller, curve: widget.curve);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
        _controller.value = 1;
        return;
      }
      final delay = widget.delayStep * (widget.index % widget.roundDelay);
      Future<void>.delayed(delay, () {
        if (mounted) {
          _controller.forward();
        }
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: widget.offset,
          end: Offset.zero,
        ).animate(_animation),
        child: widget.child,
      ),
    );
  }
}
