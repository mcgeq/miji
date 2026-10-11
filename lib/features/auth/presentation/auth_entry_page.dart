import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:miji/core/auth/application/forms/auth_form_inputs.dart';
import 'package:miji/core/auth/application/login_form_controller.dart';
import 'package:miji/core/auth/application/login_form_state.dart';
import 'package:miji/core/auth/application/registration_form_controller.dart';
import 'package:miji/core/auth/application/registration_form_state.dart';
import 'package:miji/core/auth/domain/auth_repository.dart';
import 'package:miji/core/auth/providers/auth_providers.dart';
import 'package:miji/core/presentation/app_responsive.dart';
import 'package:miji/core/presentation/app_toast.dart';
import 'package:miji/core/theme/app_theme_extension.dart';

enum AuthEntryMode { login, register }

class AuthEntryPage extends ConsumerStatefulWidget {
  const AuthEntryPage({super.key, this.initialMode = AuthEntryMode.login});

  final AuthEntryMode initialMode;

  @override
  ConsumerState<AuthEntryPage> createState() => _AuthEntryPageState();
}

class _AuthEntryPageState extends ConsumerState<AuthEntryPage>
    with TickerProviderStateMixin {
  late AuthEntryMode _mode;
  late AnimationController _entryCtrl;
  FToast? _toast;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
    _loadRememberedEmail();
  }

  Future<void> _loadRememberedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('remembered_email');
    if (email != null && email.isNotEmpty && mounted) {
      ref.read(localLoginFormControllerProvider.notifier).reset(email: email);
    }
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loginState = ref.watch(localLoginFormControllerProvider);
    final loginController = ref.read(localLoginFormControllerProvider.notifier);
    final registrationState = ref.watch(registrationFormControllerProvider);
    final registrationController = ref.read(
      registrationFormControllerProvider.notifier,
    );
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final semanticColors = theme.extension<AppSemanticColors>();

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final responsive = AppResponsive.of(
              context,
              width: constraints.maxWidth,
            );
            final isWide = responsive.isExpanded;
            final horizontalPadding = isWide ? 56.0 : 20.0;
            final verticalPadding = isWide ? 48.0 : 24.0;
            final minimumContentHeight =
                constraints.maxHeight > verticalPadding * 2
                ? constraints.maxHeight - verticalPadding * 2
                : 0.0;
            final totalElements = _mode == AuthEntryMode.login ? 7 : 8;
            final form = _mode == AuthEntryMode.login
                ? _LoginForm(
                    state: loginState,
                    controller: loginController,
                    entryCtrl: _entryCtrl,
                    totalElements: totalElements,
                    onSubmit: () => _submitLogin(loginController),
                    onShowRegister: () => _showRegister(registrationController),
                  )
                : _RegistrationForm(
                    state: registrationState,
                    controller: registrationController,
                    entryCtrl: _entryCtrl,
                    totalElements: totalElements,
                    onSubmit: () => _submitRegistration(
                      registrationController,
                      loginController,
                    ),
                    onShowLogin: () =>
                        _showLoginFromRegistration(registrationController),
                  );

            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: verticalPadding,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: minimumContentHeight),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1040),
                    child: Stack(
                      children: [
                        Positioned(
                          top: -20,
                          right: -60,
                          child: _BlurCircle(
                            size: 160,
                            color: colorScheme.primary.withValues(alpha: 0.08),
                          ),
                        ),
                        Positioned(
                          bottom: -40,
                          left: -80,
                          child: _BlurCircle(
                            size: 200,
                            color: colorScheme.secondary.withValues(
                              alpha: 0.06,
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: -20,
                          right: -20,
                          child: _BlurCircle(
                            size: 120,
                            color: colorScheme.tertiary.withValues(alpha: 0.06),
                          ),
                        ),
                        if (isWide)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: _BrandIntro(
                                  focusColor:
                                      semanticColors?.focus ??
                                      colorScheme.tertiary,
                                ),
                              ),
                              const SizedBox(width: 48),
                              SizedBox(width: 420, child: form),
                            ],
                          )
                        else
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [form],
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _submitLogin(LoginFormController controller) async {
    final result = await controller.submit();
    if (!mounted) {
      return;
    }

    final state = ref.read(localLoginFormControllerProvider);
    final submitError = state.submitError;
    if (result != null) {
      final prefs = await SharedPreferences.getInstance();
      if (state.rememberEmail) {
        await prefs.setString('remembered_email', state.email.value);
      } else {
        await prefs.remove('remembered_email');
      }
      if (!mounted) return;
      AppToast.success(_ensureToast(), context, '登录成功');
    } else if (submitError != null) {
      AppToast.error(_ensureToast(), context, _submitErrorText(submitError));
    }
  }

  Future<void> _submitRegistration(
    RegistrationFormController registrationController,
    LoginFormController loginController,
  ) async {
    final result = await registrationController.submit();
    if (!mounted) {
      return;
    }

    final submitError = ref
        .read(registrationFormControllerProvider)
        .submitError;
    if (result == null) {
      if (submitError != null) {
        AppToast.error(_ensureToast(), context, _submitErrorText(submitError));
      }
      return;
    }

    registrationController.reset();
    loginController.reset();
    ref.invalidate(authOnboardingRequiredProvider);
    _showLogin();
    AppToast.success(_ensureToast(), context, '注册成功，请使用邮箱登录');
  }

  FToast _ensureToast() {
    return _toast ??= (FToast()..init(context));
  }

  void _showLogin() {
    _switchMode(AuthEntryMode.login);
  }

  void _showLoginFromRegistration(
    RegistrationFormController registrationController,
  ) {
    registrationController.reset();
    _switchMode(AuthEntryMode.login);
  }

  void _showRegister(RegistrationFormController registrationController) {
    registrationController.reset();
    _switchMode(AuthEntryMode.register);
  }

  void _switchMode(AuthEntryMode mode) {
    setState(() {
      _mode = mode;
    });
    _entryCtrl.reset();
    _entryCtrl.forward();
  }
}

class _BrandIntro extends StatelessWidget {
  const _BrandIntro({required this.focusColor});

  final Color focusColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _AppMark(color: colorScheme.primary),
          const SizedBox(height: 28),
          Text(
            'Miji',
            style: theme.textTheme.headlineMedium?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w700,
              height: 1.15,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 28),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _DomainChip(
                color: colorScheme.secondary,
                label: '记账',
                icon: Icons.payments_outlined,
              ),
              _DomainChip(
                color: colorScheme.tertiary,
                label: '经期',
                icon: Icons.favorite_border_rounded,
              ),
              _DomainChip(
                color: focusColor,
                label: 'GTD',
                icon: Icons.checklist_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AppMark extends StatelessWidget {
  const _AppMark({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: 48,
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '米',
        style: theme.textTheme.titleLarge?.copyWith(
          color: colorScheme.onPrimary,
          fontWeight: FontWeight.w700,
          height: 1,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _DomainChip extends StatelessWidget {
  const _DomainChip({
    required this.color,
    required this.label,
    required this.icon,
  });

  final Color color;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: color),
          const SizedBox(width: 7),
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _BlurCircle extends StatelessWidget {
  const _BlurCircle({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: color, blurRadius: 50, spreadRadius: 30)],
      ),
    );
  }
}

class _StaggerFadeSlide extends StatelessWidget {
  const _StaggerFadeSlide({
    required this.controller,
    required this.index,
    required this.total,
    required this.child,
  });

  final AnimationController controller;
  final int index;
  final int total;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final interval = Interval(index / total, (index + 1) / total);
    final animation = CurvedAnimation(parent: controller, curve: interval);
    return AnimatedBuilder(
      animation: animation,
      builder: (_, c) {
        final v = animation.value;
        return Opacity(
          opacity: v,
          child: Transform.translate(offset: Offset(0, 20 * (1 - v)), child: c),
        );
      },
      child: child,
    );
  }
}

class _StyledTextField extends StatelessWidget {
  const _StyledTextField({
    required this.hintText,
    required this.icon,
    required this.iconBackgroundColor,
    required this.iconColor,
    required this.onChanged,
    this.hintStyle,
    this.obscureText = false,
    this.errorText,
    this.supportingText,
    this.supportingColor,
    this.autofillHints,
    this.textInputAction,
    this.keyboardType,
    this.onFocusLost,
  });

  final String hintText;
  final TextStyle? hintStyle;
  final IconData icon;
  final Color iconBackgroundColor;
  final Color iconColor;
  final ValueChanged<String> onChanged;
  final bool obscureText;
  final String? errorText;
  final String? supportingText;
  final Color? supportingColor;
  final Iterable<String>? autofillHints;
  final TextInputAction? textInputAction;
  final TextInputType? keyboardType;
  final VoidCallback? onFocusLost;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final effectiveHintStyle =
        hintStyle ??
        theme.inputDecorationTheme.hintStyle ??
        TextStyle(fontSize: 16, color: colorScheme.onSurfaceVariant);
    return Focus(
      onFocusChange: (hasFocus) {
        if (!hasFocus) onFocusLost?.call();
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 52,
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: errorText != null
                    ? colorScheme.error
                    : colorScheme.outline.withValues(alpha: 0.3),
              ),
            ),
            padding: const EdgeInsets.all(4),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: iconBackgroundColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    onChanged: onChanged,
                    obscureText: obscureText,
                    autofillHints: autofillHints,
                    textInputAction: textInputAction,
                    keyboardType: keyboardType,
                    textCapitalization: TextCapitalization.none,
                    enableSuggestions: !obscureText,
                    autocorrect: false,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurface,
                      height: 1.25,
                      letterSpacing: 0,
                    ),
                    decoration: InputDecoration(
                      hintText: hintText,
                      hintStyle: effectiveHintStyle,
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (errorText == null && supportingText != null)
            Padding(
              padding: const EdgeInsets.only(left: 16, top: 4),
              child: Text(
                supportingText!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: supportingColor ?? colorScheme.onSurfaceVariant,
                  height: 1.25,
                  letterSpacing: 0,
                ),
              ),
            ),
          if (errorText != null)
            Padding(
              padding: const EdgeInsets.only(left: 16, top: 4),
              child: Text(
                errorText!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.error,
                  height: 1.25,
                  letterSpacing: 0,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _LoginForm extends StatelessWidget {
  const _LoginForm({
    required this.state,
    required this.controller,
    required this.entryCtrl,
    required this.totalElements,
    required this.onSubmit,
    required this.onShowRegister,
  });

  final LoginFormState state;
  final LoginFormController controller;
  final AnimationController entryCtrl;
  final int totalElements;
  final VoidCallback onSubmit;
  final VoidCallback onShowRegister;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return _FormSurface(
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _StaggerFadeSlide(
              controller: entryCtrl,
              index: 0,
              total: totalElements,
              child: Text(
                '登录',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                  letterSpacing: 0,
                ),
              ),
            ),
            const SizedBox(height: 24),
            _StaggerFadeSlide(
              controller: entryCtrl,
              index: 2,
              total: totalElements,
              child: _StyledTextField(
                hintText: 'you@example.com',
                icon: Icons.mail_outline_rounded,
                iconBackgroundColor: const Color(0xffDEF5E9),
                iconColor: const Color(0xff5FC88F),
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                textInputAction: TextInputAction.next,
                errorText: _emailErrorText(state.email.displayError),
                onChanged: controller.emailChanged,
              ),
            ),
            const SizedBox(height: 14),
            _StaggerFadeSlide(
              controller: entryCtrl,
              index: 3,
              total: totalElements,
              child: _StyledTextField(
                hintText: '输入密码',
                icon: Icons.lock_outline_rounded,
                iconBackgroundColor: const Color(0xffEBECFF),
                iconColor: const Color(0xff9F9DF3),
                obscureText: true,
                autofillHints: const [AutofillHints.password],
                textInputAction: TextInputAction.done,
                errorText: _loginPasswordErrorText(state.password.displayError),
                onChanged: controller.passcodeChanged,
              ),
            ),
            const SizedBox(height: 8),
            _StaggerFadeSlide(
              controller: entryCtrl,
              index: 4,
              total: totalElements,
              child: _RememberMeCheckbox(
                value: state.rememberEmail,
                onChanged: controller.rememberEmailChanged,
              ),
            ),
            const SizedBox(height: 10),
            _StaggerFadeSlide(
              controller: entryCtrl,
              index: 5,
              total: totalElements,
              child: FilledButton.icon(
                onPressed: state.canSubmit ? onSubmit : null,
                icon: state.isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.login_rounded),
                label: Text(state.isSubmitting ? '登录中' : '登录'),
                style: _primaryButtonStyle(theme),
              ),
            ),
            const SizedBox(height: 16),
            _StaggerFadeSlide(
              controller: entryCtrl,
              index: 5,
              total: totalElements,
              child: _ModeSwitchButton(
                leadingText: '还没有账号？',
                actionText: '注册',
                onPressed: onShowRegister,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RegistrationForm extends StatelessWidget {
  const _RegistrationForm({
    required this.state,
    required this.controller,
    required this.entryCtrl,
    required this.totalElements,
    required this.onSubmit,
    required this.onShowLogin,
  });

  final RegistrationFormState state;
  final RegistrationFormController controller;
  final AnimationController entryCtrl;
  final int totalElements;
  final VoidCallback onSubmit;
  final VoidCallback onShowLogin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return _FormSurface(
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _StaggerFadeSlide(
              controller: entryCtrl,
              index: 0,
              total: totalElements,
              child: Text(
                '注册',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                  letterSpacing: 0,
                ),
              ),
            ),
            const SizedBox(height: 24),
            _StaggerFadeSlide(
              controller: entryCtrl,
              index: 2,
              total: totalElements,
              child: _StyledTextField(
                hintText: '3-20 位小写字母、数字或下划线',
                hintStyle: TextStyle(fontSize: 12),
                icon: Icons.person_outline_rounded,
                iconBackgroundColor: const Color(0xffFFEBE4),
                iconColor: const Color(0xfff7931a),
                autofillHints: const [AutofillHints.username],
                textInputAction: TextInputAction.next,
                errorText: _usernameErrorText(state.username.displayError),
                supportingText: _usernameAvailabilityText(state),
                supportingColor: _availabilityColor(
                  state.usernameAvailability,
                  colorScheme,
                ),
                onChanged: controller.usernameChanged,
                onFocusLost: controller.usernameFocusLost,
              ),
            ),
            const SizedBox(height: 14),
            _StaggerFadeSlide(
              controller: entryCtrl,
              index: 3,
              total: totalElements,
              child: _StyledTextField(
                hintText: 'you@example.com',
                hintStyle: TextStyle(fontSize: 12),
                icon: Icons.mail_outline_rounded,
                iconBackgroundColor: const Color(0xffDEF5E9),
                iconColor: const Color(0xff5FC88F),
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                textInputAction: TextInputAction.next,
                errorText: _emailErrorText(state.email.displayError),
                supportingText: _emailAvailabilityText(state),
                supportingColor: _availabilityColor(
                  state.emailAvailability,
                  colorScheme,
                ),
                onChanged: controller.emailChanged,
                onFocusLost: controller.emailFocusLost,
              ),
            ),
            const SizedBox(height: 14),
            _StaggerFadeSlide(
              controller: entryCtrl,
              index: 4,
              total: totalElements,
              child: _StyledTextField(
                hintText: '至少 6 位',
                hintStyle: TextStyle(fontSize: 12),
                icon: Icons.lock_outline_rounded,
                iconBackgroundColor: const Color(0xffEBECFF),
                iconColor: const Color(0xff9F9DF3),
                obscureText: true,
                autofillHints: const [AutofillHints.newPassword],
                textInputAction: TextInputAction.next,
                errorText: _passcodeErrorText(state.passcode.displayError),
                onChanged: controller.passcodeChanged,
              ),
            ),
            const SizedBox(height: 14),
            _StaggerFadeSlide(
              controller: entryCtrl,
              index: 5,
              total: totalElements,
              child: _StyledTextField(
                hintText: '再次输入密码',
                hintStyle: TextStyle(fontSize: 12),
                icon: Icons.lock_reset_rounded,
                iconBackgroundColor: const Color(0xffE0F2FE),
                iconColor: const Color(0xff38BDF8),
                obscureText: true,
                autofillHints: const [AutofillHints.newPassword],
                textInputAction: TextInputAction.done,
                errorText: _confirmPasswordErrorText(
                  state.confirmPassword.displayError,
                ),
                onChanged: controller.confirmPasswordChanged,
              ),
            ),
            const SizedBox(height: 18),
            _StaggerFadeSlide(
              controller: entryCtrl,
              index: 6,
              total: totalElements,
              child: FilledButton.icon(
                onPressed: state.canSubmit ? onSubmit : null,
                icon: state.isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.person_add_alt_1_rounded),
                label: Text(state.isSubmitting ? '注册中' : '注册'),
                style: _primaryButtonStyle(theme),
              ),
            ),
            const SizedBox(height: 16),
            _StaggerFadeSlide(
              controller: entryCtrl,
              index: 7,
              total: totalElements,
              child: _ModeSwitchButton(
                leadingText: '已有账号？',
                actionText: '登录',
                onPressed: onShowLogin,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FormSurface extends StatelessWidget {
  const _FormSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.8)),
      ),
      child: Padding(padding: const EdgeInsets.all(24), child: child),
    );
  }
}

class _RememberMeCheckbox extends StatelessWidget {
  const _RememberMeCheckbox({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return GestureDetector(
      onTap: () => onChanged(!value),
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: Checkbox(
              value: value,
              onChanged: (v) => onChanged(v ?? false),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '记住邮箱',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeSwitchButton extends StatelessWidget {
  const _ModeSwitchButton({
    required this.leadingText,
    required this.actionText,
    required this.onPressed,
  });

  final String leadingText;
  final String actionText;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Flexible(
          child: Text(
            leadingText,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              letterSpacing: 0,
            ),
          ),
        ),
        TextButton(onPressed: onPressed, child: Text(actionText)),
      ],
    );
  }
}

ButtonStyle _primaryButtonStyle(ThemeData theme) {
  return FilledButton.styleFrom(
    minimumSize: const Size.fromHeight(50),
    textStyle: theme.textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: 0,
    ),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
  );
}

String? _usernameAvailabilityText(RegistrationFormState state) {
  if (!state.username.isValid) {
    return null;
  }

  return switch (state.usernameAvailability) {
    FieldAvailabilityStatus.checking => '正在检查用户名是否可用...',
    FieldAvailabilityStatus.available => '用户名可用',
    FieldAvailabilityStatus.unavailable => '用户名已存在',
    FieldAvailabilityStatus.unchecked => null,
  };
}

String? _emailAvailabilityText(RegistrationFormState state) {
  if (!state.email.isValid) {
    return null;
  }

  return switch (state.emailAvailability) {
    FieldAvailabilityStatus.checking => '正在检查邮箱是否可用...',
    FieldAvailabilityStatus.available => '邮箱可用',
    FieldAvailabilityStatus.unavailable => '邮箱已存在',
    FieldAvailabilityStatus.unchecked => null,
  };
}

Color? _availabilityColor(
  FieldAvailabilityStatus status,
  ColorScheme colorScheme,
) {
  return switch (status) {
    FieldAvailabilityStatus.available => colorScheme.secondary,
    FieldAvailabilityStatus.unavailable => colorScheme.error,
    FieldAvailabilityStatus.checking ||
    FieldAvailabilityStatus.unchecked => colorScheme.onSurfaceVariant,
  };
}

String? _usernameErrorText(UsernameValidationError? error) {
  return switch (error) {
    UsernameValidationError.empty => '请输入用户名',
    UsernameValidationError.tooShort => '用户名至少 3 个字符',
    UsernameValidationError.tooLong => '用户名最多 20 个字符',
    UsernameValidationError.invalidStart => '用户名需要以字母开头',
    UsernameValidationError.invalidCharacters => '仅支持小写字母、数字和下划线',
    null => null,
  };
}

String? _emailErrorText(EmailValidationError? error) {
  return switch (error) {
    EmailValidationError.empty => '请输入邮箱',
    EmailValidationError.tooLong => '邮箱长度过长',
    EmailValidationError.invalid => '邮箱格式不正确',
    null => null,
  };
}

String? _passcodeErrorText(PasscodeValidationError? error) {
  return switch (error) {
    PasscodeValidationError.empty => '请输入密码',
    PasscodeValidationError.tooShort => '密码至少 6 位',
    PasscodeValidationError.tooLong => '密码最多 128 位',
    null => null,
  };
}

String? _loginPasswordErrorText(LoginPasswordValidationError? error) {
  return switch (error) {
    LoginPasswordValidationError.empty => '请输入密码',
    null => null,
  };
}

String? _confirmPasswordErrorText(ConfirmPasswordValidationError? error) {
  return switch (error) {
    ConfirmPasswordValidationError.empty => '请再次输入密码',
    ConfirmPasswordValidationError.mismatch => '两次输入的密码不一致',
    null => null,
  };
}

String _submitErrorText(AuthRepositoryErrorCode error) {
  return switch (error) {
    AuthRepositoryErrorCode.userAlreadyExists => '当前设备已注册账号',
    AuthRepositoryErrorCode.usernameAlreadyExists => '用户名已存在',
    AuthRepositoryErrorCode.emailAlreadyExists => '邮箱已存在',
    AuthRepositoryErrorCode.phoneAlreadyExists => '手机号已存在',
    AuthRepositoryErrorCode.invalidCredential => '邮箱或密码不正确',
    AuthRepositoryErrorCode.databaseWriteFailed => '写入数据库失败',
  };
}
