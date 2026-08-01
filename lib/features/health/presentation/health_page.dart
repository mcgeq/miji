import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';

import 'package:fluttertoast/fluttertoast.dart';

import 'package:miji/core/presentation/app_page_layout.dart';
import 'package:miji/core/presentation/app_toast.dart';
import 'package:miji/core/presentation/components/app_responsive_dialog.dart';
import 'package:miji/core/presentation/components/app_sliding_segmented_control.dart';
import 'package:miji/features/health/domain/health_models.dart';
import 'package:miji/features/health/domain/health_repository.dart';
import 'package:miji/features/health/health_text.dart';
import 'package:miji/features/health/presentation/health_action_dialogs.dart';
import 'package:miji/features/health/presentation/health_calendar_tab.dart';
import 'package:miji/features/health/presentation/health_daily_log_sheet.dart';
import 'package:miji/features/health/presentation/health_settings_tab.dart';
import 'package:miji/features/health/presentation/health_trends_tab.dart';
import 'package:miji/features/health/providers/health_providers.dart';

String _pregnancyErrorMessage(Object error) {
  if (error is HealthRepositoryException &&
      error.code == HealthRepositoryErrorCode.activePregnancyExists) {
    return '已有进行中的孕期模式';
  }
  return '启动孕期模式失败';
}

class HealthPage extends ConsumerStatefulWidget {
  const HealthPage({super.key});

  @override
  ConsumerState<HealthPage> createState() => _HealthPageState();
}

enum _HealthPanel { calendar, trends, settings }

class _HealthPageState extends ConsumerState<HealthPage> {
  var _selectedPanel = _HealthPanel.calendar;
  late DateTime _calendarFocusedDay;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now().toUtc();
    _calendarFocusedDay = DateTime.utc(now.year, now.month, now.day);
  }

  @override
  Widget build(BuildContext context) {
    final panelSelector = AppSlidingSegmentedControl<_HealthPanel>(
      minSegmentWidth: 80,
      value: _selectedPanel,
      segments: const [
        AppSlidingSegment(
          value: _HealthPanel.calendar,
          icon: Icons.calendar_month_rounded,
          label: '日历',
        ),
        AppSlidingSegment(
          value: _HealthPanel.trends,
          icon: Icons.insights_rounded,
          label: '趋势',
        ),
        AppSlidingSegment(
          value: _HealthPanel.settings,
          icon: Icons.tune_rounded,
          label: '设置',
        ),
      ],
      onChanged: (panel) {
        setState(() => _selectedPanel = panel);
      },
    );

    return AppPageFrame(
      maxWidth: 760,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: panelSelector,
          ),
          const SizedBox(height: 18),
          Expanded(child: _buildSelectedTab()),
        ],
      ),
    );
  }

  Widget _buildSelectedTab() {
    return switch (_selectedPanel) {
      _HealthPanel.calendar => _buildCalendar(),
      _HealthPanel.trends => _buildTrends(),
      _HealthPanel.settings => _buildSettings(),
    };
  }

  Widget _buildCalendar() {
    final selectedDay = ref.watch(healthTodayDateProvider);
    final todaySnapshot = ref.watch(currentUserHealthTodaySnapshotProvider);
    final range = _calendarRange(_calendarFocusedDay);
    final markers = ref.watch(currentUserHealthCalendarMarkersProvider(range));
    return markers.when(
      data: (items) {
        final snapshot = todaySnapshot.asData?.value;
        final periodTrackingEnabled =
            snapshot?.settings.periodTrackingEnabled ?? true;
        return HealthCalendarTab(
          focusedDay: _calendarFocusedDay,
          selectedDay: selectedDay,
          todaySnapshot: snapshot,
          periodTrackingEnabled: periodTrackingEnabled,
          markers: items,
          onPageChanged: (focusedDay) {
            setState(() => _calendarFocusedDay = focusedDay);
          },
          onDaySelected: (selectedDay, focusedDay) {
            ref.read(healthTodayDateProvider.notifier).set(selectedDay);
            setState(() => _calendarFocusedDay = focusedDay);
          },
          onQuickAction: (action) =>
              _handleCalendarQuickAction(action, selectedDay, snapshot),
          onEditDailyLog: () {
            final formKey = GlobalKey<HealthDailyLogSheetState>();
            showAppResponsiveDialog<void>(
              context: context,
              builder: (dialogContext) {
                return AppDialogScaffold(
                  title: '每日记录',
                  maxWidth: 440,
                  body: HealthDailyLogSheet(
                    key: formKey,
                    initialDate: selectedDay,
                    initialLog: HealthDailyLog.empty(selectedDay),
                    onSave: (draft) {
                      Navigator.of(dialogContext).pop();
                      unawaited(
                        ref
                            .read(currentUserHealthWriteControllerProvider)
                            .upsertDailyLog(draft),
                      );
                    },
                  ),
                  actions: appDialogIconActions(
                    onCancel: () => Navigator.of(dialogContext).pop(),
                    onConfirm: () => formKey.currentState?.save(),
                  ),
                );
              },
            );
          },
        );
      },
      loading: () => const _HealthLoading(),
      error: (error, stackTrace) => AppErrorState(
        title: '读取健康日历失败',
        onRetry: () => ref.invalidate(currentUserHealthCalendarMarkersProvider),
      ),
    );
  }

  void _handleCalendarQuickAction(
    HealthQuickAction action,
    DateTime date,
    HealthTodaySnapshot? todaySnapshot,
  ) {
    if (action == HealthQuickAction.period &&
        todaySnapshot?.settings.periodTrackingEnabled == false) {
      return;
    }
    final writer = ref.read(currentUserHealthWriteControllerProvider);
    final existing = isSameDay(date, DateTime.now()) && todaySnapshot != null
        ? todaySnapshot.dailyLog
        : HealthDailyLog.empty(date);
    void save(HealthDailyLogDraft draft) {
      unawaited(writer.upsertDailyLog(draft));
    }

    switch (action) {
      case HealthQuickAction.period:
        _handleCalendarPeriodAction(date, todaySnapshot);
      case HealthQuickAction.flow:
        showFlowDialog(context: context, existing: existing, onSave: save);
      case HealthQuickAction.symptoms:
        showSymptomsDialog(context: context, existing: existing, onSave: save);
      case HealthQuickAction.mood:
        showMoodDialog(context: context, existing: existing, onSave: save);
      case HealthQuickAction.temperatureSleep:
        showTemperatureSleepDialog(
          context: context,
          existing: existing,
          onSave: save,
        );
      case HealthQuickAction.ovulationTest:
        showOvulationTestDialog(
          context: context,
          existing: existing,
          onSave: save,
        );
      case HealthQuickAction.medication:
        showMedicationDialog(
          context: context,
          existing: existing,
          onSave: save,
        );
      case HealthQuickAction.more:
        break;
    }
  }

  void _handleCalendarPeriodAction(
    DateTime date,
    HealthTodaySnapshot? todaySnapshot,
  ) {
    final isPregnant = todaySnapshot?.activePregnancy != null;
    final hasOpenPeriod =
        !isPregnant &&
        todaySnapshot?.activePeriod?.endDate == null &&
        todaySnapshot?.activePeriod != null;
    final writer = ref.read(currentUserHealthWriteControllerProvider);

    if (hasOpenPeriod) {
      showAppResponsiveDialog<void>(
        context: context,
        expandCompactSheet: false,
        builder: (ctx) {
          return AppDialogScaffold(
            title: '结束经期',
            maxWidth: 380,
            titleTextAlign: TextAlign.center,
            actionsAlignment: WrapAlignment.center,
            body: const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('确定结束当前经期？'),
            ),
            actions: appDialogIconActions(
              onCancel: () => Navigator.of(ctx).pop(),
              onConfirm: () {
                Navigator.of(ctx).pop();
                unawaited(writer.endPeriod(date));
              },
            ),
          );
        },
      );
    } else {
      showAppResponsiveDialog<void>(
        context: context,
        expandCompactSheet: false,
        builder: (ctx) {
          return AppDialogScaffold(
            title: '开始经期',
            maxWidth: 380,
            titleTextAlign: TextAlign.center,
            actionsAlignment: WrapAlignment.center,
            body: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text('将从 ${date.month}月${date.day}日 开始记录经期。'),
            ),
            actions: appDialogIconActions(
              onCancel: () => Navigator.of(ctx).pop(),
              onConfirm: () {
                Navigator.of(ctx).pop();
                unawaited(writer.startPeriod(date));
              },
            ),
          );
        },
      );
    }
  }

  Widget _buildTrends() {
    final selectedStartDate = ref.watch(healthTrendStartDateProvider);
    final selectedPhase = ref.watch(healthTrendPhaseProvider);
    final summary = ref.watch(currentUserHealthTrendSummaryProvider);
    return summary.when(
      data: (value) {
        if (value == null) {
          return _HealthPlaceholderTab(
            icon: Icons.lock_outline_rounded,
            title: healthLockedLabel(),
          );
        }
        return HealthTrendsTab(
          summary: value,
          selectedPhase: selectedPhase,
          selectedStartDate: selectedStartDate,
          onPhaseChanged: (phase) {
            ref.read(healthTrendPhaseProvider.notifier).set(phase);
          },
          onStartDateChanged: (date) {
            ref.read(healthTrendStartDateProvider.notifier).set(date);
          },
        );
      },
      loading: () => const _HealthLoading(),
      error: (error, stackTrace) => AppErrorState(
        title: '读取健康趋势失败',
        onRetry: () => ref.invalidate(currentUserHealthTrendSummaryProvider),
      ),
    );
  }

  Widget _buildSettings() {
    final settings = ref.watch(currentUserHealthPeriodSettingsProvider);
    final activePregnancy = ref.watch(currentUserActivePregnancyProvider);
    return settings.when(
      data: (value) {
        if (value == null) {
          return _HealthPlaceholderTab(
            icon: Icons.lock_outline_rounded,
            title: healthLockedLabel(),
          );
        }
        return HealthSettingsTab(
          settings: value,
          activePregnancy: activePregnancy,
          onSave: (draft) {
            unawaited(
              ref
                  .read(currentUserHealthWriteControllerProvider)
                  .updatePeriodSettings(draft),
            );
          },
          onStartPregnancyMode: (draft) {
            final toast = FToast()..init(context);
            final errorMsg = _pregnancyErrorMessage;
            final errorColor = Theme.of(context).colorScheme.error;
            unawaited(
              ref
                  .read(currentUserHealthWriteControllerProvider)
                  .startPregnancyMode(draft)
                  .catchError((Object error) {
                    AppToast.errorWithColor(toast, errorColor, errorMsg(error));
                    return null;
                  }),
            );
          },
          onEndPregnancyMode: (draft) {
            final toast = FToast()..init(context);
            final errorColor = Theme.of(context).colorScheme.error;
            unawaited(
              ref
                  .read(currentUserHealthWriteControllerProvider)
                  .endPregnancyMode(draft)
                  .catchError((Object error) {
                    AppToast.errorWithColor(toast, errorColor, '结束孕期模式失败');
                    return null;
                  }),
            );
          },
          onCancelPregnancyMode: () {
            final toast = FToast()..init(context);
            final errorColor = Theme.of(context).colorScheme.error;
            unawaited(
              ref
                  .read(currentUserHealthWriteControllerProvider)
                  .cancelPregnancyMode()
                  .catchError((Object error) {
                    AppToast.errorWithColor(toast, errorColor, '删除孕期记录失败');
                    return null;
                  }),
            );
          },
        );
      },
      loading: () => const _HealthLoading(),
      error: (error, stackTrace) => AppErrorState(
        title: '读取健康设置失败',
        onRetry: () => ref.invalidate(currentUserHealthPeriodSettingsProvider),
      ),
    );
  }

  DateTimeRange _calendarRange(DateTime focusedDay) {
    return DateTimeRange(
      start: DateTime.utc(focusedDay.year, focusedDay.month - 1),
      end: DateTime.utc(focusedDay.year, focusedDay.month + 2, 0),
    );
  }
}

class _HealthLoading extends StatelessWidget {
  const _HealthLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox(
        width: 28,
        height: 28,
        child: CircularProgressIndicator(strokeWidth: 2.4),
      ),
    );
  }
}

class _HealthPlaceholderTab extends StatelessWidget {
  const _HealthPlaceholderTab({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: AppPlainPanel(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: colorScheme.primary),
            const SizedBox(width: 10),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
