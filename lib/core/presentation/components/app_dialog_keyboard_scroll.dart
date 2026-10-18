import 'package:flutter/material.dart';

const appDialogKeyboardTransitionDuration = Duration(milliseconds: 180);

class AppDialogKeyboardScroll extends StatefulWidget {
  const AppDialogKeyboardScroll({
    super.key,
    required this.child,
    required this.footer,
    this.horizontalPadding = 16,
    this.footerReserve = 0,
  });

  final Widget child;
  final Widget footer;
  final double horizontalPadding;
  final double footerReserve;

  @override
  State<AppDialogKeyboardScroll> createState() =>
      _AppDialogKeyboardScrollState();
}

class _AppDialogKeyboardScrollState extends State<AppDialogKeyboardScroll>
    with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  late final AnimationController _insetAnimation;
  double _insetFrom = 0;
  double _insetTo = 0;
  bool _scrollScheduled = false;

  double get _animatedInset =>
      _insetFrom + (_insetTo - _insetFrom) * _insetAnimation.value;

  @override
  void initState() {
    super.initState();
    _insetAnimation = AnimationController(
      vsync: this,
      duration: appDialogKeyboardTransitionDuration,
    )..addListener(_syncFocusedFieldVisibility);
    FocusManager.instance.addListener(_scheduleFocusedFieldVisibility);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    if (_insetTo != keyboardInset) {
      _insetFrom = _animatedInset;
      _insetTo = keyboardInset;
      _insetAnimation
        ..stop()
        ..value = 0;
      if (_insetFrom != _insetTo) {
        _insetAnimation.animateTo(
          1,
          duration: appDialogKeyboardTransitionDuration,
          curve: Curves.easeOutCubic,
        );
      }
    }
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_scheduleFocusedFieldVisibility);
    _insetAnimation.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _syncFocusedFieldVisibility() {
    _scheduleFocusedFieldVisibility(duration: Duration.zero);
  }

  void _scheduleFocusedFieldVisibility({Duration? duration}) {
    if (_scrollScheduled) {
      return;
    }
    _scrollScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollScheduled = false;
      if (!mounted || !_scrollController.hasClients) {
        return;
      }
      final focusedContext = FocusManager.instance.primaryFocus?.context;
      if (focusedContext == null) {
        return;
      }
      final ownerContext =
          _scrollController.position.context.notificationContext;
      if (ownerContext == null) {
        return;
      }
      var isInsideScrollable = false;
      focusedContext.visitAncestorElements((element) {
        if (identical(element, ownerContext)) {
          isInsideScrollable = true;
          return false;
        }
        return true;
      });
      if (!isInsideScrollable) {
        return;
      }
      Scrollable.ensureVisible(
        focusedContext,
        duration: duration ?? appDialogKeyboardTransitionDuration,
        curve: Curves.easeOutCubic,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _insetAnimation,
      builder: (context, child) {
        final inset = _animatedInset;
        return Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              bottom: widget.footerReserve + inset,
              child: child!,
            ),
            Positioned(left: 0, right: 0, bottom: inset, child: widget.footer),
          ],
        );
      },
      child: SingleChildScrollView(
        controller: _scrollController,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.symmetric(horizontal: widget.horizontalPadding),
        child: widget.child,
      ),
    );
  }
}
