import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:miji/core/presentation/components/app_confirm_dialog.dart';
import 'package:miji/core/presentation/components/app_icon_action_button.dart';
import 'package:miji/core/presentation/components/app_info_section.dart';
import 'package:miji/core/presentation/components/app_responsive_dialog.dart';
import 'package:miji/core/presentation/components/app_surface.dart';
import 'package:miji/features/settings/data/legacy_money_import_models.dart';
import 'package:miji/features/settings/data/legacy_money_import_service.dart';
import 'package:miji/features/settings/providers/legacy_money_import_providers.dart';
import 'package:miji/shared/widgets/app_text_field.dart';

class LegacyMoneyImportDialog extends ConsumerStatefulWidget {
  const LegacyMoneyImportDialog({super.key});

  @override
  ConsumerState<LegacyMoneyImportDialog> createState() =>
      _LegacyMoneyImportDialogState();
}

class _LegacyMoneyImportDialogState
    extends ConsumerState<LegacyMoneyImportDialog> {
  final _formKey = GlobalKey<FormState>();
  final _pathController = TextEditingController();

  @override
  void dispose() {
    _pathController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(legacyMoneyImportControllerProvider);
    final preview = state.preview;
    final isLoading = state.isLoading;
    final canImport = preview != null && preview.canImport && !isLoading;

    return AppDialogScaffold(
      title: '导入旧版记账数据',
      subtitle: '读取旧桌面版 JSON 快照或 SQLite 数据库，只替换当前应用的记账模块数据。',
      titleTextAlign: TextAlign.center,
      actionsAlignment: WrapAlignment.center,
      maxWidth: 640,
      body: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppTextFormField(
              controller: _pathController,
              labelText: '旧版数据文件路径',
              hintText: r'例如 F:\...\snap_2026-07-12.json',
              prefixIcon: const Icon(Icons.storage_outlined),
              textInputAction: TextInputAction.done,
              enabled: !isLoading,
              validator: _validatePath,
              onFieldSubmitted: (_) => _preview(),
            ),
            const SizedBox(height: 12),
            const _ImportNotice(),
            if (isLoading) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(minHeight: 3),
            ],
            if (state.error != null) ...[
              const SizedBox(height: 12),
              _ImportError(error: state.error!),
            ],
            if (preview != null) ...[
              const SizedBox(height: 12),
              _ImportPreviewPanel(preview: preview),
            ],
            if (state.result != null) ...[
              const SizedBox(height: 12),
              _ImportResultPanel(result: state.result!),
            ],
          ],
        ),
      ),
      actions: [
        AppIconActionButton(
          tooltip: '关闭',
          onPressed: isLoading ? null : _close,
          icon: Icons.close_rounded,
          variant: AppIconActionVariant.outlined,
        ),
        AppIconActionButton(
          tooltip: '预览',
          onPressed: isLoading ? null : _preview,
          icon: Icons.visibility_outlined,
          variant: AppIconActionVariant.filledTonal,
        ),
        AppIconActionButton(
          tooltip: '导入',
          onPressed: canImport ? _confirmImport : null,
          icon: Icons.move_to_inbox_outlined,
          variant: AppIconActionVariant.filled,
        ),
      ],
    );
  }

  String? _validatePath(String? value) {
    final path = value?.trim() ?? '';
    if (path.isEmpty) {
      return '请输入旧版数据文件路径';
    }
    return null;
  }

  Future<void> _preview() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    await ref
        .read(legacyMoneyImportControllerProvider.notifier)
        .preview(_pathController.text);
  }

  Future<void> _confirmImport() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final confirmed = await showAppConfirmDialog(
      context: context,
      title: '确认覆盖导入',
      message:
          '导入会清空当前应用中的账户、流水、账本、分摊、分期和预算数据，'
          '然后从旧版数据文件重新写入。旧版 SQLite 会以只读方式打开，JSON 快照不会被修改。',
      confirmLabel: '导入',
      destructive: true,
      icon: Icons.warning_amber_rounded,
    );
    if (!confirmed || !mounted) {
      return;
    }

    final result = await ref
        .read(legacyMoneyImportControllerProvider.notifier)
        .importNow(_pathController.text);
    if (result != null && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  void _close() {
    ref.read(legacyMoneyImportControllerProvider.notifier).reset();
    Navigator.of(context).pop(false);
  }
}

class _ImportNotice extends StatelessWidget {
  const _ImportNotice();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AppSurface(
      padding: const EdgeInsets.all(12),
      backgroundColor: colorScheme.primaryContainer.withValues(alpha: 0.28),
      borderColor: colorScheme.primary.withValues(alpha: 0.24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '此导入是开发阶段的一次性迁移。债务/结算表不会导入，家庭分摊只作为记录保留。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurface,
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ImportPreviewPanel extends StatelessWidget {
  const _ImportPreviewPanel({required this.preview});

  final LegacyMoneyImportPreview preview;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppInfoSection(
          title: preview.canImport ? '可导入数据' : '未找到可导入数据',
          children: [
            _countRow('账户', preview.countFor('account')),
            _countRow('流水', preview.countFor('transactions')),
            _countRow('账本', preview.countFor('family_ledger')),
            _countRow('成员', preview.countFor('family_member')),
            _countRow('分摊规则', preview.countFor('split_rules')),
            _countRow('分摊记录', preview.countFor('split_records')),
            _countRow('分期计划', preview.countFor('installment_plans')),
            _countRow('预算', preview.countFor('budget')),
          ],
        ),
        if (preview.warnings.isNotEmpty) ...[
          const SizedBox(height: 12),
          _ImportWarnings(warnings: preview.warnings),
        ],
      ],
    );
  }
}

class _ImportResultPanel extends StatelessWidget {
  const _ImportResultPanel({required this.result});

  final LegacyMoneyImportResult result;

  @override
  Widget build(BuildContext context) {
    return AppInfoSection(
      title: '导入结果',
      children: [
        _countRow('账户', result.countFor('account')),
        _countRow('流水', result.countFor('transactions')),
        _countRow('账本', result.countFor('family_ledger')),
        _countRow('分期计划', result.countFor('installment_plans')),
        _countRow('分摊记录', result.countFor('split_records')),
        _countRow('预算', result.countFor('budget')),
      ],
    );
  }
}

class _ImportWarnings extends StatelessWidget {
  const _ImportWarnings({required this.warnings});

  final List<LegacyMoneyImportWarning> warnings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AppSurface(
      padding: const EdgeInsets.all(12),
      backgroundColor: colorScheme.tertiaryContainer.withValues(alpha: 0.24),
      borderColor: colorScheme.tertiary.withValues(alpha: 0.22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '提示',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 8),
          for (final warning in warnings) ...[
            Text(
              warning.message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }
}

class _ImportError extends StatelessWidget {
  const _ImportError({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AppSurface(
      padding: const EdgeInsets.all(12),
      backgroundColor: colorScheme.errorContainer.withValues(alpha: 0.38),
      borderColor: colorScheme.error.withValues(alpha: 0.34),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded, color: colorScheme.error),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _errorText(error),
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onErrorContainer,
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

AppInfoRow _countRow(String label, int count) {
  return AppInfoRow(label: label, value: '$count', labelWidth: 86);
}

String _errorText(Object error) {
  if (error is LegacyMoneyImportException) {
    return error.message;
  }
  return error.toString();
}
