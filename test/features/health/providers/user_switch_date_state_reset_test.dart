import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:miji/core/auth/application/auth_session_controller.dart';
import 'package:miji/core/auth/domain/auth_session.dart';
import 'package:miji/features/health/providers/health_providers.dart';

void main() {
  test('healthTodayDateProvider resets to today on user switch', () {
    final container = ProviderContainer(
      overrides: [
        authSessionControllerProvider.overrideWith(_SessionController.new),
      ],
    );
    addTearDown(container.dispose);

    container
        .read(healthTodayDateProvider.notifier)
        .set(DateTime.utc(2020, 5, 3));
    expect(container.read(healthTodayDateProvider), DateTime(2020, 5, 3));

    container.read(authSessionControllerProvider.notifier).unlock('user-2');

    expect(
      container.read(healthTodayDateProvider),
      DateUtils.dateOnly(DateTime.now().toUtc()),
    );
  });
}

class _SessionController extends AuthSessionController {
  @override
  AuthSession build() => const AuthSession(userId: 'user-1', isUnlocked: true);
}
