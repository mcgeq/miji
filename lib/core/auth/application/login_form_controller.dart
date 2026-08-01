import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:miji/core/auth/application/auth_session_controller.dart';
import 'package:miji/core/auth/application/forms/auth_form_inputs.dart';
import 'package:miji/core/auth/application/login_form_state.dart';
import 'package:miji/core/auth/domain/auth_repository.dart';
import 'package:miji/core/auth/providers/auth_providers.dart';

final localLoginFormControllerProvider =
    NotifierProvider<LoginFormController, LoginFormState>(
      LoginFormController.new,
    );

class LoginFormController extends Notifier<LoginFormState> {
  @override
  LoginFormState build() {
    return const LoginFormState();
  }

  void emailChanged(String value) {
    state = state.copyWith(
      email: EmailInput.dirty(value),
      clearSubmitError: true,
      clearLoggedInUserId: true,
    );
  }

  void passcodeChanged(String value) {
    state = state.copyWith(
      password: LoginPasswordInput.dirty(value),
      clearSubmitError: true,
      clearLoggedInUserId: true,
    );
  }

  void reset({String? email}) {
    state = email == null
        ? const LoginFormState()
        : LoginFormState(email: EmailInput.dirty(email));
  }

  void rememberEmailChanged(bool value) {
    state = state.copyWith(rememberEmail: value);
  }

  Future<LocalLoginResult?> submit() async {
    final dirtyState = state.copyWith(
      email: EmailInput.dirty(state.email.value),
      password: LoginPasswordInput.dirty(state.password.value),
      clearSubmitError: true,
      clearLoggedInUserId: true,
    );

    state = dirtyState;
    if (!dirtyState.isValid || dirtyState.isSubmitting) {
      return null;
    }

    state = state.copyWith(isSubmitting: true);

    try {
      final result = await ref
          .read(authRepositoryProvider)
          .loginLocalUser(
            LocalLoginRequest(
              email: dirtyState.email.value,
              passcode: dirtyState.password.value,
            ),
          );

      state = state.copyWith(
        isSubmitting: false,
        loggedInUserId: result.userId,
      );
      ref.read(authSessionControllerProvider.notifier).unlock(result.userId);
      return result;
    } on AuthRepositoryException catch (error) {
      state = state.copyWith(isSubmitting: false, submitError: error.code);
      return null;
    }
  }
}
