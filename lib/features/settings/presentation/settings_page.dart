import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:miji/core/auth/application/auth_session_controller.dart';
import 'package:miji/core/auth/application/sensitive_access_controller.dart';
import 'package:miji/core/auth/application/forms/auth_form_inputs.dart';
import 'package:miji/core/auth/data/app_lock_store.dart';
import 'package:miji/core/auth/domain/app_lock.dart';
import 'package:miji/core/auth/domain/sensitive_access_ttl_option.dart';
import 'package:miji/core/auth/domain/auth_repository.dart';
import 'package:miji/core/auth/presentation/app_pattern_lock_input.dart';
import 'package:miji/core/auth/providers/app_lock_providers.dart';
import 'package:miji/core/auth/providers/auth_providers.dart';
import 'package:miji/core/preferences/domain/user_preferences_entity.dart';
import 'package:miji/core/preferences/providers/preferences_providers.dart';
import 'package:miji/core/presentation/app_page_layout.dart';
import 'package:miji/core/presentation/app_toast.dart';
import 'package:miji/core/presentation/components/app_content_panel.dart';
import 'package:miji/core/presentation/components/app_info_section.dart';
import 'package:miji/core/presentation/components/app_initial_avatar.dart';
import 'package:miji/core/presentation/components/app_list_item.dart';
import 'package:miji/core/presentation/components/app_responsive_dialog.dart';
import 'package:miji/core/presentation/components/app_section_header.dart';
import 'package:miji/core/router/app_routes.dart';
import 'package:miji/core/theme/app_design_tokens.dart';
import 'package:miji/core/user/domain/user_entity.dart';
import 'package:miji/core/user/providers/user_providers.dart';
import 'package:miji/features/bookkeeping/domain/money_currency_codes.dart';
import 'package:miji/features/settings/presentation/data_sync_section.dart';
import 'package:miji/shared/widgets/app_switch_field.dart';
import 'package:miji/shared/widgets/app_text_field.dart';
import 'package:miji/shared/widgets/form_dropdown.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppPageFrame(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AppSectionHeader(
              title: '设置',
              subtitle: '按类别管理账号、安全、显示、记账和同步配置',
            ),
            const SizedBox(height: 16),
            const _SettingsEntryGrid(),
          ],
        ),
      ),
    );
  }
}

class AccountSecuritySettingsPage extends ConsumerWidget {
  const AccountSecuritySettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    return _SettingsSubPageScaffold(
      title: '账户与安全',
      subtitle: '本地账号、锁定、密码和二次认证',
      child: user.when(
        data: (value) => _AccountSecuritySection(user: value),
        loading: () => const AppPlainPanel(
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (error, stackTrace) => AppErrorState(
          title: '读取用户信息失败',
          onRetry: () => ref.invalidate(currentUserProvider),
        ),
      ),
    );
  }
}

class AppearanceSettingsPage extends ConsumerWidget {
  const AppearanceSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authSessionControllerProvider);
    final preferences = ref.watch(currentUserPreferencesProvider);

    return _SettingsSubPageScaffold(
      title: '外观与显示',
      subtitle: '主题模式',
      child: preferences.when(
        data: (value) =>
            _AppearanceSection(preferences: value, userId: session.userId),
        loading: () => const AppPlainPanel(
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (error, stackTrace) => AppErrorState(
          title: '读取偏好失败',
          onRetry: () => ref.invalidate(currentUserPreferencesProvider),
        ),
      ),
    );
  }
}

class BookkeepingPreferenceSettingsPage extends ConsumerWidget {
  const BookkeepingPreferenceSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences = ref.watch(currentUserPreferencesProvider);

    return _SettingsSubPageScaffold(
      title: '记账偏好',
      subtitle: '账户、交易和预算使用的默认参数',
      child: preferences.when(
        data: (value) => _BookkeepingPreferenceSection(preferences: value),
        loading: () => const AppPlainPanel(
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (error, stackTrace) => AppErrorState(
          title: '读取偏好失败',
          onRetry: () => ref.invalidate(currentUserPreferencesProvider),
        ),
      ),
    );
  }
}

class DataSyncSettingsPage extends StatelessWidget {
  const DataSyncSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _SettingsSubPageScaffold(
      title: '数据同步',
      subtitle: 'WebDAV、快照、增量同步和旧数据导入',
      child: DataSyncSection(),
    );
  }
}

class AboutSettingsPage extends StatelessWidget {
  const AboutSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _SettingsSubPageScaffold(
      title: '关于应用',
      subtitle: '版本信息和本地优先的数据说明',
      child: _AboutSection(),
    );
  }
}

class _SettingsSubPageScaffold extends StatelessWidget {
  const _SettingsSubPageScaffold({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AppPageFrame(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppSectionHeader(
              title: title,
              subtitle: subtitle,
              primaryAction: IconButton.filledTonal(
                tooltip: '返回设置',
                onPressed: () => context.go(AppRoutes.settings),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _SettingsEntryGrid extends StatelessWidget {
  const _SettingsEntryGrid();

  @override
  Widget build(BuildContext context) {
    final entries = [
      _SettingsEntry(
        icon: Icons.verified_user_outlined,
        title: '账户与安全',
        subtitle: '账号资料、锁定、密码和二次认证',
        route: AppRoutes.settingsSecurity,
        color: Theme.of(context).colorScheme.primary,
      ),
      _SettingsEntry(
        icon: Icons.palette_outlined,
        title: '外观与显示',
        subtitle: '明暗模式和界面显示',
        route: AppRoutes.settingsAppearance,
        color: Theme.of(context).colorScheme.secondary,
      ),
      _SettingsEntry(
        icon: Icons.payments_outlined,
        title: '记账偏好',
        subtitle: '默认币种和记账模块基础参数',
        route: AppRoutes.settingsBookkeeping,
        color: Theme.of(context).colorScheme.tertiary,
      ),
      _SettingsEntry(
        icon: Icons.cloud_sync_outlined,
        title: '数据同步',
        subtitle: 'WebDAV、快照、增量同步和旧数据导入',
        route: AppRoutes.settingsSync,
        color: Theme.of(context).colorScheme.primary,
      ),
      _SettingsEntry(
        icon: Icons.info_outline_rounded,
        title: '关于应用',
        subtitle: '版本、本地优先和数据说明',
        route: AppRoutes.settingsAbout,
        color: Theme.of(context).colorScheme.secondary,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 720;
        if (!isWide) {
          return Column(
            children: [
              for (final entry in entries) ...[
                _SettingsEntryCard(entry: entry),
                if (entry != entries.last) const SizedBox(height: 10),
              ],
            ],
          );
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: entries.length,
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 420,
            mainAxisExtent: 118,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemBuilder: (context, index) =>
              _SettingsEntryCard(entry: entries[index]),
        );
      },
    );
  }
}

class _SettingsEntry {
  const _SettingsEntry({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.route,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String route;
  final Color color;
}

class _SettingsEntryCard extends StatelessWidget {
  const _SettingsEntryCard({required this.entry});

  final _SettingsEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AppListItemPanel(
      onTap: () => context.go(entry.route),
      backgroundColor: colorScheme.surfaceContainerLowest,
      child: Row(
        children: [
          AppListItemIcon(icon: entry.icon, color: entry.color, size: 42),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  entry.subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.35,
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

class _AccountSecuritySection extends ConsumerStatefulWidget {
  const _AccountSecuritySection({required this.user});

  final UserEntity? user;

  @override
  ConsumerState<_AccountSecuritySection> createState() =>
      _AccountSecuritySectionState();
}

class _AccountSecuritySectionState
    extends ConsumerState<_AccountSecuritySection> {
  bool _isUpdatingAvatar = false;
  FToast? _toast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final effectiveUser = widget.user;

    if (effectiveUser == null) {
      return const AppPlainPanel(
        child: AppEmptyState(
          title: '未读取到当前用户',
          message: '请重新登录后再进入设置。',
          icon: Icons.person_off_outlined,
        ),
      );
    }

    final initial = _userInitial(effectiveUser);

    return AppContentPanel(
      leadingIcon: Icons.verified_user_outlined,
      leadingColor: colorScheme.primary,
      title: '账户与安全',
      subtitle: '本地账号、锁定和退出操作',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _EditableAccountAvatar(
                initial: initial,
                avatarUri: effectiveUser.avatarUri,
                isUpdating: _isUpdatingAvatar,
                onTap: () => _showAvatarActions(effectiveUser),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      effectiveUser.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      effectiveUser.email,
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
            ],
          ),
          const SizedBox(height: 14),
          AppInfoSection(
            title: '账号资料',
            children: [
              AppInfoRow(label: '用户名', value: effectiveUser.username),
              AppInfoRow(
                label: '邮箱状态',
                value: effectiveUser.emailVerifiedAt == null ? '未验证' : '已验证',
              ),
              AppInfoRow(
                label: '手机号',
                value: effectiveUser.phoneNumber?.trim().isNotEmpty == true
                    ? effectiveUser.phoneNumber!
                    : '未绑定',
              ),
            ],
          ),
          const SizedBox(height: 12),
          const _SensitiveAccessTtlPreferenceField(),
          const SizedBox(height: 12),
          _AppLockPreferenceField(userId: effectiveUser.id),
          const SizedBox(height: 8),
          _SettingsActionRow(
            icon: Icons.password_rounded,
            title: '修改密码',
            subtitle: '更新本地登录和解锁密码',
            onTap: () {
              _showChangePasswordDialog(context, effectiveUser.id);
            },
          ),
          const SizedBox(height: 8),
          _SettingsActionRow(
            icon: Icons.logout_rounded,
            title: '退出登录',
            subtitle: '清除本机已记住的当前账号',
            destructive: true,
            onTap: () {
              ref.read(authSessionControllerProvider.notifier).clear();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showAvatarActions(UserEntity user) async {
    if (_isUpdatingAvatar) {
      return;
    }

    final action = await showAppResponsiveDialog<_AvatarAction>(
      context: context,
      builder: (_) => _AvatarActionDialog(hasAvatar: _hasAvatar(user)),
    );
    if (!mounted || action == null) {
      return;
    }

    switch (action) {
      case _AvatarAction.pickGallery:
        await _pickAvatarFromGallery(user);
      case _AvatarAction.remove:
        await _removeAvatar(user);
    }
  }

  Future<void> _pickAvatarFromGallery(UserEntity user) async {
    setState(() {
      _isUpdatingAvatar = true;
    });

    File? copiedAvatar;
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 88,
        maxWidth: 1024,
        maxHeight: 1024,
      );
      if (picked == null || !mounted) {
        return;
      }

      final avatarsDir = await _avatarDirectory();
      copiedAvatar = await _copyPickedAvatar(
        picked: picked,
        user: user,
        avatarsDir: avatarsDir,
      );
      if (!mounted) {
        await _deleteFileIfExists(copiedAvatar);
        return;
      }
      await ref
          .read(userRepositoryProvider)
          .updateAvatarUri(user.id, copiedAvatar.path);
      ref.invalidate(userByIdProvider(user.id));
      ref.invalidate(currentUserProvider);
      await _deleteAppOwnedAvatarIfNeeded(user.avatarUri, avatarsDir);

      if (!mounted) {
        return;
      }
      AppToast.success(_ensureToast(), context, '头像已更新');
    } catch (_) {
      if (copiedAvatar != null) {
        await _deleteFileIfExists(copiedAvatar);
      }
      if (!mounted) {
        return;
      }
      AppToast.error(_ensureToast(), context, '头像更新失败，请重试');
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingAvatar = false;
        });
      }
    }
  }

  Future<void> _removeAvatar(UserEntity user) async {
    if (!_hasAvatar(user)) {
      return;
    }

    setState(() {
      _isUpdatingAvatar = true;
    });

    try {
      final avatarsDir = await _avatarDirectory();
      if (!mounted) {
        return;
      }
      await ref.read(userRepositoryProvider).updateAvatarUri(user.id, null);
      ref.invalidate(userByIdProvider(user.id));
      ref.invalidate(currentUserProvider);
      await _deleteAppOwnedAvatarIfNeeded(user.avatarUri, avatarsDir);

      if (!mounted) {
        return;
      }
      AppToast.success(_ensureToast(), context, '头像已移除');
    } catch (_) {
      if (!mounted) {
        return;
      }
      AppToast.error(_ensureToast(), context, '头像更新失败，请重试');
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingAvatar = false;
        });
      }
    }
  }

  Future<void> _showChangePasswordDialog(
    BuildContext context,
    String userId,
  ) async {
    final changed = await showAppResponsiveDialog<bool>(
      context: context,
      builder: (_) => _ChangePasswordDialog(userId: userId),
    );

    if (changed == true && context.mounted) {
      AppToast.success(FToast()..init(context), context, '密码已更新');
    }
  }

  bool _hasAvatar(UserEntity user) {
    return user.avatarUri?.trim().isNotEmpty == true;
  }

  FToast _ensureToast() {
    return _toast ??= (FToast()..init(context));
  }
}

enum _AvatarAction { pickGallery, remove }

class _EditableAccountAvatar extends StatelessWidget {
  const _EditableAccountAvatar({
    required this.initial,
    required this.avatarUri,
    required this.isUpdating,
    required this.onTap,
  });

  final String initial;
  final String? avatarUri;
  final bool isUpdating;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final radius = theme.radiusTokens;

    return Semantics(
      button: true,
      label: '更新头像',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isUpdating ? null : onTap,
          borderRadius: BorderRadius.circular(radius.lg),
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                AppInitialAvatar(initial: initial, avatarUri: avatarUri),
                Positioned(
                  right: -4,
                  bottom: -4,
                  child: Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: colorScheme.surface, width: 2),
                    ),
                    child: isUpdating
                        ? SizedBox(
                            width: 11,
                            height: 11,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.8,
                              color: colorScheme.onPrimary,
                            ),
                          )
                        : Icon(
                            Icons.edit_rounded,
                            size: 12,
                            color: colorScheme.onPrimary,
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AvatarActionDialog extends StatelessWidget {
  const _AvatarActionDialog({required this.hasAvatar});

  final bool hasAvatar;

  @override
  Widget build(BuildContext context) {
    return AppDialogScaffold(
      title: '更新头像',
      subtitle: '头像图片会复制到本机应用目录',
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _AvatarActionTile(
            icon: Icons.photo_library_rounded,
            title: '从相册选择',
            subtitle: '选择一张本地图片作为当前账号头像',
            onTap: () => Navigator.of(context).pop(_AvatarAction.pickGallery),
          ),
          if (hasAvatar) ...[
            const SizedBox(height: 8),
            _AvatarActionTile(
              icon: Icons.delete_outline_rounded,
              title: '移除头像',
              subtitle: '恢复为姓名首字头像',
              destructive: true,
              onTap: () => Navigator.of(context).pop(_AvatarAction.remove),
            ),
          ],
        ],
      ),
      actions: [
        IconButton(
          tooltip: '取消',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close_rounded),
        ),
      ],
    );
  }
}

class _AvatarActionTile extends StatelessWidget {
  const _AvatarActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final tone = destructive ? colorScheme.error : colorScheme.primary;

    return AppListItemPanel(
      onTap: onTap,
      backgroundColor: colorScheme.surfaceContainerHighest.withValues(
        alpha: 0.46,
      ),
      child: Row(
        children: [
          AppListItemIcon(icon: icon, color: tone, size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: destructive
                        ? colorScheme.error
                        : colorScheme.onSurface,
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

Future<Directory> _avatarDirectory() async {
  final appDir = await getApplicationSupportDirectory();
  final avatarDir = Directory(_joinPath(appDir.path, 'avatars'));
  if (!await avatarDir.exists()) {
    await avatarDir.create(recursive: true);
  }
  return avatarDir;
}

Future<File> _copyPickedAvatar({
  required XFile picked,
  required UserEntity user,
  required Directory avatarsDir,
}) async {
  final fileName = _avatarFileName(user: user, sourcePath: picked.path);
  final target = File(_joinPath(avatarsDir.path, fileName));
  await picked.saveTo(target.path);
  return target;
}

String _avatarFileName({required UserEntity user, required String sourcePath}) {
  final safeUserId = user.id.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
  final timestamp = DateTime.now().toUtc().microsecondsSinceEpoch;
  return 'user_${safeUserId}_$timestamp${_safeFileExtension(sourcePath)}';
}

String _safeFileExtension(String sourcePath) {
  final fileName = sourcePath.split(RegExp(r'[\\/]')).last;
  final dotIndex = fileName.lastIndexOf('.');
  if (dotIndex <= 0 || dotIndex == fileName.length - 1) {
    return '.jpg';
  }

  final extension = fileName.substring(dotIndex).toLowerCase();
  final validExtension = RegExp(r'^\.[a-z0-9]{1,8}$').hasMatch(extension);
  return validExtension ? extension : '.jpg';
}

Future<void> _deleteAppOwnedAvatarIfNeeded(
  String? avatarUri,
  Directory avatarsDir,
) async {
  final normalizedAvatarUri = avatarUri?.trim();
  if (normalizedAvatarUri == null || normalizedAvatarUri.isEmpty) {
    return;
  }

  if (!_isInsideDirectory(normalizedAvatarUri, avatarsDir)) {
    return;
  }

  await _deleteFileIfExists(File(normalizedAvatarUri));
}

Future<void> _deleteFileIfExists(File file) async {
  try {
    if (await file.exists()) {
      await file.delete();
    }
  } catch (_) {
    // Best-effort cleanup; the saved avatar path is the source of truth.
  }
}

bool _isInsideDirectory(String path, Directory directory) {
  final normalizedPath = _normalizeLocalPath(path);
  final normalizedDirectory = _normalizeLocalPath(directory.path);
  return normalizedPath.startsWith(
    '$normalizedDirectory${Platform.pathSeparator}',
  );
}

String _normalizeLocalPath(String path) {
  final normalized = path.replaceAll(RegExp(r'[\\/]'), Platform.pathSeparator);
  return Platform.isWindows ? normalized.toLowerCase() : normalized;
}

String _joinPath(String directory, String child) {
  if (directory.endsWith(Platform.pathSeparator)) {
    return '$directory$child';
  }
  return '$directory${Platform.pathSeparator}$child';
}

class _AppLockPreferenceField extends ConsumerStatefulWidget {
  const _AppLockPreferenceField({required this.userId});

  final String userId;

  @override
  ConsumerState<_AppLockPreferenceField> createState() =>
      _AppLockPreferenceFieldState();
}

class _AppLockPreferenceFieldState
    extends ConsumerState<_AppLockPreferenceField> {
  bool _isSaving = false;
  FToast? _toast;

  Future<void> _setEnabled(bool enabled) async {
    if (_isSaving) {
      return;
    }

    final settings = await ref.read(
      appLockSettingsProvider(widget.userId).future,
    );
    if (!mounted) {
      return;
    }
    if (enabled && !settings.hasCredential) {
      await _showCredentialDialog(enableAfterSave: true);
      return;
    }

    setState(() {
      _isSaving = true;
    });
    try {
      await ref.read(appLockStoreProvider).setEnabled(widget.userId, enabled);
      ref.invalidate(appLockSettingsProvider(widget.userId));
      if (!mounted) {
        return;
      }
      AppToast.success(_ensureToast(), context, enabled ? '锁屏已开启' : '锁屏已关闭');
    } catch (_) {
      if (!mounted) {
        return;
      }
      AppToast.error(_ensureToast(), context, '锁屏设置保存失败，请重试');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _showCredentialDialog({required bool enableAfterSave}) async {
    final saved = await showAppResponsiveDialog<bool>(
      context: context,
      builder: (_) => _AppLockCredentialDialog(
        userId: widget.userId,
        enableAfterSave: enableAfterSave,
      ),
    );
    if (saved == true && mounted) {
      ref.invalidate(appLockSettingsProvider(widget.userId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appLockSettingsProvider(widget.userId));

    return settings.when(
      data: (value) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppListItemPanel(
            backgroundColor: Theme.of(
              context,
            ).colorScheme.surfaceContainerLowest,
            child: Row(
              children: [
                AppListItemIcon(
                  icon: Icons.screen_lock_portrait_rounded,
                  color: Theme.of(context).colorScheme.primary,
                  size: 36,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '启用锁屏',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        value.hasCredential
                            ? '当前方式：${value.method.label}'
                            : '开启后需设置 6 位 PIN 或手势图案',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Switch(
                  value: value.canLock,
                  onChanged: _isSaving ? null : _setEnabled,
                ),
              ],
            ),
          ),
          if (value.enabled && value.hasCredential) ...[
            const SizedBox(height: 8),
            _SettingsActionRow(
              icon: Icons.lock_outline_rounded,
              title: '锁定应用',
              subtitle: '回到锁屏页，下次使用 ${value.method.label} 解锁',
              onTap: () {
                ref.read(authSessionControllerProvider.notifier).lock();
              },
            ),
          ],
          if (value.hasCredential) ...[
            const SizedBox(height: 8),
            _SettingsActionRow(
              icon: Icons.gesture_rounded,
              title: '修改锁屏方式',
              subtitle: '重新设置 6 位 PIN 或手势图案',
              onTap: () => _showCredentialDialog(enableAfterSave: false),
            ),
          ],
        ],
      ),
      loading: () => const LinearProgressIndicator(minHeight: 3),
      error: (error, stackTrace) => _SettingsActionRow(
        icon: Icons.refresh_rounded,
        title: '读取锁屏设置失败',
        subtitle: '点击重试',
        onTap: () => ref.invalidate(appLockSettingsProvider(widget.userId)),
      ),
    );
  }

  FToast _ensureToast() {
    return _toast ??= (FToast()..init(context));
  }
}

class _AppLockCredentialDialog extends ConsumerStatefulWidget {
  const _AppLockCredentialDialog({
    required this.userId,
    required this.enableAfterSave,
  });

  final String userId;
  final bool enableAfterSave;

  @override
  ConsumerState<_AppLockCredentialDialog> createState() =>
      _AppLockCredentialDialogState();
}

class _AppLockCredentialDialogState
    extends ConsumerState<_AppLockCredentialDialog> {
  final _pinController = TextEditingController();
  final _confirmPinController = TextEditingController();
  AppLockMethod _method = AppLockMethod.pin;
  List<int> _pattern = const <int>[];
  List<int> _confirmPattern = const <int>[];
  bool _isSaving = false;
  String? _errorText;

  @override
  void dispose() {
    _pinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final secret = _secretText(_method, confirm: false);
    final confirmSecret = _secretText(_method, confirm: true);
    final validationError = validateAppLockSecret(_method, secret);
    if (validationError != null) {
      setState(() {
        _errorText = appLockValidationErrorText(validationError);
      });
      return;
    }
    if (secret != confirmSecret) {
      setState(() {
        _errorText = _method == AppLockMethod.pin ? '两次 PIN 不一致' : '两次手势不一致';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _errorText = null;
    });
    try {
      final store = ref.read(appLockStoreProvider);
      await store.saveCredential(
        userId: widget.userId,
        method: _method,
        secret: secret,
      );
      if (widget.enableAfterSave) {
        await store.setEnabled(widget.userId, true);
      }
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on AppLockStoreException catch (error) {
      if (mounted) {
        setState(() {
          _errorText = appLockValidationErrorText(error.validationError);
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorText = '锁屏方式保存失败，请重试';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppDialogScaffold(
      title: '设置锁屏方式',
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<AppLockMethod>(
            segments: const [
              ButtonSegment(
                value: AppLockMethod.pin,
                icon: Icon(Icons.pin_rounded),
                label: Text('PIN'),
              ),
              ButtonSegment(
                value: AppLockMethod.pattern,
                icon: Icon(Icons.gesture_rounded),
                label: Text('手势'),
              ),
            ],
            selected: {_method},
            showSelectedIcon: false,
            onSelectionChanged: _isSaving
                ? null
                : (selection) {
                    setState(() {
                      _method = selection.single;
                      _errorText = null;
                    });
                  },
          ),
          const SizedBox(height: 16),
          if (_method == AppLockMethod.pin) ...[
            AppTextField(
              controller: _pinController,
              labelText: '6 位数字 PIN',
              hintText: '输入 6 位数字',
              obscureText: true,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _confirmPinController,
              labelText: '确认 PIN',
              hintText: '再次输入 6 位数字',
              obscureText: true,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
            ),
          ] else ...[
            Text(
              '绘制手势',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 8),
            AppPatternLockInput(
              enabled: !_isSaving,
              onChanged: (value) => _pattern = value,
            ),
            const SizedBox(height: 12),
            Text(
              '再次绘制手势',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 8),
            AppPatternLockInput(
              enabled: !_isSaving,
              onChanged: (value) => _confirmPattern = value,
            ),
          ],
          if (_errorText != null) ...[
            const SizedBox(height: 12),
            Text(
              _errorText!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
                letterSpacing: 0,
              ),
            ),
          ],
        ],
      ),
      actions: [
        IconButton(
          tooltip: '取消',
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
          icon: const Icon(Icons.close_rounded),
        ),
        IconButton.filled(
          tooltip: '保存',
          onPressed: _isSaving ? null : _save,
          icon: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check_rounded),
        ),
      ],
    );
  }

  String _secretText(AppLockMethod method, {required bool confirm}) {
    return switch (method) {
      AppLockMethod.pin =>
        confirm ? _confirmPinController.text : _pinController.text,
      AppLockMethod.pattern => (confirm ? _confirmPattern : _pattern).join('-'),
    };
  }
}

class _SensitiveAccessTtlPreferenceField extends ConsumerStatefulWidget {
  const _SensitiveAccessTtlPreferenceField();

  @override
  ConsumerState<_SensitiveAccessTtlPreferenceField> createState() =>
      _SensitiveAccessTtlPreferenceFieldState();
}

class _SensitiveAccessTtlPreferenceFieldState
    extends ConsumerState<_SensitiveAccessTtlPreferenceField> {
  SensitiveAccessTtlOption? _savingTtlOption;
  FToast? _toast;

  Future<void> _updateTtlOption(SensitiveAccessTtlOption ttlOption) async {
    final preferences = ref
        .read(currentUserPreferencesProvider)
        .maybeWhen(data: (value) => value, orElse: () => null);
    final currentTtlOption =
        preferences?.sensitiveAccessTtl ??
        SensitiveAccessTtlOption.defaultOption;

    if (preferences == null ||
        ttlOption == currentTtlOption ||
        _savingTtlOption != null) {
      return;
    }

    setState(() {
      _savingTtlOption = ttlOption;
    });

    try {
      await ref
          .read(preferencesRepositoryProvider)
          .updateSensitiveAccessTtl(preferences.userId, ttlOption);
      ref
          .read(sensitiveAccessControllerProvider.notifier)
          .setTtlOption(ttlOption);
      ref.invalidate(currentUserPreferencesProvider);

      if (!mounted) {
        return;
      }

      AppToast.success(_ensureToast(), context, '二次认证有效期已更新');
    } catch (_) {
      if (!mounted) {
        return;
      }

      AppToast.error(_ensureToast(), context, '二次认证有效期更新失败，请重试');
    } finally {
      if (mounted) {
        setState(() {
          _savingTtlOption = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final preferences = ref.watch(currentUserPreferencesProvider);
    final ttlOption = preferences.maybeWhen(
      data: (value) =>
          value?.sensitiveAccessTtl ?? SensitiveAccessTtlOption.defaultOption,
      orElse: () => SensitiveAccessTtlOption.defaultOption,
    );
    final canUpdate = preferences.maybeWhen(
      data: (value) => value != null,
      orElse: () => false,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FormDropdown<SensitiveAccessTtlOption>(
          key: ValueKey('settings-sensitive-ttl-${ttlOption.storageValue}'),
          initialSelection: ttlOption,
          label: '二次认证有效期',
          width: double.infinity,
          leadingIcon: const Icon(Icons.timer_outlined),
          enabled: canUpdate && _savingTtlOption == null,
          onSelected: (value) {
            if (value != null) {
              _updateTtlOption(value);
            }
          },
          entries: SensitiveAccessTtlOption.values
              .map(
                (option) =>
                    DropdownMenuEntry(value: option, label: option.label),
              )
              .toList(),
        ),
        const SizedBox(height: 8),
        Text(
          '通过一次二次认证后，在有效期内访问记账、健康等敏感模块不再重复输入密码；应用锁屏不影响有效期，退出账号会立即失效。',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            height: 1.45,
            letterSpacing: 0,
          ),
        ),
        if (_savingTtlOption != null) ...[
          const SizedBox(height: 10),
          LinearProgressIndicator(
            minHeight: 3,
            borderRadius: BorderRadius.circular(999),
          ),
        ],
      ],
    );
  }

  FToast _ensureToast() {
    return _toast ??= (FToast()..init(context));
  }
}

class _AppearanceSection extends ConsumerStatefulWidget {
  const _AppearanceSection({required this.preferences, required this.userId});

  final UserPreferencesEntity? preferences;
  final String? userId;

  @override
  ConsumerState<_AppearanceSection> createState() => _AppearanceSectionState();
}

class _AppearanceSectionState extends ConsumerState<_AppearanceSection> {
  AppThemeModePreference? _savingThemeMode;
  bool? _savingHomeTodayAction;
  FToast? _toast;

  Future<void> _updateThemeMode(AppThemeModePreference themeMode) async {
    final userId = widget.userId;
    final preferences = widget.preferences;
    final previousThemeMode = ref.read(effectiveThemeModePreferenceProvider);

    if (userId == null || preferences == null) {
      return;
    }

    if (themeMode == previousThemeMode || _savingThemeMode != null) {
      return;
    }

    ref.read(activeThemeModePreferenceProvider.notifier).set(themeMode);
    setState(() {
      _savingThemeMode = themeMode;
    });

    try {
      await ref
          .read(preferencesRepositoryProvider)
          .updateThemeMode(userId, themeMode);
      ref.invalidate(currentUserPreferencesProvider);

      if (!mounted) {
        return;
      }

      AppToast.success(_ensureToast(), context, '主题已更新');
    } catch (_) {
      if (!mounted) {
        return;
      }

      ref
          .read(activeThemeModePreferenceProvider.notifier)
          .set(previousThemeMode);
      AppToast.error(_ensureToast(), context, '主题更新失败，请重试');
    } finally {
      if (mounted) {
        setState(() {
          _savingThemeMode = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final preferences = widget.preferences;
    final selectedThemeMode = ref.watch(effectiveThemeModePreferenceProvider);

    if (preferences == null) {
      return AppPlainPanel(
        child: Text(
          '未读取到用户偏好',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
            letterSpacing: 0,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppContentPanel(
          leadingIcon: Icons.palette_outlined,
          leadingColor: colorScheme.secondary,
          title: '外观主题',
          subtitle: '明暗模式',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<AppThemeModePreference>(
                segments: const [
                  ButtonSegment(
                    value: AppThemeModePreference.system,
                    icon: Icon(Icons.brightness_auto_rounded),
                    label: Text('系统'),
                  ),
                  ButtonSegment(
                    value: AppThemeModePreference.light,
                    icon: Icon(Icons.light_mode_rounded),
                    label: Text('浅色'),
                  ),
                  ButtonSegment(
                    value: AppThemeModePreference.dark,
                    icon: Icon(Icons.dark_mode_rounded),
                    label: Text('深色'),
                  ),
                ],
                selected: {selectedThemeMode},
                onSelectionChanged: _savingThemeMode == null
                    ? (selection) => _updateThemeMode(selection.single)
                    : null,
                showSelectedIcon: false,
                style: ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  textStyle: WidgetStatePropertyAll(
                    theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ),
              if (_savingThemeMode != null) ...[
                const SizedBox(height: 10),
                LinearProgressIndicator(
                  minHeight: 3,
                  borderRadius: BorderRadius.circular(999),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        AppContentPanel(
          leadingIcon: Icons.home_outlined,
          leadingColor: colorScheme.primary,
          title: '首页显示',
          subtitle: '控制首页各区块的显示',
          child: AppSwitchField(
            title: '今日行动',
            subtitle: '在首页顶部显示今日行动卡片',
            icon: Icons.today_outlined,
            value: preferences.showHomeTodayAction,
            onChanged: _savingHomeTodayAction == null
                ? (value) => _updateShowHomeTodayAction(value)
                : null,
          ),
        ),
      ],
    );
  }

  Future<void> _updateShowHomeTodayAction(bool show) async {
    final userId = widget.userId;
    final preferences = widget.preferences;

    if (userId == null || preferences == null) {
      return;
    }

    setState(() {
      _savingHomeTodayAction = show;
    });

    try {
      await ref
          .read(preferencesRepositoryProvider)
          .updateShowHomeTodayAction(userId, show);
      ref.invalidate(currentUserPreferencesProvider);

      if (!mounted) {
        return;
      }

      AppToast.success(_ensureToast(), context, '首页显示已更新');
    } catch (_) {
      if (!mounted) {
        return;
      }

      AppToast.error(_ensureToast(), context, '首页显示更新失败，请重试');
    } finally {
      if (mounted) {
        setState(() {
          _savingHomeTodayAction = null;
        });
      }
    }
  }

  FToast _ensureToast() {
    return _toast ??= (FToast()..init(context));
  }
}

class _BookkeepingPreferenceSection extends ConsumerStatefulWidget {
  const _BookkeepingPreferenceSection({required this.preferences});

  final UserPreferencesEntity? preferences;

  @override
  ConsumerState<_BookkeepingPreferenceSection> createState() =>
      _BookkeepingPreferenceSectionState();
}

class _BookkeepingPreferenceSectionState
    extends ConsumerState<_BookkeepingPreferenceSection> {
  String? _savingCurrencyCode;
  FToast? _toast;

  Future<void> _updateCurrencyCode(String currencyCode) async {
    final preferences = widget.preferences;
    final normalized = currencyCode.trim().toUpperCase();
    final currentCurrencyCode = _effectiveCurrencyCode(preferences);

    if (preferences == null ||
        normalized == currentCurrencyCode ||
        _savingCurrencyCode != null) {
      return;
    }

    setState(() {
      _savingCurrencyCode = normalized;
    });

    try {
      await ref
          .read(preferencesRepositoryProvider)
          .updateCurrencyCode(preferences.userId, normalized);
      ref.invalidate(currentUserPreferencesProvider);

      if (!mounted) {
        return;
      }

      AppToast.success(_ensureToast(), context, '默认币种已更新');
    } catch (_) {
      if (!mounted) {
        return;
      }

      AppToast.error(_ensureToast(), context, '默认币种更新失败，请重试');
    } finally {
      if (mounted) {
        setState(() {
          _savingCurrencyCode = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final preferences = widget.preferences;
    final currencyCode = _effectiveCurrencyCode(preferences);

    return AppContentPanel(
      leadingIcon: Icons.payments_outlined,
      leadingColor: colorScheme.tertiary,
      title: '记账偏好',
      subtitle: '账户、交易和预算使用的默认记账参数',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FormDropdown<String>(
            key: ValueKey('settings-currency-$currencyCode'),
            initialSelection: currencyCode,
            label: '默认币种',
            width: double.infinity,
            leadingIcon: const Icon(Icons.payments_rounded),
            enabled: preferences != null && _savingCurrencyCode == null,
            onSelected: (value) {
              if (value != null) {
                _updateCurrencyCode(value);
              }
            },
            entries: supportedMoneyCurrencyCodes
                .map((code) => DropdownMenuEntry(value: code, label: code))
                .toList(),
          ),
          if (_savingCurrencyCode != null) ...[
            const SizedBox(height: 10),
            LinearProgressIndicator(
              minHeight: 3,
              borderRadius: BorderRadius.circular(999),
            ),
          ],
          const SizedBox(height: 14),
          AppInfoSection(
            title: '基础偏好',
            children: [
              AppInfoRow(label: '默认币种', value: currencyCode),
              const AppInfoRow(label: '金额隐藏', value: '记账页内临时控制'),
            ],
          ),
        ],
      ),
    );
  }

  FToast _ensureToast() {
    return _toast ??= (FToast()..init(context));
  }
}

String _effectiveCurrencyCode(UserPreferencesEntity? preferences) {
  final currencyCode = preferences?.currencyCode?.trim().toUpperCase();
  if (currencyCode != null &&
      supportedMoneyCurrencyCodes.contains(currencyCode)) {
    return currencyCode;
  }
  return 'CNY';
}

class _AboutSection extends StatelessWidget {
  const _AboutSection();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AppContentPanel(
      leadingIcon: Icons.info_outline_rounded,
      leadingColor: colorScheme.primary,
      title: '关于应用',
      subtitle: '本地优先的记账、GTD 和健康管理工具',
      child: const AppInfoSection(
        title: '版本信息',
        children: [
          AppInfoRow(label: '应用', value: 'Miji'),
          AppInfoRow(label: '版本', value: '1.0.0'),
          AppInfoRow(label: '数据备份', value: '本地加密快照'),
        ],
      ),
    );
  }
}

class _SettingsActionRow extends StatelessWidget {
  const _SettingsActionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final tone = destructive ? colorScheme.error : colorScheme.primary;

    return AppListItemPanel(
      onTap: onTap,
      backgroundColor: colorScheme.surfaceContainerLowest,
      child: Row(
        children: [
          AppListItemIcon(icon: icon, color: tone, size: 36),
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

String _userInitial(UserEntity user) {
  final label = user.displayName.trim().isNotEmpty
      ? user.displayName.trim()
      : user.username.trim();

  return label.isEmpty ? '米' : String.fromCharCode(label.runes.first);
}

class _ChangePasswordDialog extends ConsumerStatefulWidget {
  const _ChangePasswordDialog({required this.userId});

  final String userId;

  @override
  ConsumerState<_ChangePasswordDialog> createState() =>
      _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends ConsumerState<_ChangePasswordDialog> {
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _submitted = false;
  bool _isSubmitting = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  FToast? _toast;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentPassword = LoginPasswordInput.dirty(_currentController.text);
    final newPassword = PasscodeInput.dirty(_newController.text);
    final confirmPassword = ConfirmPasswordInput.dirty(
      password: _newController.text,
      value: _confirmController.text,
    );
    final canSubmit =
        currentPassword.isValid &&
        newPassword.isValid &&
        confirmPassword.isValid &&
        !_isSubmitting;

    return AppDialogScaffold(
      title: '修改密码',
      subtitle: '修改后当前登录状态保持不变，下次登录和解锁使用新密码',
      maxWidth: 440,
      titleTextAlign: TextAlign.center,
      actionsAlignment: WrapAlignment.center,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField(
            controller: _currentController,
            labelText: '当前密码',
            hintText: '输入当前密码',
            obscureText: _obscureCurrent,
            autofocus: true,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.password],
            prefixIcon: const Icon(Icons.lock_outline_rounded),
            suffixIcon: _PasswordVisibilityButton(
              obscureText: _obscureCurrent,
              onPressed: () {
                setState(() {
                  _obscureCurrent = !_obscureCurrent;
                });
              },
            ),
            errorText: _submitted
                ? _currentPasswordErrorText(currentPassword.displayError)
                : null,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          AppTextField(
            controller: _newController,
            labelText: '新密码',
            hintText: '至少 6 位，最多 128 位',
            obscureText: _obscureNew,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.newPassword],
            prefixIcon: const Icon(Icons.password_rounded),
            suffixIcon: _PasswordVisibilityButton(
              obscureText: _obscureNew,
              onPressed: () {
                setState(() {
                  _obscureNew = !_obscureNew;
                });
              },
            ),
            errorText: _submitted
                ? _passcodeErrorText(newPassword.displayError)
                : null,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          AppTextField(
            controller: _confirmController,
            labelText: '确认新密码',
            hintText: '再次输入新密码',
            obscureText: _obscureConfirm,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.newPassword],
            prefixIcon: const Icon(Icons.lock_reset_rounded),
            suffixIcon: _PasswordVisibilityButton(
              obscureText: _obscureConfirm,
              onPressed: () {
                setState(() {
                  _obscureConfirm = !_obscureConfirm;
                });
              },
            ),
            errorText: _submitted
                ? _confirmPasswordErrorText(confirmPassword.displayError)
                : null,
            onSubmitted: (_) => _submit(),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actions: appDialogIconActions(
        cancelTooltip: '取消',
        confirmTooltip: _isSubmitting ? '保存中' : '保存',
        onCancel: _isSubmitting ? () {} : () => Navigator.of(context).pop(),
        onConfirm: canSubmit ? _submit : null,
        confirmIcon: _isSubmitting
            ? Icons.hourglass_top_rounded
            : Icons.check_rounded,
      ),
    );
  }

  Future<void> _submit() async {
    if (_isSubmitting) {
      return;
    }

    final currentPassword = LoginPasswordInput.dirty(_currentController.text);
    final newPassword = PasscodeInput.dirty(_newController.text);
    final confirmPassword = ConfirmPasswordInput.dirty(
      password: _newController.text,
      value: _confirmController.text,
    );

    setState(() {
      _submitted = true;
    });

    if (!currentPassword.isValid ||
        !newPassword.isValid ||
        !confirmPassword.isValid) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await ref
          .read(authRepositoryProvider)
          .changeLocalPassword(
            LocalPasswordChangeRequest(
              userId: widget.userId,
              currentPasscode: currentPassword.value,
              newPasscode: newPassword.value,
            ),
          );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(true);
    } on AuthRepositoryException catch (error) {
      if (!mounted) {
        return;
      }

      AppToast.error(_ensureToast(), context, _passwordChangeErrorText(error));
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  FToast _ensureToast() {
    return _toast ??= (FToast()..init(context));
  }
}

class _PasswordVisibilityButton extends StatelessWidget {
  const _PasswordVisibilityButton({
    required this.obscureText,
    required this.onPressed,
  });

  final bool obscureText;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: obscureText ? '显示密码' : '隐藏密码',
      onPressed: onPressed,
      icon: Icon(
        obscureText ? Icons.visibility_outlined : Icons.visibility_off_outlined,
      ),
    );
  }
}

String? _currentPasswordErrorText(LoginPasswordValidationError? error) {
  return switch (error) {
    LoginPasswordValidationError.empty => '请输入当前密码',
    null => null,
  };
}

String? _passcodeErrorText(PasscodeValidationError? error) {
  return switch (error) {
    PasscodeValidationError.empty => '请输入新密码',
    PasscodeValidationError.tooShort => '新密码至少 6 位',
    PasscodeValidationError.tooLong => '新密码最多 128 位',
    null => null,
  };
}

String? _confirmPasswordErrorText(ConfirmPasswordValidationError? error) {
  return switch (error) {
    ConfirmPasswordValidationError.empty => '请再次输入新密码',
    ConfirmPasswordValidationError.mismatch => '两次输入的新密码不一致',
    null => null,
  };
}

String _passwordChangeErrorText(AuthRepositoryException error) {
  return switch (error.code) {
    AuthRepositoryErrorCode.invalidCredential => '当前密码不正确',
    AuthRepositoryErrorCode.userAlreadyExists ||
    AuthRepositoryErrorCode.usernameAlreadyExists ||
    AuthRepositoryErrorCode.emailAlreadyExists ||
    AuthRepositoryErrorCode.phoneAlreadyExists ||
    AuthRepositoryErrorCode.databaseWriteFailed => '密码更新失败，请重试',
  };
}
