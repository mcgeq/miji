import 'package:flutter_test/flutter_test.dart';
import 'package:miji/core/auth/domain/app_lock.dart';

void main() {
  test('accepts exactly six digit pin', () {
    expect(validateAppLockSecret(AppLockMethod.pin, '123456'), isNull);
    expect(
      validateAppLockSecret(AppLockMethod.pin, '12345'),
      AppLockValidationError.pinMustBeSixDigits,
    );
    expect(
      validateAppLockSecret(AppLockMethod.pin, '12345a'),
      AppLockValidationError.pinMustBeSixDigits,
    );
  });

  test('requires pattern to connect at least four unique nodes', () {
    expect(validateAppLockSecret(AppLockMethod.pattern, '0-1-2-3'), isNull);
    expect(
      validateAppLockSecret(AppLockMethod.pattern, '0-1-2'),
      AppLockValidationError.patternTooShort,
    );
    expect(
      validateAppLockSecret(AppLockMethod.pattern, '0-1-2-1'),
      AppLockValidationError.patternHasDuplicateNodes,
    );
    expect(
      validateAppLockSecret(AppLockMethod.pattern, '0-1-2-9'),
      AppLockValidationError.patternHasInvalidNode,
    );
  });
}
