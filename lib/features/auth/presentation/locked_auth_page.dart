import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:miji/core/auth/application/auth_session_controller.dart';
import 'package:miji/core/auth/domain/app_lock.dart';
import 'package:miji/core/auth/presentation/app_pattern_lock_input.dart';
import 'package:miji/core/auth/providers/app_lock_providers.dart';
import 'package:miji/core/presentation/app_page_layout.dart';
import 'package:miji/core/presentation/app_responsive.dart';
import 'package:miji/core/presentation/app_toast.dart';

class LockedAuthPage extends ConsumerStatefulWidget {
  const LockedAuthPage({required this.userId, super.key});

  final String userId;

  @override
  ConsumerState<LockedAuthPage> createState() => _LockedAuthPageState();
}

class _LockedAuthPageState extends ConsumerState<LockedAuthPage> {
  FToast? _toast;
  bool _isSubmitting = false;
  String _pinInput = '';
  int _pinErrorVersion = 0;
  List<int> _pattern = const <int>[];
  int _patternInputVersion = 0;

  @override
  Widget build(BuildContext context) {
    final lockSettings = ref.watch(appLockSettingsProvider(widget.userId));
    final allowHardwarePinKeyboard = AppResponsive.of(
      context,
    ).isDesktopPlatform;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: AppPlainPanel(
                child: lockSettings.when(
                  data: (settings) => _LockedUserForm(
                    settings: settings,
                    pinInput: _pinInput,
                    pinErrorVersion: _pinErrorVersion,
                    patternInputVersion: _patternInputVersion,
                    isSubmitting: _isSubmitting,
                    allowHardwarePinKeyboard: allowHardwarePinKeyboard,
                    onPinDigit: _appendPinDigit,
                    onPinBackspace: _removePinDigit,
                    onPatternChanged: (value) => _pattern = value,
                    onSubmit: _submit,
                    onExit: () => ref
                        .read(authSessionControllerProvider.notifier)
                        .clear(),
                  ),
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, stackTrace) => _LockedUserMissing(
                    onExit: () => ref
                        .read(authSessionControllerProvider.notifier)
                        .clear(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_isSubmitting) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    AppLockMethod? submittingMethod;
    try {
      final settings = await ref.read(
        appLockSettingsProvider(widget.userId).future,
      );
      submittingMethod = settings.method;
      if (!mounted) {
        return;
      }
      if (!settings.canLock) {
        ref.read(authSessionControllerProvider.notifier).unlock(widget.userId);
        return;
      }

      final secret = settings.method == AppLockMethod.pin
          ? _pinInput
          : _pattern.join('-');
      final validationError = validateAppLockSecret(settings.method, secret);
      if (validationError != null) {
        AppToast.error(
          _ensureToast(),
          context,
          appLockValidationErrorText(validationError),
        );
        _resetCredentialInput(settings.method);
        return;
      }

      final verified = await ref
          .read(appLockStoreProvider)
          .verify(userId: widget.userId, secret: secret);
      if (!mounted) {
        return;
      }
      if (!verified) {
        AppToast.error(_ensureToast(), context, '解锁方式不正确');
        _playErrorFeedback(settings.method);
        _resetCredentialInput(settings.method);
        return;
      }

      ref.read(authSessionControllerProvider.notifier).unlock(widget.userId);

      if (!mounted) {
        return;
      }

      AppToast.success(_ensureToast(), context, '已解锁');
    } catch (_) {
      if (!mounted) {
        return;
      }

      AppToast.error(_ensureToast(), context, '解锁失败，请重试');
      final method = submittingMethod;
      if (method != null) {
        _playErrorFeedback(method);
        _resetCredentialInput(method);
      }
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

  void _resetCredentialInput(AppLockMethod method) {
    if (!mounted) {
      return;
    }
    if (method == AppLockMethod.pin) {
      setState(() {
        _pinInput = '';
        _pinErrorVersion += 1;
      });
      return;
    }
    setState(() {
      _pattern = const <int>[];
      _patternInputVersion += 1;
    });
  }

  void _appendPinDigit(String digit) {
    if (_isSubmitting || _pinInput.length >= 6) {
      return;
    }
    setState(() => _pinInput += digit);
    if (_pinInput.length == 6) {
      unawaited(_submit());
    }
  }

  void _removePinDigit() {
    if (_isSubmitting || _pinInput.isEmpty) {
      return;
    }
    setState(() => _pinInput = _pinInput.substring(0, _pinInput.length - 1));
  }

  void _playErrorFeedback(AppLockMethod method) {
    if (method != AppLockMethod.pin ||
        AppResponsive.of(context).isDesktopPlatform) {
      return;
    }
    HapticFeedback.lightImpact();
  }
}

class _LockedUserForm extends StatelessWidget {
  const _LockedUserForm({
    required this.settings,
    required this.pinInput,
    required this.pinErrorVersion,
    required this.patternInputVersion,
    required this.isSubmitting,
    required this.allowHardwarePinKeyboard,
    required this.onPinDigit,
    required this.onPinBackspace,
    required this.onPatternChanged,
    required this.onSubmit,
    required this.onExit,
  });
  final AppLockSettings settings;
  final String pinInput;
  final int pinErrorVersion;
  final int patternInputVersion;
  final bool isSubmitting;
  final bool allowHardwarePinKeyboard;
  final ValueChanged<String> onPinDigit;
  final VoidCallback onPinBackspace;
  final ValueChanged<List<int>> onPatternChanged;
  final VoidCallback onSubmit;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return AutofillGroup(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!settings.canLock)
            const _LockUnavailablePanel()
          else if (settings.method == AppLockMethod.pin)
            _PinLockInput(
              pin: pinInput,
              errorVersion: pinErrorVersion,
              enabled: !isSubmitting,
              enableHardwareKeyboard: allowHardwarePinKeyboard,
              onDigit: onPinDigit,
              onBackspace: onPinBackspace,
            )
          else ...[
            Text(
              '绘制手势解锁',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 10),
            AppPatternLockInput(
              key: ValueKey(patternInputVersion),
              enabled: !isSubmitting,
              onChanged: onPatternChanged,
              onCompleted: (value) {
                onPatternChanged(value);
                if (!isSubmitting) {
                  onSubmit();
                }
              },
            ),
          ],
          const SizedBox(height: 18),
          TextButton.icon(
            onPressed: isSubmitting ? null : onExit,
            icon: const Icon(Icons.logout_rounded, size: 18),
            label: const Text('退出账号'),
          ),
        ],
      ),
    );
  }
}

class _PinLockInput extends StatefulWidget {
  const _PinLockInput({
    required this.pin,
    required this.errorVersion,
    required this.enabled,
    required this.enableHardwareKeyboard,
    required this.onDigit,
    required this.onBackspace,
  });

  final String pin;
  final int errorVersion;
  final bool enabled;
  final bool enableHardwareKeyboard;
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;

  @override
  State<_PinLockInput> createState() => _PinLockInputState();
}

class _PinLockInputState extends State<_PinLockInput> {
  final FocusNode _focusNode = FocusNode(debugLabel: 'AppLockPinInput');

  @override
  void initState() {
    super.initState();
    if (widget.enableHardwareKeyboard) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _focusNode.requestFocus();
        }
      });
    }
  }

  @override
  void didUpdateWidget(covariant _PinLockInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.enableHardwareKeyboard && widget.enableHardwareKeyboard) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _focusNode.requestFocus();
        }
      });
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '输入 6 位 PIN',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 18),
        _PinDots(
          pinLength: widget.pin.length,
          errorVersion: widget.errorVersion,
        ),
        const SizedBox(height: 24),
        _PinNumberPad(
          enabled: widget.enabled,
          onDigit: widget.onDigit,
          onBackspace: widget.onBackspace,
        ),
      ],
    );

    if (!widget.enableHardwareKeyboard) {
      return content;
    }

    return KeyboardListener(
      autofocus: true,
      focusNode: _focusNode,
      onKeyEvent: _handleKeyEvent,
      child: content,
    );
  }

  void _handleKeyEvent(KeyEvent event) {
    if (!widget.enabled || event is! KeyDownEvent) {
      return;
    }
    final digit = _digitForKey(event.logicalKey);
    if (digit != null) {
      widget.onDigit(digit);
      return;
    }
    if (event.logicalKey == LogicalKeyboardKey.backspace ||
        event.logicalKey == LogicalKeyboardKey.delete) {
      widget.onBackspace();
    }
  }

  String? _digitForKey(LogicalKeyboardKey key) {
    return switch (key) {
      LogicalKeyboardKey.digit0 || LogicalKeyboardKey.numpad0 => '0',
      LogicalKeyboardKey.digit1 || LogicalKeyboardKey.numpad1 => '1',
      LogicalKeyboardKey.digit2 || LogicalKeyboardKey.numpad2 => '2',
      LogicalKeyboardKey.digit3 || LogicalKeyboardKey.numpad3 => '3',
      LogicalKeyboardKey.digit4 || LogicalKeyboardKey.numpad4 => '4',
      LogicalKeyboardKey.digit5 || LogicalKeyboardKey.numpad5 => '5',
      LogicalKeyboardKey.digit6 || LogicalKeyboardKey.numpad6 => '6',
      LogicalKeyboardKey.digit7 || LogicalKeyboardKey.numpad7 => '7',
      LogicalKeyboardKey.digit8 || LogicalKeyboardKey.numpad8 => '8',
      LogicalKeyboardKey.digit9 || LogicalKeyboardKey.numpad9 => '9',
      _ => null,
    };
  }
}

class _PinDots extends StatelessWidget {
  const _PinDots({required this.pinLength, required this.errorVersion});

  final int pinLength;
  final int errorVersion;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return TweenAnimationBuilder<double>(
      key: ValueKey(errorVersion),
      tween: Tween<double>(begin: errorVersion == 0 ? 0 : 1, end: 0),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        final offset = value == 0 ? 0.0 : (value * 12) * (value > 0.5 ? -1 : 1);
        return Transform.translate(offset: Offset(offset, 0), child: child);
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var index = 0; index < 6; index++) ...[
            AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              curve: Curves.easeOut,
              width: 13,
              height: 13,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: index < pinLength
                    ? colorScheme.primary
                    : colorScheme.outlineVariant,
              ),
            ),
            if (index != 5) const SizedBox(width: 14),
          ],
        ],
      ),
    );
  }
}

class _PinNumberPad extends StatelessWidget {
  const _PinNumberPad({
    required this.enabled,
    required this.onDigit,
    required this.onBackspace,
  });

  final bool enabled;
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;

  static const _rows = [
    ['1', '2', '3'],
    ['4', '5', '6'],
    ['7', '8', '9'],
    ['', '0', 'backspace'],
  ];

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 270),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final row in _rows) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (final value in row)
                    _PinPadKey(
                      value: value,
                      enabled: enabled,
                      onDigit: onDigit,
                      onBackspace: onBackspace,
                    ),
                ],
              ),
              if (row != _rows.last) const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

class _PinPadKey extends StatelessWidget {
  const _PinPadKey({
    required this.value,
    required this.enabled,
    required this.onDigit,
    required this.onBackspace,
  });

  final String value;
  final bool enabled;
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;

  @override
  Widget build(BuildContext context) {
    if (value.isEmpty) {
      return const SizedBox(width: 70, height: 58);
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isBackspace = value == 'backspace';

    return Semantics(
      button: true,
      label: isBackspace ? '删除' : value,
      child: Material(
        color: isBackspace
            ? Colors.transparent
            : colorScheme.surfaceContainerHighest.withValues(alpha: 0.78),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: !enabled
              ? null
              : isBackspace
              ? onBackspace
              : () => onDigit(value),
          child: SizedBox(
            width: 70,
            height: 58,
            child: Center(
              child: isBackspace
                  ? Icon(
                      Icons.backspace_outlined,
                      color: colorScheme.onSurfaceVariant,
                      size: 24,
                    )
                  : Text(
                      value,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LockUnavailablePanel extends StatelessWidget {
  const _LockUnavailablePanel();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Column(
      children: [
        Icon(
          Icons.lock_open_rounded,
          size: 34,
          color: colorScheme.onSurfaceVariant,
        ),
        const SizedBox(height: 10),
        Text(
          '当前未启用锁屏',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

class _LockedUserMissing extends StatelessWidget {
  const _LockedUserMissing({required this.onExit});

  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(Icons.error_outline_rounded, color: colorScheme.error, size: 36),
        const SizedBox(height: 12),
        Text(
          '当前用户不可用',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium?.copyWith(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: onExit,
          icon: const Icon(Icons.logout_rounded),
          label: const Text('退出账号'),
        ),
      ],
    );
  }
}
