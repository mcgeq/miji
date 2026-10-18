import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluttertoast/fluttertoast.dart';

import 'package:miji/core/presentation/app_toast.dart';
import 'package:miji/core/presentation/components/app_content_panel.dart';
import 'package:miji/core/presentation/components/app_form_hint.dart';
import 'package:miji/core/presentation/components/app_surface.dart';
import 'package:miji/core/notifications/notification_providers.dart';
import 'package:miji/features/bookkeeping/application/money_reminder_settings.dart';
import 'package:miji/shared/widgets/app_switch_field.dart';

/// 记账模块的提醒与通知设置。
///
/// 之前这些开关是散的：预算提醒的开关和阈值藏在预算表单里，每日汇总是硬编码
/// 20:00 且关不掉，账单提醒则根本没有时间概念——它只在打开 App 时扫一次。
/// 这里把它们收拢到一处，用户第一次能真正配置「什么时候打扰我」。
class MoneyReminderSettingsSection extends ConsumerStatefulWidget {
  const MoneyReminderSettingsSection({super.key});

  @override
  ConsumerState<MoneyReminderSettingsSection> createState() =>
      _MoneyReminderSettingsSectionState();
}

class _MoneyReminderSettingsSectionState
    extends ConsumerState<MoneyReminderSettingsSection> {
  FToast? _toast;

  FToast _ensureToast() => _toast ??= (FToast()..init(context));

  Future<void> _update(
    MoneyReminderSettings Function(MoneyReminderSettings current) transform,
  ) async {
    final controller = ref.read(moneyReminderSettingsProvider.notifier);
    final saved = await controller.saveWith(transform);
    if (!saved && mounted) {
      AppToast.error(_ensureToast(), context, '提醒设置保存失败，请重试');
    }
  }

  Future<void> _pickTime({
    required String title,
    required TimeOfDay initial,
    required ValueChanged<TimeOfDay> onPicked,
  }) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      helpText: title,
    );
    if (picked == null || !mounted) {
      return;
    }
    onPicked(picked);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final settings =
        ref.watch(moneyReminderSettingsProvider).value ??
        MoneyReminderSettings.defaults;
    final supported = ref
        .watch(appNotificationServiceProvider)
        .supportsNotifications;

    return AppContentPanel(
      leadingIcon: Icons.notifications_active_outlined,
      leadingColor: colorScheme.tertiary,
      title: '提醒与通知',
      subtitle: '账单到期、预算超支和每日记账的推送时机',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!supported) ...[
            const AppFormHint(
              icon: Icons.info_outline_rounded,
              text: '当前平台不支持本地通知，以下设置不会生效。',
            ),
            const SizedBox(height: 12),
          ],
          AppSwitchField(
            title: '记账通知',
            subtitle: '关闭后不再推送任何账单、预算和记账提醒',
            icon: Icons.notifications_active_outlined,
            value: settings.enabled,
            onChanged: (value) =>
                _update((current) => current.copyWith(enabled: value)),
          ),
          const SizedBox(height: 10),
          _TimeField(
            title: '账单提醒时间',
            subtitle: '到期前按提醒本身设置的提前天数，在这个时间推送',
            icon: Icons.today_outlined,
            time: settings.notifyTime,
            enabled: settings.enabled,
            onTap: () => _pickTime(
              title: '账单提醒时间',
              initial: settings.notifyTime,
              onPicked: (time) => _update(
                (current) => current.copyWith(
                  notifyHour: time.hour,
                  notifyMinute: time.minute,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          AppSwitchField(
            title: '每日汇总',
            subtitle: '当天有待处理提醒时，晚上推一条汇总',
            icon: Icons.summarize_outlined,
            value: settings.dailyDigestEnabled,
            onChanged: settings.enabled
                ? (value) => _update(
                    (current) => current.copyWith(dailyDigestEnabled: value),
                  )
                : null,
          ),
          const SizedBox(height: 10),
          _TimeField(
            title: '汇总推送时间',
            icon: Icons.schedule_outlined,
            time: settings.digestTime,
            enabled: settings.enabled && settings.dailyDigestEnabled,
            onTap: () => _pickTime(
              title: '汇总推送时间',
              initial: settings.digestTime,
              onPicked: (time) => _update(
                (current) => current.copyWith(
                  digestHour: time.hour,
                  digestMinute: time.minute,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          AppSwitchField(
            title: '每日记账提醒',
            subtitle: '当天还没记过账时，晚上提醒一次',
            icon: Icons.edit_note_outlined,
            value: settings.dailyLogReminderEnabled,
            onChanged: settings.enabled
                ? (value) => _update(
                    (current) =>
                        current.copyWith(dailyLogReminderEnabled: value),
                  )
                : null,
          ),
          const SizedBox(height: 10),
          _TimeField(
            title: '记账提醒时间',
            icon: Icons.alarm_outlined,
            time: settings.logReminderTime,
            enabled: settings.enabled && settings.dailyLogReminderEnabled,
            onTap: () => _pickTime(
              title: '记账提醒时间',
              initial: settings.logReminderTime,
              onPicked: (time) => _update(
                (current) => current.copyWith(
                  logReminderHour: time.hour,
                  logReminderMinute: time.minute,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          const AppFormHint(
            icon: Icons.tips_and_updates_outlined,
            text: '已进入提醒期或已逾期的项每天复推一次，在提醒中心处理掉后会自动停止。',
          ),
        ],
      ),
    );
  }
}

/// 时间选择行。
///
/// 用自定义的点击行而不是 `ListTile`：设置页里其它开关走的是 `AppSwitchField`
/// 的 surface 样式，混进 Material 默认 ListTile 会让两组控件看起来像两个应用。
class _TimeField extends StatelessWidget {
  const _TimeField({
    required this.title,
    required this.icon,
    required this.time,
    required this.enabled,
    required this.onTap,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final TimeOfDay time;
  final bool enabled;
  final VoidCallback onTap;

  String get _timeLabel {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final foreground = enabled
        ? colorScheme.onSurface
        : colorScheme.onSurfaceVariant.withValues(alpha: 0.55);
    final primary = enabled
        ? colorScheme.primary
        : colorScheme.onSurfaceVariant.withValues(alpha: 0.45);

    return AppSurface(
      tone: AppSurfaceTone.subtle,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      onTap: enabled ? onTap : null,
      child: Row(
        children: [
          Icon(icon, size: 20, color: primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            _timeLabel,
            style: theme.textTheme.titleSmall?.copyWith(
              color: primary,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.chevron_right_rounded,
            size: 18,
            color: colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}
