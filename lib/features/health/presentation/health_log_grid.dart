import 'package:flutter/material.dart';

import 'package:miji/features/health/domain/health_models.dart';
import 'package:miji/features/health/presentation/health_presentation_helpers.dart';
import 'package:miji/features/health/presentation/health_theme.dart';

/// 4×2 的快捷记录磁贴。
///
/// 取代现状那排 25px 高的彩色药丸：整块可点、触控目标 ≥ 48dp、已记录的
/// 右上角有绿点。「完整记录」不再和「结束经期」混在一排。
class HealthLogGrid extends StatelessWidget {
  const HealthLogGrid({
    required this.hasOpenPeriod,
    required this.log,
    required this.onAction,
    super.key,
    this.periodTrackingEnabled = true,
    this.isPregnant = false,
  });

  final bool hasOpenPeriod;
  final HealthDailyLog log;
  final ValueChanged<HealthQuickAction> onAction;
  final bool periodTrackingEnabled;
  final bool isPregnant;

  @override
  Widget build(BuildContext context) {
    final actions = HealthQuickAction.values.where(_isVisible).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 8.0;
        const columns = 4;
        final tileWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final action in actions)
              SizedBox(
                width: tileWidth,
                child: _LogTile(
                  action: action,
                  label: quickActionTileLabel(action),
                  done: _isDone(action),
                  onTap: () => onAction(action),
                ),
              ),
          ],
        );
      },
    );
  }

  bool _isVisible(HealthQuickAction action) {
    if (!periodTrackingEnabled && action == HealthQuickAction.period) {
      return false;
    }
    if (isPregnant) {
      return switch (action) {
        HealthQuickAction.period ||
        HealthQuickAction.flow ||
        HealthQuickAction.ovulationTest => false,
        _ => true,
      };
    }
    return true;
  }

  bool _isDone(HealthQuickAction action) {
    return switch (action) {
      HealthQuickAction.period => hasOpenPeriod,
      HealthQuickAction.flow => log.flowLevel != null,
      HealthQuickAction.symptoms => log.symptoms.isNotEmpty,
      HealthQuickAction.mood => log.mood != null,
      HealthQuickAction.temperatureSleep =>
        log.temperatureCelsiusTenths != null || log.sleepMinutes != null,
      HealthQuickAction.ovulationTest => log.ovulationTest != null,
      HealthQuickAction.medication => log.medications.isNotEmpty,
      HealthQuickAction.more => false,
    };
  }
}

class _LogTile extends StatelessWidget {
  const _LogTile({
    required this.action,
    required this.label,
    required this.done,
    required this.onTap,
  });

  final HealthQuickAction action;
  final String label;
  final bool done;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final palette = HealthPalette.of(context);
    final accent = palette.actionColor(action);
    final surface = palette.actionSurface(action);

    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        label: label,
        child: Material(
          color: done
              ? colorScheme.primaryContainer.withValues(alpha: 0.34)
              : colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: Container(
              height: 62,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: done
                      ? colorScheme.primary.withValues(alpha: 0.32)
                      : colorScheme.outlineVariant.withValues(alpha: 0.6),
                ),
              ),
              child: Stack(
                children: [
                  // Positioned.fill 让图标在整块里水平垂直居中。
                  Positioned.fill(
                    child: Center(
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: surface,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          quickActionIcon(action),
                          size: 20,
                          color: done ? colorScheme.primary : accent,
                        ),
                      ),
                    ),
                  ),
                  if (done)
                    Positioned(
                      top: 7,
                      right: 7,
                      child: Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
