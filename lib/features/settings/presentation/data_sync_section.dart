import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';

import 'package:miji/core/presentation/app_toast.dart';
import 'package:miji/core/presentation/components/app_confirm_dialog.dart';
import 'package:miji/core/presentation/components/app_content_panel.dart';
import 'package:miji/core/presentation/components/app_icon_action_button.dart';
import 'package:miji/core/presentation/components/app_info_section.dart';
import 'package:miji/core/presentation/components/app_list_item.dart';
import 'package:miji/core/presentation/components/app_responsive_dialog.dart';
import 'package:miji/core/sync/local_snapshot/database_snapshot_models.dart';
import 'package:miji/core/sync/local_snapshot/database_snapshot_providers.dart';
import 'package:miji/core/sync/webdav/webdav_auto_sync_executor.dart';
import 'package:miji/core/sync/webdav/webdav_models.dart';
import 'package:miji/core/sync/webdav/webdav_providers.dart';
import 'package:miji/core/sync/webdav/webdav_sync_metadata_store.dart';
import 'package:miji/core/sync/webdav/webdav_sync_preferences_store.dart';
import 'package:miji/core/theme/app_design_tokens.dart';
import 'package:miji/features/settings/presentation/legacy_money_import_dialog.dart';
import 'package:miji/features/settings/presentation/widgets/sync_conflict_panel.dart';
import 'package:miji/features/settings/providers/legacy_money_import_providers.dart';
import 'package:miji/shared/widgets/app_switch_field.dart';
import 'package:miji/shared/widgets/app_text_field.dart';
import 'package:miji/shared/widgets/form_dropdown.dart';

class DataSyncSection extends ConsumerStatefulWidget {
  const DataSyncSection({super.key});

  @override
  ConsumerState<DataSyncSection> createState() => _DataSyncSectionState();
}

enum _DataSyncView {
  overview,
  webDav,
  autoSync,
  snapshots,
  activity,
  diagnostics,
  legacy,
}

String _dataSyncViewTitle(_DataSyncView view) {
  return switch (view) {
    _DataSyncView.overview => '数据与同步',
    _DataSyncView.webDav => 'WebDAV 配置',
    _DataSyncView.autoSync => '自动同步',
    _DataSyncView.snapshots => '快照备份与恢复',
    _DataSyncView.activity => '同步记录',
    _DataSyncView.diagnostics => '同步诊断',
    _DataSyncView.legacy => '旧版数据导入',
  };
}

String _dataSyncViewSubtitle(_DataSyncView view) {
  return switch (view) {
    _DataSyncView.overview => '先看状态和主操作，低频配置收进管理入口',
    _DataSyncView.webDav => '配置云端服务、测试连接和清除本机账号信息',
    _DataSyncView.autoSync => '管理同步密码、启动时同步和定时间隔',
    _DataSyncView.snapshots => '创建、查看和恢复本机或云端加密快照',
    _DataSyncView.activity => '查看最近同步结果、失败原因和自动同步状态',
    _DataSyncView.diagnostics => '查看设备身份、待上传变更、远端游标和冲突数量',
    _DataSyncView.legacy => '一次性导入旧桌面版记账数据',
  };
}

class _DataSyncSectionState extends ConsumerState<DataSyncSection> {
  FToast? _toast;
  _DataSyncView _view = _DataSyncView.overview;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final status = ref.watch(localDatabaseSnapshotStatusProvider);
    final snapshotActionState = ref.watch(databaseSnapshotActionProvider);
    final webDavConfig = ref.watch(webDavConfigProvider);
    final webDavStatus = ref.watch(webDavRemoteSnapshotStatusProvider);
    final webDavMetadata = ref.watch(webDavSyncMetadataProvider);
    final webDavPreferences = ref.watch(webDavSyncPreferencesProvider);
    final webDavActionState = ref.watch(webDavSyncActionProvider);
    final webDavAutoSyncStatus = ref.watch(webDavAutoSyncControllerProvider);
    final webDavDiagnostics = ref.watch(webDavSyncDiagnosticsProvider);
    final isBusy = snapshotActionState.isLoading || webDavActionState.isLoading;

    return AppContentPanel(
      leadingIcon: Icons.cloud_sync_outlined,
      leadingColor: colorScheme.primary,
      title: _dataSyncViewTitle(_view),
      subtitle: _dataSyncViewSubtitle(_view),
      child: status.when(
        data: (value) {
          return webDavConfig.when(
            data: (config) => _buildDataSyncContent(
              context: context,
              snapshotStatus: value,
              config: config,
              remoteStatus: webDavStatus,
              syncMetadata: webDavMetadata,
              syncPreferences: webDavPreferences,
              autoSyncStatus: webDavAutoSyncStatus,
              diagnostics: webDavDiagnostics,
              actionState: webDavActionState,
              isBusy: isBusy,
            ),
            loading: () => const AppInfoSection(
              title: '同步配置',
              children: [
                Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: CircularProgressIndicator(),
                  ),
                ),
              ],
            ),
            error: (error, stackTrace) => AppInfoSection(
              title: '同步配置',
              children: [
                AppInfoRow(label: '状态', value: _webDavErrorText(error)),
              ],
            ),
          );
        },
        loading: () => const AppInfoSection(
          title: '本机备份',
          children: [
            Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: CircularProgressIndicator(),
              ),
            ),
          ],
        ),
        error: (error, stackTrace) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppInfoSection(
              title: '本机备份',
              children: [
                AppInfoRow(label: '状态', value: _snapshotErrorText(error)),
              ],
            ),
            const SizedBox(height: 12),
            _DataSyncActionRow(
              icon: Icons.refresh_rounded,
              title: '重新读取状态',
              subtitle: '刷新本机快照信息',
              onTap: () => ref.invalidate(localDatabaseSnapshotStatusProvider),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataSyncContent({
    required BuildContext context,
    required LocalDatabaseSnapshotStatus snapshotStatus,
    required WebDavConfig config,
    required AsyncValue<WebDavRemoteSnapshotStatus> remoteStatus,
    required AsyncValue<WebDavSyncMetadata> syncMetadata,
    required AsyncValue<WebDavSyncPreferences> syncPreferences,
    required WebDavAutoSyncStatus autoSyncStatus,
    required AsyncValue<WebDavSyncDiagnostics> diagnostics,
    required WebDavSyncActionState actionState,
    required bool isBusy,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final latest = snapshotStatus.latestSnapshot;
    final latestRemote = _remoteLatestSnapshot(remoteStatus);
    final syncActivities = _recentSyncActivities(syncMetadata);
    final autoSyncFailure = _autoSyncFailureStatus(syncMetadata);
    final children = <Widget>[
      if (_view != _DataSyncView.overview) ...[
        _DataSyncBackRow(
          onBack: () => setState(() => _view = _DataSyncView.overview),
        ),
        const SizedBox(height: 12),
      ],
      switch (_view) {
        _DataSyncView.overview => _DataSyncOverview(
          snapshotStatus: snapshotStatus,
          config: config,
          remoteStatus: remoteStatus,
          syncMetadata: syncMetadata,
          autoSyncStatus: autoSyncStatus,
          actionState: actionState,
          latestRemote: latestRemote,
          isBusy: isBusy,
          onConfigureWebDav: () => _configureWebDav(context, config),
          onSaveAutoSyncPassword: () => _saveAutoSyncPassword(context),
          onSyncNow: () => _syncWebDavNow(context),
          onCreateRemoteSnapshot: () => _createRemoteSnapshot(context),
          onShowRemoteSnapshots: () => _showRemoteSnapshots(context),
          onShowConflicts: () => _showSyncConflicts(context),
          onOpenView: (view) => setState(() => _view = view),
        ),
        _DataSyncView.webDav => _WebDavConfigPanel(
          config: config,
          remoteStatus: remoteStatus,
          actionState: actionState,
          isBusy: isBusy,
          onConfigure: () => _configureWebDav(context, config),
          onTest: () => _testWebDav(context),
          onClear: () => _clearWebDav(context),
        ),
        _DataSyncView.autoSync =>
          config.isConfigured
              ? syncPreferences.when(
                  data: (preferences) => _WebDavAutoSyncSection(
                    preferences: preferences,
                    enabled: !isBusy,
                    status: autoSyncStatus,
                    onChanged: _saveWebDavSyncPreferences,
                    onAutoSyncToggled: (enabled) =>
                        _toggleAutoSync(preferences, autoSyncStatus, enabled),
                    onSavePassword: () => _saveAutoSyncPassword(context),
                    onClearPassword: () => _clearAutoSyncPassword(context),
                  ),
                  loading: () => const AppInfoSection(
                    title: '自动同步',
                    children: [AppInfoRow(label: '状态', value: '读取中')],
                  ),
                  error: (error, stackTrace) => const AppInfoSection(
                    title: '自动同步',
                    children: [AppInfoRow(label: '状态', value: '读取失败')],
                  ),
                )
              : _DataSyncHintPanel(
                  icon: Icons.cloud_off_outlined,
                  title: '还没有配置 WebDAV',
                  message: '配置 WebDAV 后，才能设置同步密码、自动增量同步和启动时同步。',
                  actionLabel: '配置 WebDAV',
                  onAction: () => _configureWebDav(context, config),
                ),
        _DataSyncView.snapshots => _SnapshotManagementPanel(
          snapshotStatus: snapshotStatus,
          latestLocal: latest,
          latestRemote: latestRemote,
          remoteStatus: remoteStatus,
          config: config,
          autoSyncStatus: autoSyncStatus,
          isBusy: isBusy,
          onExportLocal: () => _exportSnapshot(context),
          onRestoreLocal: () => _restoreLatestSnapshot(context),
          onCreateRemote: () => _createRemoteSnapshot(context),
          onShowRemoteSnapshots: () => _showRemoteSnapshots(context),
        ),
        _DataSyncView.activity => _SyncActivityPanel(
          syncMetadata: syncMetadata,
          autoSyncFailure: autoSyncFailure,
          syncActivities: syncActivities,
        ),
        _DataSyncView.diagnostics => _SyncDiagnosticsPanel(
          diagnostics: diagnostics,
          onRefresh: () => ref.invalidate(webDavSyncDiagnosticsProvider),
        ),
        _DataSyncView.legacy => _LegacyImportPanel(
          isBusy: isBusy,
          onImport: () => _showLegacyMoneyImport(context),
        ),
      },
      if (isBusy) ...[
        const SizedBox(height: 12),
        LinearProgressIndicator(
          minHeight: 3,
          borderRadius: BorderRadius.circular(theme.radiusTokens.pill),
        ),
        const SizedBox(height: 6),
        Text(
          actionState.isLoading ? _webDavActionText(actionState) : '正在处理本机快照',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
            letterSpacing: 0,
          ),
        ),
      ],
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }

  Future<void> _exportSnapshot(BuildContext context) async {
    final password = await showAppResponsiveDialog<String>(
      context: context,
      builder: (_) =>
          const _SnapshotPasswordDialog(mode: _SnapshotDialogMode.export),
    );

    if (password == null || !context.mounted) {
      return;
    }

    try {
      await ref
          .read(databaseSnapshotActionProvider.notifier)
          .exportSnapshot(password);

      if (!context.mounted) {
        return;
      }
      AppToast.success(_ensureToast(context), context, '快照已创建');
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      AppToast.error(_ensureToast(context), context, _syncErrorText(error));
    }
  }

  Future<void> _restoreLatestSnapshot(BuildContext context) async {
    final password = await showAppResponsiveDialog<String>(
      context: context,
      builder: (_) =>
          const _SnapshotPasswordDialog(mode: _SnapshotDialogMode.restore),
    );

    if (password == null || !context.mounted) {
      return;
    }

    try {
      await ref
          .read(databaseSnapshotActionProvider.notifier)
          .restoreLatestSnapshot(password);

      if (!context.mounted) {
        return;
      }
      AppToast.success(_ensureToast(context), context, '快照已恢复，请重新登录');
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      AppToast.error(_ensureToast(context), context, _syncErrorText(error));
    }
  }

  Future<void> _showLegacyMoneyImport(BuildContext context) async {
    final imported = await showAppResponsiveDialog<bool>(
      context: context,
      builder: (_) => const LegacyMoneyImportDialog(),
    );

    ref.read(legacyMoneyImportControllerProvider.notifier).reset();

    if (imported != true || !context.mounted) {
      return;
    }

    AppToast.success(_ensureToast(context), context, '旧版记账数据已导入');
  }

  Future<void> _configureWebDav(
    BuildContext context,
    WebDavConfig current,
  ) async {
    final config = await showAppResponsiveDialog<WebDavConfig>(
      context: context,
      builder: (_) => _WebDavConfigDialog(initialConfig: current),
    );

    if (config == null || !context.mounted) {
      return;
    }

    try {
      await ref.read(webDavSyncActionProvider.notifier).saveConfig(config);
      if (!context.mounted) {
        return;
      }
      AppToast.success(_ensureToast(context), context, 'WebDAV 配置已保存');
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      AppToast.error(_ensureToast(context), context, _syncErrorText(error));
    }
  }

  Future<void> _clearWebDav(BuildContext context) async {
    try {
      await ref.read(webDavSyncActionProvider.notifier).clearConfig();
      if (!context.mounted) {
        return;
      }
      AppToast.success(_ensureToast(context), context, 'WebDAV 配置已清除');
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      AppToast.error(_ensureToast(context), context, _syncErrorText(error));
    }
  }

  Future<void> _testWebDav(BuildContext context) async {
    try {
      await ref.read(webDavSyncActionProvider.notifier).testConnection();
      if (!context.mounted) {
        return;
      }
      AppToast.success(_ensureToast(context), context, 'WebDAV 连接正常');
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      AppToast.error(_ensureToast(context), context, _syncErrorText(error));
    }
  }

  Future<void> _syncWebDavNow(BuildContext context) async {
    try {
      await ref.read(webDavSyncActionProvider.notifier).syncNow();
      if (!context.mounted) {
        return;
      }
      final metadata = await ref.read(webDavSyncMetadataProvider.future);
      if (!context.mounted) {
        return;
      }
      final activity = metadata.recentSyncActivities.isEmpty
          ? null
          : metadata.recentSyncActivities.first;
      AppToast.success(
        _ensureToast(context),
        context,
        activity == null ? 'WebDAV 同步已完成' : _syncActivitySubtitle(activity),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      AppToast.error(_ensureToast(context), context, _syncErrorText(error));
    }
  }

  Future<void> _createRemoteSnapshot(BuildContext context) async {
    try {
      await ref
          .read(webDavSyncActionProvider.notifier)
          .exportAndUploadSnapshot();
      if (!context.mounted) {
        return;
      }
      AppToast.success(_ensureToast(context), context, '云端快照已创建');
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      AppToast.error(_ensureToast(context), context, _syncErrorText(error));
    }
  }

  Future<void> _showSyncConflicts(BuildContext context) {
    return showAppResponsiveDialog<void>(
      context: context,
      builder: (_) => const SyncConflictPanel(),
    );
  }

  Future<void> _saveWebDavSyncPreferences(
    WebDavSyncPreferences preferences,
  ) async {
    try {
      await ref
          .read(webDavSyncActionProvider.notifier)
          .saveSyncPreferences(preferences);
    } catch (error) {
      if (!mounted) {
        return;
      }
      AppToast.error(_ensureToast(context), context, _syncErrorText(error));
    }
  }

  Future<void> _toggleAutoSync(
    WebDavSyncPreferences preferences,
    WebDavAutoSyncStatus status,
    bool enabled,
  ) async {
    if (enabled && !status.passwordSaved) {
      AppToast.error(_ensureToast(context), context, '请先设置同步密码');
      return;
    }

    await _saveWebDavSyncPreferences(
      preferences.copyWith(
        autoUploadEnabled: enabled,
        uploadOnStartupEnabled: enabled
            ? preferences.uploadOnStartupEnabled
            : false,
      ),
    );
  }

  Future<bool> _saveAutoSyncPassword(BuildContext context) async {
    final password = await showAppResponsiveDialog<String>(
      context: context,
      builder: (_) => const _SnapshotPasswordDialog(
        mode: _SnapshotDialogMode.autoSyncPassword,
      ),
    );

    if (password == null || !context.mounted) {
      return false;
    }

    try {
      await ref
          .read(webDavSyncActionProvider.notifier)
          .saveAutoSyncPassword(password);
      if (!context.mounted) {
        return false;
      }
      AppToast.success(_ensureToast(context), context, '同步密码已保存');
      return true;
    } catch (error) {
      if (!context.mounted) {
        return false;
      }
      AppToast.error(_ensureToast(context), context, _syncErrorText(error));
      return false;
    }
  }

  Future<void> _clearAutoSyncPassword(BuildContext context) async {
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: '清除同步密码',
      message: '清除后立即同步和自动增量同步会暂停，云端快照恢复不受影响。',
      confirmLabel: '清除',
      destructive: true,
      icon: Icons.lock_reset_rounded,
    );
    if (!confirmed || !context.mounted) {
      return;
    }

    try {
      await ref.read(webDavSyncActionProvider.notifier).clearAutoSyncPassword();
      if (!context.mounted) {
        return;
      }
      AppToast.success(_ensureToast(context), context, '同步密码已清除');
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      AppToast.error(_ensureToast(context), context, _syncErrorText(error));
    }
  }

  Future<void> _showRemoteSnapshots(BuildContext context) async {
    WebDavRemoteSnapshotStatus status;
    try {
      ref.invalidate(webDavRemoteSnapshotStatusProvider);
      status = await ref.read(webDavRemoteSnapshotStatusProvider.future);
      if (!context.mounted) {
        return;
      }
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      AppToast.error(_ensureToast(context), context, _syncErrorText(error));
      return;
    }

    final result = await showAppResponsiveDialog<_RemoteSnapshotPickerResult>(
      context: context,
      builder: (_) => _RemoteSnapshotPickerDialog(snapshots: status.snapshots),
    );

    if (result == null || !context.mounted) {
      return;
    }

    switch (result.action) {
      case _RemoteSnapshotAction.restore:
        await _restoreRemoteSnapshot(context, result.snapshot);
      case _RemoteSnapshotAction.delete:
        await _deleteRemoteSnapshot(context, result.snapshot);
    }
  }

  Future<void> _restoreRemoteSnapshot(
    BuildContext context,
    WebDavRemoteSnapshotInfo snapshot,
  ) async {
    final password = await showAppResponsiveDialog<String>(
      context: context,
      builder: (_) => const _SnapshotPasswordDialog(
        mode: _SnapshotDialogMode.remoteRestore,
      ),
    );

    if (password == null || !context.mounted) {
      return;
    }

    try {
      await ref
          .read(webDavSyncActionProvider.notifier)
          .restoreRemoteSnapshot(snapshot: snapshot, password: password);
      if (!context.mounted) {
        return;
      }
      AppToast.success(_ensureToast(context), context, '云端快照已恢复，请重新登录');
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      AppToast.error(_ensureToast(context), context, _syncErrorText(error));
    }
  }

  Future<void> _deleteRemoteSnapshot(
    BuildContext context,
    WebDavRemoteSnapshotInfo snapshot,
  ) async {
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: '删除云端快照',
      message: '确认删除“${snapshot.fileName}”？删除后无法从云端恢复此快照。',
      confirmLabel: '删除',
      destructive: true,
      icon: Icons.delete_outline_rounded,
    );
    if (!confirmed || !context.mounted) {
      return;
    }

    try {
      await ref
          .read(webDavSyncActionProvider.notifier)
          .deleteRemoteSnapshot(snapshot);
      if (!context.mounted) {
        return;
      }
      AppToast.success(_ensureToast(context), context, '云端快照已删除');
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      AppToast.error(_ensureToast(context), context, _syncErrorText(error));
    }
  }

  FToast _ensureToast(BuildContext context) {
    return _toast ??= (FToast()..init(context));
  }
}

class _DataSyncOverview extends StatelessWidget {
  const _DataSyncOverview({
    required this.snapshotStatus,
    required this.config,
    required this.remoteStatus,
    required this.syncMetadata,
    required this.autoSyncStatus,
    required this.actionState,
    required this.latestRemote,
    required this.isBusy,
    required this.onConfigureWebDav,
    required this.onSaveAutoSyncPassword,
    required this.onSyncNow,
    required this.onCreateRemoteSnapshot,
    required this.onShowRemoteSnapshots,
    required this.onShowConflicts,
    required this.onOpenView,
  });

  final LocalDatabaseSnapshotStatus snapshotStatus;
  final WebDavConfig config;
  final AsyncValue<WebDavRemoteSnapshotStatus> remoteStatus;
  final AsyncValue<WebDavSyncMetadata> syncMetadata;
  final WebDavAutoSyncStatus autoSyncStatus;
  final WebDavSyncActionState actionState;
  final WebDavRemoteSnapshotInfo? latestRemote;
  final bool isBusy;
  final VoidCallback onConfigureWebDav;
  final VoidCallback onSaveAutoSyncPassword;
  final VoidCallback onSyncNow;
  final VoidCallback onCreateRemoteSnapshot;
  final VoidCallback onShowRemoteSnapshots;
  final VoidCallback onShowConflicts;
  final ValueChanged<_DataSyncView> onOpenView;

  @override
  Widget build(BuildContext context) {
    final latestLocal = snapshotStatus.latestSnapshot;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DataSyncStatusSummary(
          snapshotStatus: snapshotStatus,
          config: config,
          remoteStatus: remoteStatus,
          syncMetadata: syncMetadata,
          autoSyncStatus: autoSyncStatus,
          actionState: actionState,
          latestLocal: latestLocal,
        ),
        const SizedBox(height: 12),
        _primaryAction(),
        const SizedBox(height: 12),
        AppInfoSection(
          title: '常用操作',
          childSpacing: 8,
          children: [
            _DataSyncActionRow(
              icon: Icons.backup_outlined,
              title: '创建云端快照',
              subtitle: autoSyncStatus.passwordSaved
                  ? '加密当前数据库并上传到 WebDAV'
                  : '请先设置同步密码',
              enabled:
                  !isBusy &&
                  config.isConfigured &&
                  autoSyncStatus.passwordSaved,
              onTap: onCreateRemoteSnapshot,
            ),
            _DataSyncActionRow(
              icon: Icons.cloud_download_outlined,
              title: '查看云端快照',
              subtitle: latestRemote == null
                  ? '刷新并查看可恢复快照'
                  : latestRemote!.fileName,
              enabled: !isBusy && config.isConfigured,
              destructive: true,
              onTap: onShowRemoteSnapshots,
            ),
            _DataSyncActionRow(
              icon: Icons.sync_problem_outlined,
              title: '同步冲突',
              subtitle: '查看需要人工处理的交易冲突',
              enabled: !isBusy && config.isConfigured,
              onTap: onShowConflicts,
            ),
          ],
        ),
        const SizedBox(height: 12),
        AppInfoSection(
          title: '管理入口',
          childSpacing: 8,
          children: [
            _DataSyncActionRow(
              icon: Icons.settings_ethernet_rounded,
              title: 'WebDAV 配置',
              subtitle: '服务商、账号、远端目录和连接测试',
              onTap: () => onOpenView(_DataSyncView.webDav),
            ),
            _DataSyncActionRow(
              icon: Icons.sync_rounded,
              title: '自动同步',
              subtitle: '同步密码、启动时同步和同步间隔',
              onTap: () => onOpenView(_DataSyncView.autoSync),
            ),
            _DataSyncActionRow(
              icon: Icons.inventory_2_outlined,
              title: '快照备份与恢复',
              subtitle: '本机快照、云端快照、覆盖恢复',
              onTap: () => onOpenView(_DataSyncView.snapshots),
            ),
            _DataSyncActionRow(
              icon: Icons.history_rounded,
              title: '同步记录',
              subtitle: '最近同步、失败原因和自动同步状态',
              onTap: () => onOpenView(_DataSyncView.activity),
            ),
            _DataSyncActionRow(
              icon: Icons.monitor_heart_outlined,
              title: '同步诊断',
              subtitle: '设备身份、待上传变更、远端游标和冲突数量',
              onTap: () => onOpenView(_DataSyncView.diagnostics),
            ),
            _DataSyncActionRow(
              icon: Icons.move_to_inbox_outlined,
              title: '旧版数据导入',
              subtitle: '一次性导入旧桌面版记账数据',
              destructive: true,
              onTap: () => onOpenView(_DataSyncView.legacy),
            ),
          ],
        ),
      ],
    );
  }

  Widget _primaryAction() {
    if (!config.isConfigured) {
      return _DataSyncActionRow(
        icon: Icons.cloud_queue_rounded,
        title: '配置 WebDAV',
        subtitle: '先配置云端服务，之后才能同步和管理云端快照',
        enabled: !isBusy,
        onTap: onConfigureWebDav,
      );
    }

    if (!autoSyncStatus.passwordSaved) {
      return _DataSyncActionRow(
        icon: Icons.lock_reset_rounded,
        title: '设置同步密码',
        subtitle: '立即同步、自动增量同步和云端快照创建都会使用此密码',
        enabled: !isBusy,
        onTap: onSaveAutoSyncPassword,
      );
    }

    return _DataSyncActionRow(
      icon: Icons.sync_rounded,
      title: '立即同步',
      subtitle: '上传和下载最近的增量变更',
      enabled: !isBusy,
      onTap: onSyncNow,
    );
  }
}

class _DataSyncStatusSummary extends StatelessWidget {
  const _DataSyncStatusSummary({
    required this.snapshotStatus,
    required this.config,
    required this.remoteStatus,
    required this.syncMetadata,
    required this.autoSyncStatus,
    required this.actionState,
    required this.latestLocal,
  });

  final LocalDatabaseSnapshotStatus snapshotStatus;
  final WebDavConfig config;
  final AsyncValue<WebDavRemoteSnapshotStatus> remoteStatus;
  final AsyncValue<WebDavSyncMetadata> syncMetadata;
  final WebDavAutoSyncStatus autoSyncStatus;
  final WebDavSyncActionState actionState;
  final LocalDatabaseSnapshotInfo? latestLocal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final failure = _autoSyncFailureStatus(syncMetadata);
    final status = _summaryStatus(
      colorScheme: colorScheme,
      successColor: theme.moneyColors.success,
      failure: failure,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppListItemPanel(
          backgroundColor: colorScheme.surfaceContainerLowest,
          borderColor: status.color.withValues(alpha: 0.24),
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppListItemIcon(icon: status.icon, color: status.color, size: 42),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      status.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      status.subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.45,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _DataSyncMetricGrid(
          metrics: [
            _DataSyncMetric(
              icon: Icons.cloud_queue_rounded,
              label: 'WebDAV',
              value: config.isConfigured ? config.providerType.label : '未配置',
              tone: config.isConfigured
                  ? theme.moneyColors.success
                  : colorScheme.error,
            ),
            _DataSyncMetric(
              icon: Icons.key_rounded,
              label: '同步密码',
              value: autoSyncStatus.passwordSaved ? '已设置' : '未设置',
              tone: autoSyncStatus.passwordSaved
                  ? theme.moneyColors.success
                  : colorScheme.error,
            ),
            _DataSyncMetric(
              icon: Icons.sync_rounded,
              label: '自动同步',
              value: _autoSyncStatusText(autoSyncStatus),
              tone: autoSyncStatus.lastOutcome == WebDavAutoSyncOutcome.failed
                  ? colorScheme.error
                  : colorScheme.primary,
            ),
            _DataSyncMetric(
              icon: Icons.schedule_rounded,
              label: '最近同步',
              value: _syncMetadataDateText(
                syncMetadata,
                (metadata) => metadata.lastUploadedAt,
              ),
              tone: colorScheme.secondary,
            ),
            _DataSyncMetric(
              icon: Icons.inventory_2_outlined,
              label: '本机快照',
              value: snapshotStatus.snapshots.isEmpty
                  ? '暂无'
                  : '${snapshotStatus.snapshots.length} 个',
              inlineDetail: latestLocal == null
                  ? null
                  : _formatDateTime(latestLocal!.createdAt),
              tone: colorScheme.tertiary,
            ),
            _DataSyncMetric(
              icon: Icons.cloud_done_outlined,
              label: '云端快照',
              value: _remoteSnapshotCountText(remoteStatus),
              tone: colorScheme.primary,
            ),
          ],
        ),
      ],
    );
  }

  _DataSyncSummaryStatus _summaryStatus({
    required ColorScheme colorScheme,
    required Color successColor,
    required _AutoSyncFailureStatus? failure,
  }) {
    if (actionState.isLoading) {
      return _DataSyncSummaryStatus(
        icon: Icons.sync_rounded,
        color: colorScheme.primary,
        title: _webDavActionText(actionState),
        subtitle: '正在处理数据同步任务，请保持应用运行。',
      );
    }

    if (!config.isConfigured) {
      return _DataSyncSummaryStatus(
        icon: Icons.cloud_off_outlined,
        color: colorScheme.tertiary,
        title: '还没有配置云端同步',
        subtitle: '先配置 WebDAV，之后才能使用增量同步和云端快照。',
      );
    }

    if (failure != null) {
      return _DataSyncSummaryStatus(
        icon: Icons.sync_problem_rounded,
        color: colorScheme.error,
        title: '最近一次自动同步失败',
        subtitle: failure.message,
      );
    }

    if (!autoSyncStatus.passwordSaved) {
      return _DataSyncSummaryStatus(
        icon: Icons.lock_outline_rounded,
        color: colorScheme.tertiary,
        title: '需要设置同步密码',
        subtitle: '同步密码用于立即同步、自动增量同步和创建云端快照。',
      );
    }

    return _DataSyncSummaryStatus(
      icon: Icons.verified_rounded,
      color: successColor,
      title: '同步已就绪',
      subtitle: '可以立即同步，也可以进入自动同步设置调整同步策略。',
    );
  }
}

class _DataSyncSummaryStatus {
  const _DataSyncSummaryStatus({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
}

class _DataSyncMetricGrid extends StatelessWidget {
  const _DataSyncMetricGrid({required this.metrics});

  final List<_DataSyncMetric> metrics;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 760 ? 3 : 2;
        final spacing = 8.0;
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final metric in metrics)
              SizedBox(
                width: width,
                child: _DataSyncMetricCard(metric: metric),
              ),
          ],
        );
      },
    );
  }
}

class _DataSyncMetric {
  const _DataSyncMetric({
    required this.icon,
    required this.label,
    required this.value,
    required this.tone,
    this.inlineDetail,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color tone;
  final String? inlineDetail;
}

class _DataSyncMetricCard extends StatelessWidget {
  const _DataSyncMetricCard({required this.metric});

  final _DataSyncMetric metric;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AppListItemPanel(
      backgroundColor: colorScheme.surfaceContainerLowest,
      borderColor: metric.tone.withValues(alpha: 0.18),
      padding: const EdgeInsets.all(10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(metric.icon, size: 18, color: metric.tone),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  metric.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 3),
                RichText(
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  text: TextSpan(
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                    children: [
                      TextSpan(text: metric.value),
                      if (metric.inlineDetail != null)
                        TextSpan(
                          text: ' · ${metric.inlineDetail}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WebDavConfigPanel extends StatelessWidget {
  const _WebDavConfigPanel({
    required this.config,
    required this.remoteStatus,
    required this.actionState,
    required this.isBusy,
    required this.onConfigure,
    required this.onTest,
    required this.onClear,
  });

  final WebDavConfig config;
  final AsyncValue<WebDavRemoteSnapshotStatus> remoteStatus;
  final WebDavSyncActionState actionState;
  final bool isBusy;
  final VoidCallback onConfigure;
  final VoidCallback onTest;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppInfoSection(
          title: 'WebDAV 云端',
          children: [
            AppInfoRow(
              label: '配置状态',
              value: config.isConfigured ? '已配置' : '未配置',
            ),
            AppInfoRow(label: '当前任务', value: _webDavActionText(actionState)),
            AppInfoRow(
              label: '服务商',
              value: config.isConfigured ? config.providerType.label : '未配置',
            ),
            AppInfoRow(
              label: '服务地址',
              value: config.isConfigured ? config.effectiveEndpointUrl : '暂无',
            ),
            AppInfoRow(
              label: '远端目录',
              value: config.remoteDirectory.isEmpty
                  ? WebDavConfig.empty.remoteDirectory
                  : config.remoteDirectory,
            ),
            AppInfoRow(
              label: '远端快照',
              value: _remoteSnapshotCountText(remoteStatus),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _DataSyncActionRow(
          icon: Icons.settings_ethernet_rounded,
          title: config.isConfigured ? '编辑 WebDAV 配置' : '配置 WebDAV',
          subtitle: config.isConfigured ? config.username : '选择服务商、账号和远端目录',
          enabled: !isBusy,
          onTap: onConfigure,
        ),
        if (config.isConfigured) ...[
          const SizedBox(height: 8),
          _DataSyncActionRow(
            icon: Icons.cloud_done_outlined,
            title: '测试 WebDAV 连接',
            subtitle: '检查账号权限并创建远端目录',
            enabled: !isBusy,
            onTap: onTest,
          ),
          const SizedBox(height: 8),
          _DataSyncActionRow(
            icon: Icons.link_off_rounded,
            title: '清除 WebDAV 配置',
            subtitle: '只清除本机保存的 WebDAV 账号信息',
            enabled: !isBusy,
            destructive: true,
            onTap: onClear,
          ),
        ],
      ],
    );
  }
}

class _SnapshotManagementPanel extends StatelessWidget {
  const _SnapshotManagementPanel({
    required this.snapshotStatus,
    required this.latestLocal,
    required this.latestRemote,
    required this.remoteStatus,
    required this.config,
    required this.autoSyncStatus,
    required this.isBusy,
    required this.onExportLocal,
    required this.onRestoreLocal,
    required this.onCreateRemote,
    required this.onShowRemoteSnapshots,
  });

  final LocalDatabaseSnapshotStatus snapshotStatus;
  final LocalDatabaseSnapshotInfo? latestLocal;
  final WebDavRemoteSnapshotInfo? latestRemote;
  final AsyncValue<WebDavRemoteSnapshotStatus> remoteStatus;
  final WebDavConfig config;
  final WebDavAutoSyncStatus autoSyncStatus;
  final bool isBusy;
  final VoidCallback onExportLocal;
  final VoidCallback onRestoreLocal;
  final VoidCallback onCreateRemote;
  final VoidCallback onShowRemoteSnapshots;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppInfoSection(
          title: '本机快照',
          children: [
            AppInfoRow(
              label: '快照数量',
              value: '${snapshotStatus.snapshots.length}',
            ),
            AppInfoRow(
              label: '最近快照',
              value: latestLocal == null
                  ? '暂无'
                  : '${_formatDateTime(latestLocal!.createdAt)} · ${_formatSize(latestLocal!.sizeBytes)}',
            ),
            AppInfoRow(
              label: '最近恢复',
              value: snapshotStatus.lastRestoreAt == null
                  ? '暂无'
                  : _formatDateTime(snapshotStatus.lastRestoreAt!),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _DataSyncActionRow(
          icon: Icons.enhanced_encryption_outlined,
          title: '仅创建本机快照',
          subtitle: '只保存在本机，不上传到 WebDAV',
          enabled: !isBusy,
          onTap: onExportLocal,
        ),
        const SizedBox(height: 8),
        _DataSyncActionRow(
          icon: Icons.restore_rounded,
          title: '恢复最近本地快照',
          subtitle: latestLocal == null
              ? '暂无可恢复的本地快照'
              : _fileName(latestLocal!.file.path),
          enabled: !isBusy && latestLocal != null,
          destructive: true,
          onTap: onRestoreLocal,
        ),
        const SizedBox(height: 12),
        AppInfoSection(
          title: '云端快照',
          children: [
            AppInfoRow(
              label: 'WebDAV',
              value: config.isConfigured ? '已配置' : '未配置',
            ),
            AppInfoRow(
              label: '远端快照',
              value: _remoteSnapshotCountText(remoteStatus),
            ),
            AppInfoRow(
              label: '最近云端',
              value: latestRemote == null
                  ? '暂无'
                  : '${latestRemote!.fileName} · ${_formatSize(latestRemote!.sizeBytes)}',
            ),
          ],
        ),
        const SizedBox(height: 12),
        _DataSyncActionRow(
          icon: Icons.backup_outlined,
          title: '创建云端快照',
          subtitle: autoSyncStatus.passwordSaved
              ? '创建加密数据库快照并上传到 WebDAV'
              : '请先设置同步密码',
          enabled:
              !isBusy && config.isConfigured && autoSyncStatus.passwordSaved,
          onTap: onCreateRemote,
        ),
        const SizedBox(height: 8),
        _DataSyncActionRow(
          icon: Icons.cloud_download_outlined,
          title: '查看云端快照',
          subtitle: '选择要恢复或删除的云端快照',
          enabled: !isBusy && config.isConfigured,
          destructive: true,
          onTap: onShowRemoteSnapshots,
        ),
      ],
    );
  }
}

class _SyncActivityPanel extends StatelessWidget {
  const _SyncActivityPanel({
    required this.syncMetadata,
    required this.autoSyncFailure,
    required this.syncActivities,
  });

  final AsyncValue<WebDavSyncMetadata> syncMetadata;
  final _AutoSyncFailureStatus? autoSyncFailure;
  final List<WebDavSyncActivityEntry> syncActivities;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (autoSyncFailure != null) ...[
          _AutoSyncFailureBanner(status: autoSyncFailure!),
          const SizedBox(height: 12),
        ],
        AppInfoSection(
          title: '同步状态',
          children: [
            AppInfoRow(
              label: '最近上传',
              value: _syncMetadataDateText(
                syncMetadata,
                (metadata) => metadata.lastUploadedAt,
              ),
            ),
            AppInfoRow(
              label: '最近恢复',
              value: _syncMetadataDateText(
                syncMetadata,
                (metadata) => metadata.lastRestoredAt,
              ),
            ),
            AppInfoRow(
              label: '自动成功',
              value: _syncMetadataDateText(
                syncMetadata,
                (metadata) => metadata.lastAutoSyncSucceededAt,
              ),
            ),
            AppInfoRow(
              label: '自动失败',
              value: _syncMetadataDateText(
                syncMetadata,
                (metadata) => metadata.lastAutoSyncFailedAt,
              ),
            ),
            AppInfoRow(
              label: '失败原因',
              value: _syncMetadataText(
                syncMetadata,
                (metadata) => metadata.lastAutoSyncError,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (syncActivities.isEmpty)
          const _DataSyncHintPanel(
            icon: Icons.history_rounded,
            title: '暂无同步记录',
            message: '完成一次手动同步、自动同步或冲突处理后，这里会显示最近记录。',
          )
        else
          _SyncActivityHistorySection(activities: syncActivities),
      ],
    );
  }
}

class _SyncDiagnosticsPanel extends StatelessWidget {
  const _SyncDiagnosticsPanel({
    required this.diagnostics,
    required this.onRefresh,
  });

  final AsyncValue<WebDavSyncDiagnostics> diagnostics;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return diagnostics.when(
      data: (value) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DataSyncMetricGrid(
            metrics: [
              _DataSyncMetric(
                icon: Icons.upload_rounded,
                label: '待上传',
                value: '${value.pendingUploadChanges} 条',
                tone: value.pendingUploadChanges > 0
                    ? colorScheme.primary
                    : theme.moneyColors.success,
              ),
              _DataSyncMetric(
                icon: Icons.warning_amber_rounded,
                label: '待处理冲突',
                value: '${value.openConflicts} 条',
                tone: value.openConflicts > 0
                    ? colorScheme.error
                    : theme.moneyColors.success,
              ),
              _DataSyncMetric(
                icon: Icons.devices_other_rounded,
                label: '远端设备',
                value: '${value.remoteCursorDeviceCount} 个',
                tone: colorScheme.secondary,
              ),
              _DataSyncMetric(
                icon: Icons.route_rounded,
                label: '远端游标',
                value: value.remoteCursorMaxSequence == null
                    ? '暂无'
                    : _shortSequence(value.remoteCursorMaxSequence!),
                tone: colorScheme.tertiary,
              ),
            ],
          ),
          const SizedBox(height: 12),
          AppInfoSection(
            title: '同步身份',
            children: [
              AppInfoRow(label: '本机设备', value: _shortId(value.deviceId)),
              AppInfoRow(label: '数据空间', value: _shortId(value.datasetId)),
              AppInfoRow(
                label: '当前用户',
                value: value.currentUserId == null
                    ? '未登录'
                    : _shortId(value.currentUserId!),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AppInfoSection(
            title: '最近同步结果',
            children: [
              AppInfoRow(
                label: '状态',
                value: value.latestActivity == null
                    ? '暂无同步记录'
                    : _syncActivityOutcomeText(value.latestActivity!.outcome),
              ),
              AppInfoRow(
                label: '时间',
                value: value.latestActivity == null
                    ? '暂无'
                    : _formatDateTime(value.latestActivity!.finishedAt),
              ),
              AppInfoRow(
                label: '结果',
                value: value.latestActivity == null
                    ? '暂无'
                    : _syncActivitySubtitle(value.latestActivity!),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _DataSyncActionRow(
            icon: Icons.refresh_rounded,
            title: '刷新诊断信息',
            subtitle: '重新读取本机变更、冲突和远端游标状态',
            onTap: onRefresh,
          ),
        ],
      ),
      loading: () => const AppInfoSection(
        title: '同步诊断',
        children: [AppInfoRow(label: '状态', value: '读取中')],
      ),
      error: (error, stackTrace) => AppInfoSection(
        title: '同步诊断',
        children: [AppInfoRow(label: '状态', value: _syncErrorText(error))],
      ),
    );
  }
}

class _LegacyImportPanel extends StatelessWidget {
  const _LegacyImportPanel({required this.isBusy, required this.onImport});

  final bool isBusy;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _DataSyncHintPanel(
          icon: Icons.move_to_inbox_outlined,
          title: '旧版数据导入',
          message: '这是开发阶段的一次性导入入口，用于从旧桌面版 JSON 快照或数据库导入记账数据。',
        ),
        const SizedBox(height: 12),
        _DataSyncActionRow(
          icon: Icons.move_to_inbox_outlined,
          title: '导入旧版记账数据',
          subtitle: '导入账户、流水、账本、分摊、分期和预算',
          enabled: !isBusy,
          destructive: true,
          onTap: onImport,
        ),
      ],
    );
  }
}

class _DataSyncBackRow extends StatelessWidget {
  const _DataSyncBackRow({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: onBack,
        icon: const Icon(Icons.arrow_back_rounded),
        label: const Text('返回同步总览'),
      ),
    );
  }
}

class _DataSyncHintPanel extends StatelessWidget {
  const _DataSyncHintPanel({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AppListItemPanel(
      backgroundColor: colorScheme.surfaceContainerLowest,
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppListItemIcon(icon: icon, color: colorScheme.primary, size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.45,
                    letterSpacing: 0,
                  ),
                ),
                if (actionLabel != null && onAction != null) ...[
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.tonalIcon(
                      onPressed: onAction,
                      icon: const Icon(Icons.arrow_forward_rounded),
                      label: Text(actionLabel!),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AutoSyncFailureStatus {
  const _AutoSyncFailureStatus({required this.failedAt, required this.message});

  final DateTime failedAt;
  final String message;
}

class _AutoSyncFailureBanner extends StatelessWidget {
  const _AutoSyncFailureBanner({required this.status});

  final _AutoSyncFailureStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final tone = colorScheme.error;

    return AppListItemPanel(
      backgroundColor: colorScheme.errorContainer.withValues(alpha: 0.34),
      borderColor: tone.withValues(alpha: 0.28),
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppListItemIcon(
            icon: Icons.sync_problem_rounded,
            color: tone,
            size: 34,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '自动同步失败',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: colorScheme.onErrorContainer,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '上次失败：${_formatDateTime(status.failedAt)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onErrorContainer.withValues(alpha: 0.78),
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  status.message,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onErrorContainer,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SyncActivityHistorySection extends StatelessWidget {
  const _SyncActivityHistorySection({required this.activities});

  final List<WebDavSyncActivityEntry> activities;

  @override
  Widget build(BuildContext context) {
    return AppInfoSection(
      title: '最近同步记录',
      childSpacing: 8,
      children: [
        for (final activity in activities.take(3))
          _SyncActivityHistoryRow(activity: activity),
      ],
    );
  }
}

class _SyncActivityHistoryRow extends StatelessWidget {
  const _SyncActivityHistoryRow({required this.activity});

  final WebDavSyncActivityEntry activity;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final failed = activity.outcome == 'failed';
    final tone = failed ? colorScheme.error : theme.moneyColors.success;

    return AppListItemPanel(
      padding: const EdgeInsets.all(10),
      backgroundColor: colorScheme.surfaceContainerLowest,
      borderColor: tone.withValues(alpha: 0.24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppListItemIcon(
            icon: failed ? Icons.error_outline_rounded : Icons.check_rounded,
            color: tone,
            size: 30,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _formatDateTime(activity.finishedAt),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                    Text(
                      _syncActivityOutcomeText(activity.outcome),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: tone,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  _syncActivitySubtitle(activity),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    letterSpacing: 0,
                  ),
                ),
                if ((activity.errorMessage ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    activity.errorMessage!.trim(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WebDavAutoSyncSection extends StatelessWidget {
  const _WebDavAutoSyncSection({
    required this.preferences,
    required this.status,
    required this.enabled,
    required this.onChanged,
    required this.onAutoSyncToggled,
    required this.onSavePassword,
    required this.onClearPassword,
  });

  final WebDavSyncPreferences preferences;
  final WebDavAutoSyncStatus status;
  final bool enabled;
  final ValueChanged<WebDavSyncPreferences> onChanged;
  final ValueChanged<bool> onAutoSyncToggled;
  final VoidCallback onSavePassword;
  final VoidCallback onClearPassword;

  @override
  Widget build(BuildContext context) {
    final autoUploadEnabled = preferences.autoUploadEnabled;
    final controlsEnabled = enabled && autoUploadEnabled;

    return AppInfoSection(
      title: '自动同步',
      childSpacing: 8,
      children: [
        AppInfoRow(label: '同步密码', value: status.passwordSaved ? '已保存' : '未保存'),
        AppInfoRow(label: '状态', value: _autoSyncStatusText(status)),
        AppInfoRow(
          label: '最近结果',
          value: _autoSyncOutcomeText(status.lastOutcome),
        ),
        AppInfoRow(
          label: '下次同步',
          value: status.nextRunAt == null
              ? '暂无'
              : _formatDateTime(status.nextRunAt!),
        ),
        _DataSyncActionRow(
          icon: Icons.lock_reset_rounded,
          title: status.passwordSaved ? '修改同步密码' : '设置同步密码',
          subtitle: status.passwordSaved
              ? '立即同步和自动增量同步都会使用此密码'
              : '使用立即同步或自动增量同步前需要先保存同步密码',
          enabled: enabled,
          onTap: onSavePassword,
        ),
        if (status.passwordSaved) ...[
          const SizedBox(height: 8),
          _DataSyncActionRow(
            icon: Icons.lock_open_rounded,
            title: '清除同步密码',
            subtitle: '清除后立即同步和自动增量同步都会暂停',
            enabled: enabled,
            destructive: true,
            onTap: onClearPassword,
          ),
        ],
        AppSwitchField(
          title: '自动增量同步',
          subtitle: '按设定间隔同步本机与 WebDAV 上的增量变更',
          icon: Icons.sync_rounded,
          value: autoUploadEnabled,
          onChanged: enabled && status.passwordSaved ? onAutoSyncToggled : null,
        ),
        AppSwitchField(
          title: '启动时同步',
          subtitle: '应用启动后执行一次增量同步，不会覆盖恢复本机数据',
          icon: Icons.rocket_launch_outlined,
          value: preferences.uploadOnStartupEnabled,
          onChanged: controlsEnabled && status.passwordSaved
              ? (value) => onChanged(
                  preferences.copyWith(uploadOnStartupEnabled: value),
                )
              : null,
        ),
        FormDropdown<int>(
          entries: WebDavSyncPreferences.supportedIntervals
              .map(
                (minutes) => DropdownMenuEntry<int>(
                  value: minutes,
                  label: _syncIntervalText(minutes),
                  leadingIcon: const Icon(Icons.schedule_rounded),
                ),
              )
              .toList(growable: false),
          initialSelection: preferences.uploadIntervalMinutes,
          label: '上传间隔',
          leadingIcon: const Icon(Icons.timer_outlined),
          enabled: controlsEnabled && status.passwordSaved,
          onSelected: (value) {
            if (value == null) {
              return;
            }
            onChanged(preferences.copyWith(uploadIntervalMinutes: value));
          },
        ),
      ],
    );
  }
}

enum _RemoteSnapshotAction { restore, delete }

class _RemoteSnapshotPickerResult {
  const _RemoteSnapshotPickerResult({
    required this.action,
    required this.snapshot,
  });

  final _RemoteSnapshotAction action;
  final WebDavRemoteSnapshotInfo snapshot;
}

class _RemoteSnapshotPickerDialog extends StatelessWidget {
  const _RemoteSnapshotPickerDialog({required this.snapshots});

  final List<WebDavRemoteSnapshotInfo> snapshots;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AppDialogScaffold(
      title: '云端快照',
      subtitle: '选择一个快照恢复到本机。恢复会覆盖当前本机数据库。',
      titleTextAlign: TextAlign.center,
      actionsAlignment: WrapAlignment.center,
      body: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 420),
        child: snapshots.isEmpty
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Text(
                    '暂无云端快照',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              )
            : ListView.separated(
                shrinkWrap: true,
                itemCount: snapshots.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final snapshot = snapshots[index];
                  return AppListItemPanel(
                    onTap: () => Navigator.of(context).pop(
                      _RemoteSnapshotPickerResult(
                        action: _RemoteSnapshotAction.restore,
                        snapshot: snapshot,
                      ),
                    ),
                    backgroundColor: colorScheme.surfaceContainerLowest,
                    child: Row(
                      children: [
                        AppListItemIcon(
                          icon: Icons.cloud_download_outlined,
                          color: colorScheme.primary,
                          size: 36,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                snapshot.updatedAt == null
                                    ? snapshot.fileName
                                    : _formatDateTime(snapshot.updatedAt!),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${_formatSize(snapshot.sizeBytes)} · ${snapshot.fileName}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  letterSpacing: 0,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        AppIconActionButton(
                          tooltip: '删除',
                          onPressed: () => Navigator.of(context).pop(
                            _RemoteSnapshotPickerResult(
                              action: _RemoteSnapshotAction.delete,
                              snapshot: snapshot,
                            ),
                          ),
                          icon: Icons.delete_outline_rounded,
                          variant: AppIconActionVariant.plain,
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
      actions: [
        AppIconActionButton(
          tooltip: '关闭',
          onPressed: () => Navigator.of(context).pop(),
          icon: Icons.close_rounded,
          variant: AppIconActionVariant.outlined,
        ),
      ],
    );
  }
}

class _DataSyncActionRow extends StatelessWidget {
  const _DataSyncActionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.enabled = true,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool enabled;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final tone = destructive ? colorScheme.error : colorScheme.primary;
    final effectiveTone = enabled ? tone : colorScheme.onSurfaceVariant;

    return AppListItemPanel(
      onTap: enabled ? onTap : null,
      backgroundColor: colorScheme.surfaceContainerLowest,
      child: Row(
        children: [
          AppListItemIcon(icon: icon, color: effectiveTone, size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: enabled
                        ? colorScheme.onSurface
                        : colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            Icons.chevron_right_rounded,
            color: colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}

enum _SnapshotDialogMode {
  export,
  cloudSnapshot,
  deltaSync,
  restore,
  remoteRestore,
  autoSyncPassword,
}

class _SnapshotPasswordDialog extends StatefulWidget {
  const _SnapshotPasswordDialog({required this.mode});

  final _SnapshotDialogMode mode;

  @override
  State<_SnapshotPasswordDialog> createState() =>
      _SnapshotPasswordDialogState();
}

class _SnapshotPasswordDialogState extends State<_SnapshotPasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool get _isExport =>
      widget.mode == _SnapshotDialogMode.export ||
      widget.mode == _SnapshotDialogMode.cloudSnapshot ||
      widget.mode == _SnapshotDialogMode.autoSyncPassword;

  bool get _isSyncPassword =>
      widget.mode == _SnapshotDialogMode.deltaSync ||
      widget.mode == _SnapshotDialogMode.autoSyncPassword;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppDialogScaffold(
      title: switch (widget.mode) {
        _SnapshotDialogMode.export => '创建加密快照',
        _SnapshotDialogMode.cloudSnapshot => '创建云端快照',
        _SnapshotDialogMode.deltaSync => '增量同步密码',
        _SnapshotDialogMode.restore => '恢复本地快照',
        _SnapshotDialogMode.remoteRestore => '恢复云端快照',
        _SnapshotDialogMode.autoSyncPassword => '同步密码',
      },
      subtitle: widget.mode == _SnapshotDialogMode.autoSyncPassword
          ? '此密码仅保存在当前设备，用于手动和自动增量同步。'
          : widget.mode == _SnapshotDialogMode.deltaSync
          ? '此密码用于 WebDAV 增量同步，不会创建或恢复快照。'
          : _isExport
          ? '恢复快照时需要输入此密码。可以与本地登录密码相同，但系统不会自动保存。'
          : '恢复会关闭当前数据库并覆盖本地数据。恢复后需要重新登录。',
      titleTextAlign: TextAlign.center,
      actionsAlignment: WrapAlignment.center,
      body: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppTextFormField(
              controller: _passwordController,
              labelText: _isSyncPassword ? '同步密码' : '快照密码',
              prefixIcon: const Icon(Icons.key_rounded),
              obscureText: true,
              autofocus: true,
              validator: _validatePassword,
            ),
            if (_isExport) ...[
              const SizedBox(height: 12),
              AppTextFormField(
                controller: _confirmPasswordController,
                labelText: _isSyncPassword ? '再次输入同步密码' : '再次输入快照密码',
                prefixIcon: const Icon(Icons.verified_user_outlined),
                obscureText: true,
                validator: _validateConfirmPassword,
              ),
            ],
          ],
        ),
      ),
      actions: appDialogIconActions(
        onCancel: () => Navigator.of(context).pop(),
        onConfirm: _submit,
        confirmTooltip: widget.mode == _SnapshotDialogMode.autoSyncPassword
            ? '保存'
            : widget.mode == _SnapshotDialogMode.deltaSync
            ? '开始同步'
            : _isExport
            ? '创建'
            : '恢复',
        confirmIcon: widget.mode == _SnapshotDialogMode.autoSyncPassword
            ? Icons.save_outlined
            : widget.mode == _SnapshotDialogMode.deltaSync
            ? Icons.sync_rounded
            : _isExport
            ? Icons.enhanced_encryption_outlined
            : Icons.restore_rounded,
      ),
    );
  }

  String? _validatePassword(String? value) {
    final password = value?.trim() ?? '';
    if (password.isEmpty) {
      return _isSyncPassword ? '请输入同步密码' : '请输入快照密码';
    }
    if (password.length < 8) {
      return _isSyncPassword ? '同步密码至少 8 位' : '快照密码至少 8 位';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    final error = _validatePassword(value);
    if (error != null) {
      return error;
    }
    if (value?.trim() != _passwordController.text.trim()) {
      return _isSyncPassword ? '两次输入的同步密码不一致' : '两次输入的快照密码不一致';
    }
    return null;
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    Navigator.of(context).pop(_passwordController.text.trim());
  }
}

class _WebDavConfigDialog extends ConsumerStatefulWidget {
  const _WebDavConfigDialog({required this.initialConfig});

  final WebDavConfig initialConfig;

  @override
  ConsumerState<_WebDavConfigDialog> createState() =>
      _WebDavConfigDialogState();
}

class _WebDavConfigDialogState extends ConsumerState<_WebDavConfigDialog> {
  final _formKey = GlobalKey<FormState>();
  late WebDavProviderType _providerType;
  late final TextEditingController _endpointController;
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;
  late final TextEditingController _remoteDirectoryController;
  FToast? _toast;
  bool _testing = false;

  bool get _needsEndpointInput => _providerType.needsEndpointInput;

  @override
  void initState() {
    super.initState();
    final config = widget.initialConfig;
    _providerType = config.providerType;
    _endpointController = TextEditingController(
      text: config.endpointUrl.isNotEmpty
          ? config.endpointUrl
          : config.providerType.defaultEndpointUrl,
    );
    _usernameController = TextEditingController(text: config.username);
    _passwordController = TextEditingController(text: config.password);
    _remoteDirectoryController = TextEditingController(
      text: config.remoteDirectory.isEmpty
          ? WebDavConfig.empty.remoteDirectory
          : config.remoteDirectory,
    );
  }

  @override
  void dispose() {
    _endpointController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _remoteDirectoryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppDialogScaffold(
      title: 'WebDAV 配置',
      subtitle: '账号信息只保存在当前设备，不会写入数据库快照。',
      titleTextAlign: TextAlign.center,
      actionsAlignment: WrapAlignment.center,
      body: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FormDropdown<WebDavProviderType>(
              entries: WebDavProviderType.values
                  .map(
                    (type) => DropdownMenuEntry<WebDavProviderType>(
                      value: type,
                      label: type.label,
                      leadingIcon: Icon(_providerIcon(type)),
                    ),
                  )
                  .toList(growable: false),
              initialSelection: _providerType,
              label: '同步服务',
              leadingIcon: const Icon(Icons.cloud_queue_rounded),
              onSelected: _selectProviderType,
            ),
            const SizedBox(height: 12),
            AppTextFormField(
              controller: _endpointController,
              labelText: '服务地址',
              prefixIcon: const Icon(Icons.link_rounded),
              enabled: _needsEndpointInput,
              validator: _validateEndpoint,
            ),
            const SizedBox(height: 12),
            AppTextFormField(
              controller: _usernameController,
              labelText: '用户名',
              prefixIcon: const Icon(Icons.person_outline_rounded),
              validator: _validateRequired,
            ),
            const SizedBox(height: 12),
            AppTextFormField(
              controller: _passwordController,
              labelText: '密码',
              prefixIcon: const Icon(Icons.password_rounded),
              obscureText: true,
              validator: _validateRequired,
            ),
            const SizedBox(height: 12),
            AppTextFormField(
              controller: _remoteDirectoryController,
              labelText: '远端目录',
              prefixIcon: const Icon(Icons.folder_outlined),
              validator: _validateRequired,
            ),
          ],
        ),
      ),
      actions: [
        AppIconActionButton(
          tooltip: '取消',
          onPressed: _testing ? null : () => Navigator.of(context).pop(),
          icon: Icons.close_rounded,
          variant: AppIconActionVariant.outlined,
        ),
        AppIconActionButton(
          tooltip: '测试连接',
          onPressed: _testing ? null : _testConnection,
          icon: _testing
              ? Icons.hourglass_top_rounded
              : Icons.cloud_done_outlined,
          variant: AppIconActionVariant.filledTonal,
        ),
        AppIconActionButton(
          tooltip: '保存',
          onPressed: _testing ? null : _submit,
          icon: Icons.save_outlined,
          variant: AppIconActionVariant.filled,
        ),
      ],
    );
  }

  void _selectProviderType(WebDavProviderType? value) {
    if (value == null) {
      return;
    }
    setState(() {
      _providerType = value;
      final defaultUrl = value.defaultEndpointUrl;
      if (defaultUrl.isNotEmpty) {
        _endpointController.text = defaultUrl;
      } else if (!_needsEndpointInput) {
        _endpointController.clear();
      }
    });
  }

  IconData _providerIcon(WebDavProviderType type) {
    return switch (type) {
      WebDavProviderType.nutstore => Icons.cloud_done_outlined,
      WebDavProviderType.teraCloud => Icons.cloud_queue_outlined,
      WebDavProviderType.nextcloud => Icons.cloud_circle_outlined,
      WebDavProviderType.custom => Icons.settings_ethernet_rounded,
    };
  }

  String? _validateEndpoint(String? value) {
    if (!_needsEndpointInput) {
      return null;
    }
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return '请输入服务地址';
    }
    final uri = Uri.tryParse(text);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      return '请输入完整的服务地址';
    }
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      return '服务地址需要使用 http 或 https';
    }
    return null;
  }

  String? _validateRequired(String? value) {
    if ((value ?? '').trim().isEmpty) {
      return '必填';
    }
    return null;
  }

  Future<void> _testConnection() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() => _testing = true);
    try {
      await ref.read(webDavClientProvider).testConnection(_currentConfig());
      if (!mounted) {
        return;
      }
      AppToast.success(_ensureToast(context), context, 'WebDAV 连接正常');
    } catch (error) {
      if (!mounted) {
        return;
      }
      AppToast.error(_ensureToast(context), context, _syncErrorText(error));
    } finally {
      if (mounted) {
        setState(() => _testing = false);
      }
    }
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    Navigator.of(context).pop(_currentConfig());
  }

  WebDavConfig _currentConfig() {
    return WebDavConfig(
      providerType: _providerType,
      endpointUrl: _needsEndpointInput ? _endpointController.text.trim() : '',
      username: _usernameController.text.trim(),
      password: _passwordController.text,
      remoteDirectory: _remoteDirectoryController.text.trim(),
    );
  }

  FToast _ensureToast(BuildContext context) {
    return _toast ??= (FToast()..init(context));
  }
}

WebDavRemoteSnapshotInfo? _remoteLatestSnapshot(
  AsyncValue<WebDavRemoteSnapshotStatus> status,
) {
  return status.when(
    data: (value) => value.latestSnapshot,
    error: (error, stackTrace) => null,
    loading: () => null,
  );
}

_AutoSyncFailureStatus? _autoSyncFailureStatus(
  AsyncValue<WebDavSyncMetadata> metadata,
) {
  return metadata.when(
    data: (value) {
      final failedAt = value.lastAutoSyncFailedAt;
      if (failedAt == null) {
        return null;
      }
      final message = value.lastAutoSyncError?.trim();
      return _AutoSyncFailureStatus(
        failedAt: failedAt,
        message: message == null || message.isEmpty
            ? '自动同步失败，请检查 WebDAV 配置和网络状态'
            : message,
      );
    },
    error: (error, stackTrace) => null,
    loading: () => null,
  );
}

List<WebDavSyncActivityEntry> _recentSyncActivities(
  AsyncValue<WebDavSyncMetadata> metadata,
) {
  return metadata.when(
    data: (value) => value.recentSyncActivities,
    error: (error, stackTrace) => const [],
    loading: () => const [],
  );
}

String _syncActivitySubtitle(WebDavSyncActivityEntry activity) {
  final parts = <String>[_syncActivityReasonText(activity.reason)];
  if (activity.uploadedChanges > 0) {
    parts.add('上传 ${activity.uploadedChanges} 条');
  }
  if (activity.uploadedPackages > 0) {
    parts.add('上传 ${activity.uploadedPackages} 包');
  }
  if (activity.downloadedPackages > 0) {
    parts.add('下载 ${activity.downloadedPackages} 包');
  }
  if (activity.appliedRemoteChanges > 0) {
    parts.add('应用 ${activity.appliedRemoteChanges} 条');
  }
  if (activity.remoteConflicts > 0) {
    parts.add('冲突 ${activity.remoteConflicts} 条');
  }
  if (parts.length == 1) {
    parts.add('无新增变更');
  }
  return parts.join(' · ');
}

String _shortId(String value) {
  final trimmed = value.trim();
  if (trimmed.length <= 12) {
    return trimmed;
  }
  return '${trimmed.substring(0, 8)}...${trimmed.substring(trimmed.length - 4)}';
}

String _shortSequence(int value) {
  final text = value.toString();
  if (text.length <= 10) {
    return text;
  }
  return '...${text.substring(text.length - 10)}';
}

String _syncActivityReasonText(String reason) {
  return switch (reason) {
    'startup' => '启动同步',
    'interval' => '定时同步',
    'manual' => '手动同步',
    'conflictResolved' => '冲突处理后同步',
    _ => reason,
  };
}

String _syncActivityOutcomeText(String outcome) {
  return switch (outcome) {
    'success' => '成功',
    'failed' => '失败',
    _ => outcome,
  };
}

String _remoteSnapshotCountText(AsyncValue<WebDavRemoteSnapshotStatus> status) {
  return status.when(
    data: (value) => value.isConfigured ? '${value.snapshots.length}' : '未配置',
    error: (error, stackTrace) => _webDavErrorText(error),
    loading: () => '读取中',
  );
}

String _syncMetadataDateText(
  AsyncValue<WebDavSyncMetadata> metadata,
  DateTime? Function(WebDavSyncMetadata metadata) select,
) {
  return metadata.when(
    data: (value) {
      final dateTime = select(value);
      return dateTime == null ? '暂无' : _formatDateTime(dateTime);
    },
    error: (error, stackTrace) => '读取失败',
    loading: () => '读取中',
  );
}

String _syncMetadataText(
  AsyncValue<WebDavSyncMetadata> metadata,
  String? Function(WebDavSyncMetadata metadata) select,
) {
  return metadata.when(
    data: (value) {
      final text = select(value)?.trim();
      return text == null || text.isEmpty ? '暂无' : text;
    },
    error: (error, stackTrace) => '读取失败',
    loading: () => '读取中',
  );
}

String _webDavActionText(WebDavSyncActionState state) {
  final label = _webDavActionOperationText(state.operation);
  if (state.isLoading) {
    return '正在$label';
  }
  if (state.error != null) {
    return '$label失败';
  }
  return '空闲';
}

String _webDavActionOperationText(WebDavSyncActionOperation operation) {
  return switch (operation) {
    WebDavSyncActionOperation.idle => '同步',
    WebDavSyncActionOperation.saveConfig => '保存配置',
    WebDavSyncActionOperation.clearConfig => '清除配置',
    WebDavSyncActionOperation.saveSyncPreferences => '保存同步设置',
    WebDavSyncActionOperation.saveAutoSyncPassword => '保存同步密码',
    WebDavSyncActionOperation.clearAutoSyncPassword => '清除同步密码',
    WebDavSyncActionOperation.testConnection => '测试连接',
    WebDavSyncActionOperation.deltaSyncNow => '增量同步',
    WebDavSyncActionOperation.uploadLatestLocalSnapshot => '上传本机快照',
    WebDavSyncActionOperation.downloadRemoteSnapshot => '下载云端快照',
    WebDavSyncActionOperation.exportAndUploadSnapshot => '创建并上传快照',
    WebDavSyncActionOperation.restoreRemoteSnapshot => '恢复云端快照',
    WebDavSyncActionOperation.deleteRemoteSnapshot => '删除云端快照',
  };
}

String _autoSyncStatusText(WebDavAutoSyncStatus status) {
  if (!status.isConfigured) {
    return '请先配置 WebDAV';
  }
  if (!status.autoUploadEnabled) {
    return '未开启';
  }
  if (!status.passwordSaved) {
    return '缺少同步密码';
  }
  if (status.isRunning) {
    return '同步中';
  }
  return '等待下次同步';
}

String _autoSyncOutcomeText(WebDavAutoSyncOutcome? outcome) {
  return switch (outcome) {
    null => '暂无',
    WebDavAutoSyncOutcome.success => '成功',
    WebDavAutoSyncOutcome.alreadyRunning => '已有同步任务运行中',
    WebDavAutoSyncOutcome.configMissing => 'WebDAV 未配置',
    WebDavAutoSyncOutcome.autoUploadDisabled => '自动上传未开启',
    WebDavAutoSyncOutcome.passwordMissing => '缺少同步密码',
    WebDavAutoSyncOutcome.failed => '失败',
  };
}

String _syncIntervalText(int minutes) {
  if (minutes < 60) {
    return '$minutes 分钟';
  }
  final hours = minutes ~/ 60;
  return hours >= 24 ? '24 小时' : '$hours 小时';
}

String _fileName(String path) {
  return path.split(RegExp(r'[\\/]')).last;
}

String _formatDateTime(DateTime value) {
  return DateFormat('yyyy-MM-dd HH:mm').format(value.toLocal());
}

String _formatSize(int bytes) {
  if (bytes < 1024) {
    return '$bytes B';
  }
  if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }
  return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
}

String _syncErrorText(Object error) {
  if (error is WebDavSyncException) {
    return _webDavErrorText(error);
  }
  return _snapshotErrorText(error);
}

String _webDavErrorText(Object error) {
  if (error is! WebDavSyncException) {
    return 'WebDAV 操作失败，请检查配置';
  }

  return switch (error.code) {
    WebDavSyncErrorCode.configMissing => '请先配置 WebDAV',
    WebDavSyncErrorCode.invalidConfig => 'WebDAV 配置不正确',
    WebDavSyncErrorCode.connectionFailed => 'WebDAV 连接失败',
    WebDavSyncErrorCode.remoteDirectoryUnavailable => '远端目录不可用',
    WebDavSyncErrorCode.passwordMissing => '请先设置同步密码',
    WebDavSyncErrorCode.uploadFailed => '上传快照失败',
    WebDavSyncErrorCode.downloadFailed => '下载快照失败',
    WebDavSyncErrorCode.deleteFailed => '删除云端快照失败',
    WebDavSyncErrorCode.restoreTimedOut => '恢复云端快照超时，请重试',
    WebDavSyncErrorCode.noLocalSnapshot => '请先创建本机快照',
    WebDavSyncErrorCode.noRemoteSnapshot => '暂无可恢复的云端快照',
  };
}

String _snapshotErrorText(Object error) {
  if (error is! DatabaseSnapshotException) {
    return '操作失败，请重试';
  }

  return switch (error.code) {
    DatabaseSnapshotErrorCode.databaseFileMissing => '未找到本地数据库文件',
    DatabaseSnapshotErrorCode.invalidPassword => '快照密码不正确',
    DatabaseSnapshotErrorCode.invalidSnapshotFormat => '快照文件格式不正确',
    DatabaseSnapshotErrorCode.incompatibleSchema => '快照版本高于当前应用，无法恢复',
    DatabaseSnapshotErrorCode.databaseValidationFailed => '快照数据库校验失败',
    DatabaseSnapshotErrorCode.exportFailed => '创建快照失败',
    DatabaseSnapshotErrorCode.restoreFailed => '恢复快照失败',
  };
}
