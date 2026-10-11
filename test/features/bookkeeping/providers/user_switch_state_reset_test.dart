import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:miji/core/auth/application/auth_session_controller.dart';
import 'package:miji/core/auth/domain/auth_session.dart';
import 'package:miji/features/bookkeeping/providers/bookkeeping_providers.dart';

void main() {
  test('currentMoneyLedgerIdProvider resets when user switches', () {
    final container = ProviderContainer(
      overrides: [
        authSessionControllerProvider.overrideWith(_SessionController.new),
      ],
    );
    addTearDown(container.dispose);

    container.read(currentMoneyLedgerIdProvider.notifier).set('ledger-a');
    expect(container.read(currentMoneyLedgerIdProvider), 'ledger-a');

    container.read(authSessionControllerProvider.notifier).unlock('user-2');

    expect(container.read(currentMoneyLedgerIdProvider), isNull);
  });
}

class _SessionController extends AuthSessionController {
  @override
  AuthSession build() => const AuthSession(userId: 'user-1', isUnlocked: true);
}
