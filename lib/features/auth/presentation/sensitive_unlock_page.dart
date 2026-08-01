import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:go_router/go_router.dart';
import 'package:miji/core/auth/application/auth_session_controller.dart';
import 'package:miji/core/auth/application/sensitive_access_controller.dart';
import 'package:miji/core/auth/domain/auth_repository.dart';
import 'package:miji/core/auth/providers/auth_providers.dart';
import 'package:miji/core/presentation/app_page_layout.dart';
import 'package:miji/core/presentation/app_toast.dart';
import 'package:miji/core/router/app_routes.dart';
import 'package:miji/shared/widgets/app_text_field.dart';

class SensitiveUnlockPage extends ConsumerStatefulWidget {
  const SensitiveUnlockPage({required this.from, super.key});

  final String from;

  @override
  ConsumerState<SensitiveUnlockPage> createState() =>
      _SensitiveUnlockPageState();
}

class _SensitiveUnlockPageState extends ConsumerState<SensitiveUnlockPage> {
  final _passwordController = TextEditingController();
  FToast? _toast;
  bool _isSubmitting = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final target = _safeReturnLocation(widget.from);
    final session = ref.watch(authSessionControllerProvider);
    final userId = session.userId;

    return AppPageFrame(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                Icons.verified_user_outlined,
                size: 42,
                color: colorScheme.primary,
              ),
              const SizedBox(height: 18),
              Text(
                '二次认证',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '继续访问敏感模块需要再次验证。',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.45,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 22),
              if (userId == null) ...[
                Text(
                  '当前账号状态不可用，请返回首页后重新进入。',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.error,
                    height: 1.45,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 18),
              ] else ...[
                AppTextField(
                  controller: _passwordController,
                  labelText: '密码',
                  hintText: '输入当前账号密码',
                  obscureText: _obscurePassword,
                  autofocus: true,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  enableSuggestions: false,
                  autocorrect: false,
                  inputFormatters: [
                    FilteringTextInputFormatter.deny(RegExp(r'\s')),
                  ],
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    tooltip: _obscurePassword ? '显示密码' : '隐藏密码',
                    onPressed: _isSubmitting
                        ? null
                        : () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                  onSubmitted: (_) => _submit(userId, target),
                ),
                const SizedBox(height: 18),
              ],
              FilledButton.icon(
                onPressed: userId == null || _isSubmitting
                    ? null
                    : () => _submit(userId, target),
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.lock_open_rounded),
                label: Text(_isSubmitting ? '验证中' : '验证并继续'),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => context.go(AppRoutes.home),
                child: const Text('返回首页'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit(String userId, String target) async {
    if (_isSubmitting) {
      return;
    }

    final passcode = _passwordController.text;
    if (passcode.isEmpty) {
      AppToast.error(_ensureToast(), context, '请输入密码');
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await ref
          .read(authRepositoryProvider)
          .unlockLocalUser(
            LocalUnlockRequest(userId: userId, passcode: passcode),
          );
      ref.read(sensitiveAccessControllerProvider.notifier).verify();

      if (!mounted) {
        return;
      }

      context.go(target);
    } on AuthRepositoryException catch (error) {
      if (!mounted) {
        return;
      }

      AppToast.error(
        _ensureToast(),
        context,
        _sensitiveUnlockErrorText(error.code),
      );
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

String _safeReturnLocation(String from) {
  if (from == AppRoutes.unlock || !from.startsWith('/app/')) {
    return AppRoutes.home;
  }

  return from;
}

String _sensitiveUnlockErrorText(AuthRepositoryErrorCode error) {
  return switch (error) {
    AuthRepositoryErrorCode.invalidCredential => '密码不正确',
    AuthRepositoryErrorCode.userAlreadyExists ||
    AuthRepositoryErrorCode.usernameAlreadyExists ||
    AuthRepositoryErrorCode.emailAlreadyExists ||
    AuthRepositoryErrorCode.phoneAlreadyExists ||
    AuthRepositoryErrorCode.databaseWriteFailed => '验证失败，请重试',
  };
}
