import 'package:email_validator/email_validator.dart';
import 'package:formz/formz.dart';

enum UsernameValidationError {
  empty,
  tooShort,
  tooLong,
  invalidStart,
  invalidCharacters,
}

class UsernameInput extends FormzInput<String, UsernameValidationError> {
  const UsernameInput.pure([super.value = '']) : super.pure();

  const UsernameInput.dirty([super.value = '']) : super.dirty();

  static final _allowedCharacters = RegExp(r'^[a-z][a-z0-9_]*$');

  @override
  UsernameValidationError? validator(String value) {
    final normalized = value.trim();

    if (normalized.isEmpty) {
      return UsernameValidationError.empty;
    }
    if (normalized.length < 3) {
      return UsernameValidationError.tooShort;
    }
    if (normalized.length > 20) {
      return UsernameValidationError.tooLong;
    }
    if (!RegExp(r'^[a-zA-Z]').hasMatch(normalized)) {
      return UsernameValidationError.invalidStart;
    }
    if (!_allowedCharacters.hasMatch(normalized)) {
      return UsernameValidationError.invalidCharacters;
    }

    return null;
  }
}

enum EmailValidationError { empty, tooLong, invalid }

class EmailInput extends FormzInput<String, EmailValidationError> {
  const EmailInput.pure([super.value = '']) : super.pure();

  EmailInput.dirty([String value = '']) : super.dirty(_normalize(value));

  static String _normalize(String value) => value.trim().toLowerCase();

  @override
  EmailValidationError? validator(String value) {
    if (value.isEmpty) {
      return EmailValidationError.empty;
    }
    if (value.length > 254) {
      return EmailValidationError.tooLong;
    }
    if (!EmailValidator.validate(value)) {
      return EmailValidationError.invalid;
    }

    return null;
  }
}

enum DisplayNameValidationError { empty, tooLong }

class DisplayNameInput extends FormzInput<String, DisplayNameValidationError> {
  const DisplayNameInput.pure([super.value = '']) : super.pure();

  const DisplayNameInput.dirty([super.value = '']) : super.dirty();

  @override
  DisplayNameValidationError? validator(String value) {
    final normalized = value.trim();

    if (normalized.isEmpty) {
      return DisplayNameValidationError.empty;
    }
    if (normalized.length > 40) {
      return DisplayNameValidationError.tooLong;
    }

    return null;
  }
}

enum PasscodeValidationError { empty, tooShort, tooLong }

class PasscodeInput extends FormzInput<String, PasscodeValidationError> {
  const PasscodeInput.pure([super.value = '']) : super.pure();

  const PasscodeInput.dirty([super.value = '']) : super.dirty();

  @override
  PasscodeValidationError? validator(String value) {
    if (value.trim().isEmpty) {
      return PasscodeValidationError.empty;
    }
    if (value.length < 6) {
      return PasscodeValidationError.tooShort;
    }
    if (value.length > 128) {
      return PasscodeValidationError.tooLong;
    }

    return null;
  }
}

enum LoginPasswordValidationError { empty }

class LoginPasswordInput
    extends FormzInput<String, LoginPasswordValidationError> {
  const LoginPasswordInput.pure([super.value = '']) : super.pure();

  const LoginPasswordInput.dirty([super.value = '']) : super.dirty();

  @override
  LoginPasswordValidationError? validator(String value) {
    if (value.trim().isEmpty) {
      return LoginPasswordValidationError.empty;
    }

    return null;
  }
}

enum ConfirmPasswordValidationError { empty, mismatch }

class ConfirmPasswordInput
    extends FormzInput<String, ConfirmPasswordValidationError> {
  const ConfirmPasswordInput.pure({this.password = '', String value = ''})
    : super.pure(value);

  const ConfirmPasswordInput.dirty({required this.password, String value = ''})
    : super.dirty(value);

  final String password;

  @override
  ConfirmPasswordValidationError? validator(String value) {
    if (value.trim().isEmpty) {
      return ConfirmPasswordValidationError.empty;
    }
    if (value != password) {
      return ConfirmPasswordValidationError.mismatch;
    }

    return null;
  }
}
