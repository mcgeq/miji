import 'package:flutter/material.dart';
import 'package:miji/core/presentation/app_responsive.dart';
import 'package:miji/core/presentation/components/app_icon_action_button.dart';
import 'package:miji/core/theme/app_design_tokens.dart';

const _dialogKeyboardTransitionDuration = Duration(milliseconds: 180);
const _compactExpandedSheetTopGap = 12.0;
const _compactExpandedSheetMinimumHeight = 332.0;
const _compactDialogFooterReserveGap = 8.0;

Future<T?> showAppResponsiveDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool expandCompactSheet = false,
}) {
  final responsive = AppResponsive.of(context);
  if (responsive.isCompact) {
    if (expandCompactSheet) {
      return showGeneralDialog<T>(
        context: context,
        barrierDismissible: true,
        barrierLabel: MaterialLocalizations.of(
          context,
        ).modalBarrierDismissLabel,
        barrierColor: Theme.of(
          context,
        ).colorScheme.scrim.withValues(alpha: 0.48),
        transitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (context, animation, secondaryAnimation) {
          final theme = Theme.of(context);
          final radius = theme.radiusTokens;
          final media = MediaQuery.of(context);
          final view = View.of(context);
          final availableHeight =
              view.physicalSize.height / view.devicePixelRatio -
              media.padding.top;
          final expandedHeight =
              availableHeight <= _compactExpandedSheetMinimumHeight
              ? availableHeight
              : availableHeight - _compactExpandedSheetTopGap;

          final sheet = ClipRRect(
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(radius.lg),
            ),
            child: _AppResponsiveDialogScope(
              expandCompactSheet: true,
              child: builder(context),
            ),
          );

          return Material(
            color: Colors.transparent,
            child: SizedBox.expand(
              child: Stack(
                children: [
                  AnimatedPositioned(
                    duration: _dialogKeyboardTransitionDuration,
                    curve: Curves.easeOutCubic,
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: expandedHeight,
                    child: sheet,
                  ),
                ],
              ),
            ),
          );
        },
        transitionBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          final offsetTween = Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          );
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: offsetTween.animate(curved),
              child: child,
            ),
          );
        },
      );
    }

    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        final theme = Theme.of(context);
        final radius = theme.radiusTokens;
        final media = MediaQuery.of(context);
        final keyboardInset = media.viewInsets.bottom;
        final view = View.of(context);
        final availableHeight =
            view.physicalSize.height / view.devicePixelRatio -
            media.padding.top;
        final maxHeight = (availableHeight * 0.92)
            .clamp(320.0, 760.0)
            .toDouble();

        final sheet = ClipRRect(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radius.lg)),
          child: _AppResponsiveDialogScope(
            expandCompactSheet: false,
            child: builder(context),
          ),
        );

        return AnimatedPadding(
          duration: _dialogKeyboardTransitionDuration,
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.only(bottom: keyboardInset),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: sheet,
          ),
        );
      },
    );
  }

  return showDialog<T>(
    context: context,
    builder: (context) => _AppResponsiveDialogScope(
      expandCompactSheet: false,
      child: builder(context),
    ),
  );
}

List<Widget> appDialogIconActions({
  required VoidCallback onCancel,
  required VoidCallback? onConfirm,
  String cancelTooltip = '取消',
  String confirmTooltip = '确定',
  IconData cancelIcon = Icons.close_rounded,
  IconData confirmIcon = Icons.check_rounded,
}) {
  return [
    AppIconActionButton(
      tooltip: cancelTooltip,
      onPressed: onCancel,
      icon: cancelIcon,
      variant: AppIconActionVariant.outlined,
    ),
    AppIconActionButton(
      tooltip: confirmTooltip,
      onPressed: onConfirm,
      icon: confirmIcon,
      variant: AppIconActionVariant.filled,
    ),
  ];
}

class AppDialogScaffold extends StatelessWidget {
  const AppDialogScaffold({
    super.key,
    required this.title,
    required this.body,
    required this.actions,
    this.subtitle,
    this.maxWidth,
    this.titleTextAlign = TextAlign.start,
    this.actionsAlignment = WrapAlignment.end,
  });

  final String title;
  final String? subtitle;
  final Widget body;
  final List<Widget> actions;
  final double? maxWidth;
  final TextAlign titleTextAlign;
  final WrapAlignment actionsAlignment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final controls = theme.controlTokens;
    final spacing = theme.spacingTokens;
    final radius = theme.radiusTokens;
    final responsive = AppResponsive.of(context);
    final compact = responsive.isCompact;
    final expandedCompactSheet =
        compact && _AppResponsiveDialogScope.expandCompactSheetOf(context);
    final resolvedMaxWidth = maxWidth ?? controls.dialogWidth;
    final headerAlignment = titleTextAlign == TextAlign.center
        ? CrossAxisAlignment.center
        : CrossAxisAlignment.start;

    final dialogRadius = BorderRadius.circular(radius.lg);
    final sheetRadius = BorderRadius.vertical(top: Radius.circular(radius.lg));

    final header = Padding(
      padding: EdgeInsets.fromLTRB(
        spacing.cardPadding,
        spacing.cardPadding,
        spacing.cardPadding,
        spacing.fieldGap,
      ),
      child: Column(
        crossAxisAlignment: headerAlignment,
        children: [
          Text(
            title,
            textAlign: titleTextAlign,
            style: theme.textTheme.titleLarge?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
          if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              textAlign: titleTextAlign,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                letterSpacing: 0,
              ),
            ),
          ],
        ],
      ),
    );

    Widget scrollableBody() {
      return AnimatedSize(
        duration: _dialogKeyboardTransitionDuration,
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.symmetric(horizontal: spacing.cardPadding),
          child: body,
        ),
      );
    }

    final actionsFooter = DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: Border(
          top: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.32),
          ),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(spacing.cardPadding),
        child: SizedBox(
          width: double.infinity,
          child: Wrap(
            alignment: actionsAlignment,
            spacing: 8,
            runSpacing: 8,
            children: actions,
          ),
        ),
      ),
    );

    final Widget child;
    if (expandedCompactSheet) {
      final footerReserveHeight =
          controls.iconButtonSize +
          spacing.cardPadding * 2 +
          _compactDialogFooterReserveGap;
      child = _ExpandedCompactDialogLayout(
        header: header,
        body: body,
        actionsFooter: actionsFooter,
        horizontalPadding: spacing.cardPadding,
        footerReserveHeight: footerReserveHeight,
      );
    } else {
      child = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          Flexible(child: scrollableBody()),
          actionsFooter,
        ],
      );
    }

    final content = Material(
      color: colorScheme.surfaceContainerLow,
      borderRadius: compact ? sheetRadius : dialogRadius,
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: compact ? double.infinity : resolvedMaxWidth,
        ),
        child: child,
      ),
    );

    if (compact) {
      return content;
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: dialogRadius),
      child: content,
    );
  }
}

class _ExpandedCompactDialogLayout extends StatefulWidget {
  const _ExpandedCompactDialogLayout({
    required this.header,
    required this.body,
    required this.actionsFooter,
    required this.horizontalPadding,
    required this.footerReserveHeight,
  });

  final Widget header;
  final Widget body;
  final Widget actionsFooter;
  final double horizontalPadding;
  final double footerReserveHeight;

  @override
  State<_ExpandedCompactDialogLayout> createState() =>
      _ExpandedCompactDialogLayoutState();
}

class _ExpandedCompactDialogLayoutState
    extends State<_ExpandedCompactDialogLayout>
    with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  late final AnimationController _keyboardAnimation;
  double _insetFrom = 0;
  double _insetTo = 0;
  bool _focusScrollScheduled = false;

  double get _animatedKeyboardInset =>
      _insetFrom + (_insetTo - _insetFrom) * _keyboardAnimation.value;

  @override
  void initState() {
    super.initState();
    _keyboardAnimation = AnimationController(
      vsync: this,
      duration: _dialogKeyboardTransitionDuration,
    )..addListener(_syncFocusedFieldWithKeyboard);
    FocusManager.instance.addListener(_scheduleFocusedFieldVisibility);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    if (_insetTo != keyboardInset) {
      _insetFrom = _animatedKeyboardInset;
      _insetTo = keyboardInset;
      _keyboardAnimation
        ..stop()
        ..value = 0;
      if (_insetFrom != _insetTo) {
        _keyboardAnimation.animateTo(
          1,
          duration: _dialogKeyboardTransitionDuration,
          curve: Curves.easeOutCubic,
        );
      }
    }
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_scheduleFocusedFieldVisibility);
    _keyboardAnimation.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        widget.header,
        Expanded(
          child: AnimatedBuilder(
            animation: _keyboardAnimation,
            builder: (context, child) {
              final inset = _animatedKeyboardInset;
              return Stack(
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    bottom: widget.footerReserveHeight + inset,
                    child: child!,
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: inset,
                    child: widget.actionsFooter,
                  ),
                ],
              );
            },
            child: SingleChildScrollView(
              controller: _scrollController,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.symmetric(
                horizontal: widget.horizontalPadding,
              ),
              child: widget.body,
            ),
          ),
        ),
      ],
    );
  }

  void _syncFocusedFieldWithKeyboard() {
    if (_focusScrollScheduled) {
      return;
    }
    _focusScrollScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusScrollScheduled = false;
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
        duration: Duration.zero,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      );
    });
  }

  void _scheduleFocusedFieldVisibility() {
    if (_focusScrollScheduled) {
      return;
    }
    _focusScrollScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusScrollScheduled = false;
      if (!mounted || !_scrollController.hasClients) {
        return;
      }
      final focusedContext = FocusManager.instance.primaryFocus?.context;
      if (focusedContext == null) {
        return;
      }
      Scrollable.ensureVisible(
        focusedContext,
        duration: _dialogKeyboardTransitionDuration,
        curve: Curves.easeOutCubic,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      );
    });
  }
}

class _AppResponsiveDialogScope extends InheritedWidget {
  const _AppResponsiveDialogScope({
    required this.expandCompactSheet,
    required super.child,
  });

  final bool expandCompactSheet;

  static bool expandCompactSheetOf(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<_AppResponsiveDialogScope>()
            ?.expandCompactSheet ??
        false;
  }

  @override
  bool updateShouldNotify(_AppResponsiveDialogScope oldWidget) {
    return expandCompactSheet != oldWidget.expandCompactSheet;
  }
}
