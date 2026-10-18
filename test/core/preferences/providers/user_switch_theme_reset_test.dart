import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:miji/core/auth/application/auth_session_controller.dart';
import 'package:miji/core/auth/domain/auth_session.dart';
import 'package:miji/core/preferences/domain/user_preferences_entity.dart';
import 'package:miji/core/preferences/providers/preferences_providers.dart';

void main() {
  test('activeThemeModePreferenceProvider resets when user switches', () {
    final container = ProviderContainer(
      overrides: [
        authSessionControllerProvider.overrideWith(_SessionController.new),
      ],
    );
    addTearDown(container.dispose);

    container
        .read(activeThemeModePreferenceProvider.notifier)
        .set(AppThemeModePreference.dark);
    expect(
      container.read(activeThemeModePreferenceProvider),
      AppThemeModePreference.dark,
    );

    container.read(authSessionControllerProvider.notifier).unlock('user-2');

    expect(container.read(activeThemeModePreferenceProvider), isNull);
  });
}

class _SessionController extends AuthSessionController {
  @override
  AuthSession build() => const AuthSession(userId: 'user-1', isUnlocked: true);
}
