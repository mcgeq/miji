import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:miji/core/auth/application/auth_session_controller.dart';
import 'package:miji/core/auth/domain/auth_session.dart';
import 'package:miji/features/home/application/home_money_dashboard_providers.dart';

void main() {
  test('home month selection resets to current month on user switch', () {
    final container = ProviderContainer(
      overrides: [
        authSessionControllerProvider.overrideWith(_SessionController.new),
      ],
    );
    addTearDown(container.dispose);

    container
        .read(homeMoneySelectedMonthProvider.notifier)
        .set(DateTime(2020, 5));
    expect(container.read(homeMoneySelectedMonthProvider), DateTime(2020, 5));

    container.read(authSessionControllerProvider.notifier).unlock('user-2');

    final now = DateTime.now();
    expect(
      container.read(homeMoneySelectedMonthProvider),
      DateTime(now.year, now.month),
    );
  });
}

class _SessionController extends AuthSessionController {
  @override
  AuthSession build() => const AuthSession(userId: 'user-1', isUnlocked: true);
}
