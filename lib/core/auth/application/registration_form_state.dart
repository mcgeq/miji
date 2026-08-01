import 'package:formz/formz.dart';

import 'package:miji/core/auth/application/forms/auth_form_inputs.dart';
import 'package:miji/core/auth/domain/auth_repository.dart';

enum FieldAvailabilityStatus { unchecked, checking, available, unavailable }

class RegistrationFormState {
  const RegistrationFormState({
    this.username = const UsernameInput.pure(),
    EmailInput? email,
    this.passcode = const PasscodeInput.pure(),
    ConfirmPasswordInput? confirmPassword,
    this.usernameAvailability = FieldAvailabilityStatus.unchecked,
    this.emailAvailability = FieldAvailabilityStatus.unchecked,
    this.isSubmitting = false,
    this.submitError,
    this.registeredUserId,
  }) : email = email ?? const EmailInput.pure(),
       confirmPassword = confirmPassword ?? const ConfirmPasswordInput.pure();

  final UsernameInput username;
  final EmailInput email;
  final PasscodeInput passcode;
  final ConfirmPasswordInput confirmPassword;
  final FieldAvailabilityStatus usernameAvailability;
  final FieldAvailabilityStatus emailAvailability;
  final bool isSubmitting;
  final AuthRepositoryErrorCode? submitError;
  final String? registeredUserId;

  bool get isValid {
    return Formz.validate([username, email, passcode, confirmPassword]);
  }

  bool get isCheckingAvailability {
    return usernameAvailability == FieldAvailabilityStatus.checking ||
        emailAvailability == FieldAvailabilityStatus.checking;
  }

  bool get hasUnavailableCredential {
    return usernameAvailability == FieldAvailabilityStatus.unavailable ||
        emailAvailability == FieldAvailabilityStatus.unavailable;
  }

  bool get canSubmit {
    return isValid &&
        !isSubmitting &&
        !isCheckingAvailability &&
        !hasUnavailableCredential;
  }

  RegistrationFormState copyWith({
    UsernameInput? username,
    EmailInput? email,
    PasscodeInput? passcode,
    ConfirmPasswordInput? confirmPassword,
    FieldAvailabilityStatus? usernameAvailability,
    FieldAvailabilityStatus? emailAvailability,
    bool? isSubmitting,
    AuthRepositoryErrorCode? submitError,
    bool clearSubmitError = false,
    String? registeredUserId,
    bool clearRegisteredUserId = false,
  }) {
    return RegistrationFormState(
      username: username ?? this.username,
      email: email ?? this.email,
      passcode: passcode ?? this.passcode,
      confirmPassword: confirmPassword ?? this.confirmPassword,
      usernameAvailability: usernameAvailability ?? this.usernameAvailability,
      emailAvailability: emailAvailability ?? this.emailAvailability,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      submitError: clearSubmitError ? null : submitError ?? this.submitError,
      registeredUserId: clearRegisteredUserId
          ? null
          : registeredUserId ?? this.registeredUserId,
    );
  }
}
