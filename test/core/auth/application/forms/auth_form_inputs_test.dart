import 'package:flutter_test/flutter_test.dart';
import 'package:miji/core/auth/application/forms/auth_form_inputs.dart';

void main() {
  group('UsernameInput', () {
    test('pure input hides validation error until dirty', () {
      const input = UsernameInput.pure();

      expect(input.error, UsernameValidationError.empty);
      expect(input.displayError, isNull);
    });

    test('rejects empty username', () {
      const input = UsernameInput.dirty('');

      expect(input.error, UsernameValidationError.empty);
      expect(input.displayError, UsernameValidationError.empty);
      expect(input.isValid, isFalse);
    });

    test('rejects username shorter than 3 characters', () {
      const input = UsernameInput.dirty('ab');

      expect(input.error, UsernameValidationError.tooShort);
      expect(input.isValid, isFalse);
    });

    test('rejects username longer than 20 characters', () {
      const input = UsernameInput.dirty('abcdefghijklmnopqrstu');

      expect(input.error, UsernameValidationError.tooLong);
      expect(input.isValid, isFalse);
    });

    test('rejects username that does not start with a lowercase letter', () {
      const input = UsernameInput.dirty('1abc');

      expect(input.error, UsernameValidationError.invalidStart);
      expect(input.isValid, isFalse);
    });

    test('rejects uppercase and unsupported characters', () {
      const uppercase = UsernameInput.dirty('Abc');
      const hyphenated = UsernameInput.dirty('abc-def');

      expect(uppercase.error, UsernameValidationError.invalidCharacters);
      expect(hyphenated.error, UsernameValidationError.invalidCharacters);
      expect(uppercase.isValid, isFalse);
      expect(hyphenated.isValid, isFalse);
    });

    test('accepts lowercase letters numbers and underscore', () {
      const input = UsernameInput.dirty('miji_user1');

      expect(input.error, isNull);
      expect(input.displayError, isNull);
      expect(input.isValid, isTrue);
    });
  });

  group('EmailInput', () {
    test('rejects blank email because email is used for login', () {
      final input = EmailInput.dirty('');

      expect(input.error, EmailValidationError.empty);
      expect(input.isValid, isFalse);
    });

    test('normalizes email by trimming and lowercasing', () {
      final input = EmailInput.dirty('  LINDA@EXAMPLE.COM  ');

      expect(input.value, 'linda@example.com');
      expect(input.error, isNull);
      expect(input.isValid, isTrue);
    });

    test('rejects email longer than 254 characters', () {
      final input = EmailInput.dirty('${'a' * 245}@example.com');

      expect(input.error, EmailValidationError.tooLong);
      expect(input.isValid, isFalse);
    });

    test('rejects invalid email syntax', () {
      final input = EmailInput.dirty('wrong-mail');

      expect(input.error, EmailValidationError.invalid);
      expect(input.isValid, isFalse);
    });

    test('accepts valid email syntax', () {
      final input = EmailInput.dirty('linda@example.com');

      expect(input.error, isNull);
      expect(input.isValid, isTrue);
    });
  });

  group('DisplayNameInput', () {
    test('pure input hides validation error until dirty', () {
      const input = DisplayNameInput.pure();

      expect(input.error, DisplayNameValidationError.empty);
      expect(input.displayError, isNull);
    });

    test('rejects empty display name', () {
      const input = DisplayNameInput.dirty('   ');

      expect(input.error, DisplayNameValidationError.empty);
      expect(input.isValid, isFalse);
    });

    test('rejects display name longer than 40 characters', () {
      const input = DisplayNameInput.dirty(
        'abcdefghijklmnopqrstuvwxyzabcdefghijklmno',
      );

      expect(input.error, DisplayNameValidationError.tooLong);
      expect(input.isValid, isFalse);
    });

    test('accepts valid display name', () {
      const input = DisplayNameInput.dirty('Linda');

      expect(input.error, isNull);
      expect(input.isValid, isTrue);
    });
  });

  group('PasscodeInput', () {
    test('pure input hides validation error until dirty', () {
      const input = PasscodeInput.pure();

      expect(input.error, PasscodeValidationError.empty);
      expect(input.displayError, isNull);
    });

    test('rejects empty passcode', () {
      const input = PasscodeInput.dirty('');

      expect(input.error, PasscodeValidationError.empty);
      expect(input.isValid, isFalse);
    });

    test('rejects all whitespace passcode', () {
      const input = PasscodeInput.dirty('      ');

      expect(input.error, PasscodeValidationError.empty);
      expect(input.isValid, isFalse);
    });

    test('rejects passcode shorter than 6 characters', () {
      const input = PasscodeInput.dirty('12345');

      expect(input.error, PasscodeValidationError.tooShort);
      expect(input.isValid, isFalse);
    });

    test('rejects passcode longer than 128 characters', () {
      final input = PasscodeInput.dirty('a' * 129);

      expect(input.error, PasscodeValidationError.tooLong);
      expect(input.isValid, isFalse);
    });

    test('accepts valid passcode', () {
      const input = PasscodeInput.dirty('123456');

      expect(input.error, isNull);
      expect(input.isValid, isTrue);
    });
  });
}
