import 'package:formz/formz.dart';

import 'package:miji/core/auth/application/forms/auth_form_inputs.dart';
import 'package:miji/core/auth/domain/auth_repository.dart';

class LoginFormState {
  const LoginFormState({
    EmailInput? email,
    this.password = const LoginPasswordInput.pure(),
    this.isSubmitting = false,
    this.submitError,
    this.loggedInUserId,
    this.rememberEmail = false,
  }) : email = email ?? const EmailInput.pure();

  final EmailInput email;
  final LoginPasswordInput password;
  final bool isSubmitting;
  final AuthRepositoryErrorCode? submitError;
  final String? loggedInUserId;
  final bool rememberEmail;

  bool get isValid {
    return Formz.validate([email, password]);
  }

  bool get canSubmit {
    return isValid && !isSubmitting;
  }

  LoginFormState copyWith({
    EmailInput? email,
    LoginPasswordInput? password,
    bool? isSubmitting,
    AuthRepositoryErrorCode? submitError,
    bool clearSubmitError = false,
    String? loggedInUserId,
    bool clearLoggedInUserId = false,
    bool? rememberEmail,
  }) {
    return LoginFormState(
      email: email ?? this.email,
      password: password ?? this.password,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      submitError: clearSubmitError ? null : submitError ?? this.submitError,
      loggedInUserId: clearLoggedInUserId
          ? null
          : loggedInUserId ?? this.loggedInUserId,
      rememberEmail: rememberEmail ?? this.rememberEmail,
    );
  }
}
