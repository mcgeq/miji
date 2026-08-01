import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:miji/core/auth/application/forms/auth_form_inputs.dart';
import 'package:miji/core/auth/application/registration_form_state.dart';
import 'package:miji/core/auth/domain/auth_repository.dart';
import 'package:miji/core/auth/providers/auth_providers.dart';

final registrationFormControllerProvider =
    NotifierProvider<RegistrationFormController, RegistrationFormState>(
      RegistrationFormController.new,
    );

class RegistrationFormController extends Notifier<RegistrationFormState> {
  Timer? _usernameAvailabilityTimer;
  Timer? _emailAvailabilityTimer;

  @override
  RegistrationFormState build() {
    ref.onDispose(() {
      _usernameAvailabilityTimer?.cancel();
      _emailAvailabilityTimer?.cancel();
    });

    return const RegistrationFormState();
  }

  void usernameChanged(String value) {
    state = state.copyWith(
      username: UsernameInput.dirty(value),
      usernameAvailability: FieldAvailabilityStatus.unchecked,
      clearSubmitError: true,
      clearRegisteredUserId: true,
    );
  }

  void emailChanged(String value) {
    state = state.copyWith(
      email: EmailInput.dirty(value),
      emailAvailability: FieldAvailabilityStatus.unchecked,
      clearSubmitError: true,
      clearRegisteredUserId: true,
    );
  }

  void passcodeChanged(String value) {
    state = state.copyWith(
      passcode: PasscodeInput.dirty(value),
      confirmPassword: ConfirmPasswordInput.dirty(
        password: value,
        value: state.confirmPassword.value,
      ),
      clearSubmitError: true,
      clearRegisteredUserId: true,
    );
  }

  void confirmPasswordChanged(String value) {
    state = state.copyWith(
      confirmPassword: ConfirmPasswordInput.dirty(
        password: state.passcode.value,
        value: value,
      ),
      clearSubmitError: true,
      clearRegisteredUserId: true,
    );
  }

  void reset() {
    _usernameAvailabilityTimer?.cancel();
    _emailAvailabilityTimer?.cancel();
    state = const RegistrationFormState();
  }

  Future<void> usernameFocusLost() async {
    final username = UsernameInput.dirty(state.username.value);

    state = state.copyWith(username: username);
    if (!username.isValid) {
      _usernameAvailabilityTimer?.cancel();
      state = state.copyWith(
        usernameAvailability: FieldAvailabilityStatus.unchecked,
      );
      return;
    }

    await _checkUsernameAvailability(username.value);
  }

  Future<void> emailFocusLost() async {
    final email = EmailInput.dirty(state.email.value);

    state = state.copyWith(email: email);
    if (!email.isValid) {
      _emailAvailabilityTimer?.cancel();
      state = state.copyWith(
        emailAvailability: FieldAvailabilityStatus.unchecked,
      );
      return;
    }

    await _checkEmailAvailability(email.value);
  }

  Future<LocalRegistrationResult?> submit() async {
    final dirtyState = state.copyWith(
      username: UsernameInput.dirty(state.username.value),
      email: EmailInput.dirty(state.email.value),
      passcode: PasscodeInput.dirty(state.passcode.value),
      confirmPassword: ConfirmPasswordInput.dirty(
        password: state.passcode.value,
        value: state.confirmPassword.value,
      ),
      clearSubmitError: true,
      clearRegisteredUserId: true,
    );

    state = dirtyState;
    if (!dirtyState.isValid || dirtyState.isSubmitting) {
      return null;
    }

    final isAvailable = await _ensureCredentialsAvailable(dirtyState);
    if (!isAvailable || state.isSubmitting || !_isCurrentForm(dirtyState)) {
      return null;
    }

    state = state.copyWith(isSubmitting: true);

    try {
      final result = await ref
          .read(authRepositoryProvider)
          .registerLocalUser(
            LocalRegistrationRequest(
              username: dirtyState.username.value,
              email: dirtyState.email.value,
              displayName: dirtyState.username.value,
              passcode: dirtyState.passcode.value,
            ),
          );

      state = state.copyWith(
        isSubmitting: false,
        registeredUserId: result.userId,
      );
      return result;
    } on AuthRepositoryException catch (error) {
      state = state.copyWith(isSubmitting: false, submitError: error.code);
      return null;
    }
  }

  Future<bool> _ensureCredentialsAvailable(
    RegistrationFormState currentState,
  ) async {
    final usernameAvailable = await _checkUsernameAvailability(
      currentState.username.value,
    );
    if (!usernameAvailable) {
      return false;
    }

    return _checkEmailAvailability(currentState.email.value);
  }

  bool _isCurrentForm(RegistrationFormState snapshot) {
    return state.username.value == snapshot.username.value &&
        state.email.value == snapshot.email.value &&
        state.passcode.value == snapshot.passcode.value &&
        state.confirmPassword.value == snapshot.confirmPassword.value;
  }

  Future<bool> _checkUsernameAvailability(String username) async {
    _usernameAvailabilityTimer?.cancel();
    state = state.copyWith(
      usernameAvailability: FieldAvailabilityStatus.checking,
      clearSubmitError: true,
    );

    final isAvailable = await ref
        .read(authRepositoryProvider)
        .isUsernameAvailable(username);

    if (state.username.value != username) {
      return false;
    }

    state = state.copyWith(
      usernameAvailability: isAvailable
          ? FieldAvailabilityStatus.available
          : FieldAvailabilityStatus.unavailable,
    );

    if (isAvailable) {
      _usernameAvailabilityTimer = Timer(const Duration(seconds: 2), () {
        if (state.username.value == username &&
            state.usernameAvailability == FieldAvailabilityStatus.available) {
          state = state.copyWith(
            usernameAvailability: FieldAvailabilityStatus.unchecked,
          );
        }
      });
    }

    return isAvailable;
  }

  Future<bool> _checkEmailAvailability(String email) async {
    _emailAvailabilityTimer?.cancel();
    state = state.copyWith(
      emailAvailability: FieldAvailabilityStatus.checking,
      clearSubmitError: true,
    );

    final isAvailable = await ref
        .read(authRepositoryProvider)
        .isEmailAvailable(email);

    if (state.email.value != email) {
      return false;
    }

    state = state.copyWith(
      emailAvailability: isAvailable
          ? FieldAvailabilityStatus.available
          : FieldAvailabilityStatus.unavailable,
    );

    if (isAvailable) {
      _emailAvailabilityTimer = Timer(const Duration(seconds: 2), () {
        if (state.email.value == email &&
            state.emailAvailability == FieldAvailabilityStatus.available) {
          state = state.copyWith(
            emailAvailability: FieldAvailabilityStatus.unchecked,
          );
        }
      });
    }

    return isAvailable;
  }
}
