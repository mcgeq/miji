import 'package:flutter/material.dart';
import 'package:miji/core/theme/app_design_tokens.dart';

class AppSlidingSegment<T> {
  const AppSlidingSegment({
    required this.value,
    required this.label,
    this.icon,
    this.tooltip,
  });

  final T value;
  final String label;
  final IconData? icon;
  final String? tooltip;
}

class AppSlidingSegmentedControl<T> extends StatelessWidget {
  const AppSlidingSegmentedControl({
    super.key,
    required this.segments,
    required this.value,
    required this.onChanged,
    this.height,
    this.minSegmentWidth = 72,
    this.showTrack = true,
    this.showLabels = true,
  });

  final List<AppSlidingSegment<T>> segments;
  final T value;
  final ValueChanged<T> onChanged;
  final double? height;
  final double minSegmentWidth;
  final bool showTrack;
  final bool showLabels;

  @override
  Widget build(BuildContext context) {
    if (segments.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final radius = theme.radiusTokens;
    final controlHeight = height ?? theme.controlTokens.compactFieldHeight;
    final selectedIndex = segments.indexWhere(
      (segment) => segment.value == value,
    );
    final activeIndex = selectedIndex < 0 ? 0 : selectedIndex;
    final minTotalWidth = minSegmentWidth * segments.length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final resolvedWidth =
            availableWidth.isFinite && availableWidth >= minTotalWidth
            ? availableWidth
            : minTotalWidth;

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          clipBehavior: Clip.none,
          child: SizedBox(
            height: controlHeight,
            width: resolvedWidth,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final segmentWidth = constraints.maxWidth / segments.length;

                final decoration = showTrack
                    ? BoxDecoration(
                        color: colorScheme.surfaceContainerHighest.withValues(
                          alpha: 0.62,
                        ),
                        borderRadius: BorderRadius.circular(radius.pill),
                        border: Border.all(
                          color: colorScheme.outlineVariant.withValues(
                            alpha: 0.38,
                          ),
                        ),
                      )
                    : const BoxDecoration();

                return DecoratedBox(
                  decoration: decoration,
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(radius.pill),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      children: [
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOutCubic,
                          top: 3,
                          bottom: 3,
                          left: 3 + activeIndex * segmentWidth,
                          width: segmentWidth - 6,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: colorScheme.primary,
                              borderRadius: BorderRadius.circular(radius.pill),
                              boxShadow: [
                                BoxShadow(
                                  color: colorScheme.primary.withValues(
                                    alpha: 0.18,
                                  ),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            for (final segment in segments)
                              Expanded(
                                child: _SlidingSegmentButton<T>(
                                  segment: segment,
                                  selected: segment.value == value,
                                  showLabel: showLabels,
                                  onTap: () => onChanged(segment.value),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _SlidingSegmentButton<T> extends StatelessWidget {
  const _SlidingSegmentButton({
    required this.segment,
    required this.selected,
    required this.showLabel,
    required this.onTap,
  });

  final AppSlidingSegment<T> segment;
  final bool selected;
  final bool showLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final foreground = selected
        ? colorScheme.onPrimary
        : colorScheme.onSurfaceVariant;
    final icon = segment.icon;

    final child = InkWell(
      onTap: onTap,
      customBorder: const StadiumBorder(),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) Icon(icon, size: 16, color: foreground),
              if (icon != null && showLabel) const SizedBox(width: 5),
              if (showLabel)
                Flexible(
                  child: Text(
                    segment.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: foreground,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                      letterSpacing: 0,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    final tooltip = segment.tooltip ?? (showLabel ? null : segment.label);
    return tooltip == null ? child : Tooltip(message: tooltip, child: child);
  }
}
