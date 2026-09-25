import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:miji/core/auth/application/auth_session_controller.dart';
import 'package:miji/core/presentation/components/app_responsive_dialog.dart';
import 'package:miji/features/bookkeeping/domain/money_analysis_report_entity.dart';
import 'package:miji/features/bookkeeping/providers/bookkeeping_providers.dart';
import 'package:miji/shared/widgets/app_switch_field.dart';

/// 报表自动生成设置：按账本配置周报 / 月报 / 季报 / 年报是否自动生成。
class MoneyReportSettingsDialog extends ConsumerStatefulWidget {
  const MoneyReportSettingsDialog({super.key, required this.ledgerId});

  final String ledgerId;

  @override
  ConsumerState<MoneyReportSettingsDialog> createState() =>
      _MoneyReportSettingsDialogState();
}

class _MoneyReportSettingsDialogState
    extends ConsumerState<MoneyReportSettingsDialog> {
  MoneyReportGenerationConfigEntity? _config;
  bool _saving = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final session = ref.read(authSessionControllerProvider);
    final userId = session.userId;
    if (!session.isUnlocked || userId == null) {
      return;
    }
    try {
      final config = await ref
          .read(moneyRepositoryProvider)
          .getReportGenerationConfig(userId, widget.ledgerId);
      if (!mounted) return;
      setState(() => _config = config);
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorText = '读取配置失败');
    }
  }

  MoneyReportGenerationConfigEntity _updated({
    bool? weekly,
    bool? monthly,
    bool? quarterly,
    bool? yearly,
  }) {
    final base = _config!;
    return MoneyReportGenerationConfigEntity(
      userId: base.userId,
      ledgerId: base.ledgerId,
      autoGenerateWeekly: weekly ?? base.autoGenerateWeekly,
      autoGenerateMonthly: monthly ?? base.autoGenerateMonthly,
      autoGenerateQuarterly: quarterly ?? base.autoGenerateQuarterly,
      autoGenerateYearly: yearly ?? base.autoGenerateYearly,
      createdAt: base.createdAt,
      updatedAt: base.updatedAt,
    );
  }

  Future<void> _save() async {
    final session = ref.read(authSessionControllerProvider);
    final userId = session.userId;
    if (!session.isUnlocked || userId == null || _config == null) {
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(moneyRepositoryProvider)
          .updateReportGenerationConfig(userId, _config!);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _errorText = '保存失败';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = _config;
    return AppDialogScaffold(
      title: '报表自动生成',
      maxWidth: 420,
      titleTextAlign: TextAlign.center,
      errorText: _errorText,
      body: config == null
          ? const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          : Column(
              children: [
                AppSwitchField(
                  title: '周报',
                  icon: Icons.calendar_view_week_rounded,
                  value: config.autoGenerateWeekly,
                  onChanged: (value) =>
                      setState(() => _config = _updated(weekly: value)),
                ),
                AppSwitchField(
                  title: '月报',
                  icon: Icons.calendar_month_rounded,
                  value: config.autoGenerateMonthly,
                  onChanged: (value) =>
                      setState(() => _config = _updated(monthly: value)),
                ),
                AppSwitchField(
                  title: '季报',
                  icon: Icons.calendar_view_month_rounded,
                  value: config.autoGenerateQuarterly,
                  onChanged: (value) =>
                      setState(() => _config = _updated(quarterly: value)),
                ),
                AppSwitchField(
                  title: '年报',
                  icon: Icons.calendar_today_rounded,
                  value: config.autoGenerateYearly,
                  onChanged: (value) =>
                      setState(() => _config = _updated(yearly: value)),
                ),
              ],
            ),
      actions: appDialogIconActions(
        onCancel: () => Navigator.of(context).pop(),
        onConfirm: config == null || _saving ? null : _save,
        confirmTooltip: '保存',
      ),
    );
  }
}
