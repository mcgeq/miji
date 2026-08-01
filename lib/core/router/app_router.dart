import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:miji/core/auth/application/auth_session_controller.dart';
import 'package:miji/core/auth/application/sensitive_access_controller.dart';
import 'package:miji/core/auth/providers/auth_providers.dart';
import 'package:miji/core/preferences/providers/preferences_providers.dart';
import 'package:miji/features/auth/presentation/auth_entry_page.dart';
import 'package:miji/features/auth/presentation/locked_auth_page.dart';
import 'package:miji/features/auth/presentation/sensitive_unlock_page.dart';
import 'package:miji/features/bookkeeping/presentation/bookkeeping_page.dart';
import 'package:miji/features/gtd/presentation/gtd_page.dart';
import 'package:miji/features/health/presentation/health_page.dart';
import 'package:miji/features/home/presentation/home_page.dart';
import 'package:miji/features/settings/presentation/settings_page.dart';
import 'package:miji/features/shell/presentation/app_shell_page.dart';

import 'package:miji/core/router/app_routes.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = _RouterRefreshNotifier();

  ref.listen(authSessionControllerProvider, (_, _) {
    refreshNotifier.refresh();
  });
  ref.listen(sensitiveAccessControllerProvider, (_, _) {
    refreshNotifier.refresh();
  });
  ref.listen(currentUserPreferencesProvider, (_, next) {
    final ttlOption = next.maybeWhen(
      data: (preferences) => preferences?.sensitiveAccessTtl,
      orElse: () => null,
    );
    if (ttlOption != null) {
      ref
          .read(sensitiveAccessControllerProvider.notifier)
          .setTtlOption(ttlOption);
    }
    refreshNotifier.refresh();
  });

  final router = GoRouter(
    initialLocation: AppRoutes.home,
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final session = ref.read(authSessionControllerProvider);
      final sensitiveSession = ref.read(sensitiveAccessControllerProvider);
      final path = state.uri.path;
      final location = state.uri.toString();
      final isUnlocked = session.isUnlocked && session.userId != null;
      final isAuthRoute = path == AppRoutes.auth;
      final isAppRoute = path == AppRoutes.app || path.startsWith('/app/');
      final isUnlockRoute = path == AppRoutes.unlock;

      if (session.isRestoring) {
        return isAuthRoute ? null : AppRoutes.auth;
      }

      if (!isUnlocked) {
        return isAuthRoute ? null : AppRoutes.auth;
      }

      if (path == AppRoutes.root || isAuthRoute || path == AppRoutes.app) {
        return AppRoutes.home;
      }

      if (isAppRoute &&
          !isUnlockRoute &&
          AppRoutes.isSensitivePath(path) &&
          !sensitiveSession.isVerified) {
        return Uri(
          path: AppRoutes.unlock,
          queryParameters: {'from': location},
        ).toString();
      }

      if (isUnlockRoute && sensitiveSession.isVerified) {
        return state.uri.queryParameters['from'] ?? AppRoutes.home;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.root,
        builder: (context, state) => const SizedBox.shrink(),
      ),
      GoRoute(
        path: AppRoutes.auth,
        builder: (context, state) => const _AuthRoutePage(),
      ),
      ShellRoute(
        builder: (context, state, child) => AppShellPage(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.home,
            builder: (context, state) => const HomePage(),
          ),
          GoRoute(
            path: AppRoutes.gtd,
            builder: (context, state) => const GtdPage(),
          ),
          GoRoute(
            path: AppRoutes.bookkeeping,
            builder: (context, state) => BookkeepingPage(
              initialSection: state.uri.queryParameters['section'],
              initialAccountId: state.uri.queryParameters['accountId'],
            ),
          ),
          GoRoute(
            path: AppRoutes.health,
            builder: (context, state) => const HealthPage(),
          ),
          GoRoute(
            path: AppRoutes.settings,
            builder: (context, state) => const SettingsPage(),
          ),
          GoRoute(
            path: AppRoutes.settingsSecurity,
            builder: (context, state) => const AccountSecuritySettingsPage(),
          ),
          GoRoute(
            path: AppRoutes.settingsAppearance,
            builder: (context, state) => const AppearanceSettingsPage(),
          ),
          GoRoute(
            path: AppRoutes.settingsBookkeeping,
            builder: (context, state) =>
                const BookkeepingPreferenceSettingsPage(),
          ),
          GoRoute(
            path: AppRoutes.settingsSync,
            builder: (context, state) => const DataSyncSettingsPage(),
          ),
          GoRoute(
            path: AppRoutes.settingsAbout,
            builder: (context, state) => const AboutSettingsPage(),
          ),
          GoRoute(
            path: AppRoutes.unlock,
            builder: (context, state) => SensitiveUnlockPage(
              from: state.uri.queryParameters['from'] ?? AppRoutes.home,
            ),
          ),
        ],
      ),
    ],
  );

  ref.onDispose(() {
    router.dispose();
    refreshNotifier.dispose();
  });
  return router;
});

class _RouterRefreshNotifier extends ChangeNotifier {
  void refresh() {
    notifyListeners();
  }
}

class _AuthRoutePage extends ConsumerStatefulWidget {
  const _AuthRoutePage();

  @override
  ConsumerState<_AuthRoutePage> createState() => _AuthRoutePageState();
}

class _AuthRoutePageState extends ConsumerState<_AuthRoutePage> {
  late Future<bool> _onboardingRequiredFuture;

  @override
  void initState() {
    super.initState();
    _onboardingRequiredFuture = _readOnboardingRequired();
  }

  Future<bool> _readOnboardingRequired() {
    return ref.read(authOnboardingRequiredProvider.future);
  }

  void _retryOnboardingRequired() {
    ref.invalidate(authOnboardingRequiredProvider);
    setState(() {
      _onboardingRequiredFuture = _readOnboardingRequired();
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authSessionControllerProvider);
    if (session.isRestoring) {
      return const Scaffold(
        body: SafeArea(child: Center(child: CircularProgressIndicator())),
      );
    }

    if (!session.isUnlocked && session.userId != null) {
      return LockedAuthPage(userId: session.userId!);
    }

    return FutureBuilder<bool>(
      future: _onboardingRequiredFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: SafeArea(child: Center(child: CircularProgressIndicator())),
          );
        }
        if (snapshot.hasError) {
          return _AuthRouteErrorPage(onRetry: _retryOnboardingRequired);
        }
        final isRequired = snapshot.data ?? true;
        return AuthEntryPage(
          initialMode: isRequired
              ? AuthEntryMode.register
              : AuthEntryMode.login,
        );
      },
    );
  }
}

class _AuthRouteErrorPage extends StatelessWidget {
  const _AuthRouteErrorPage({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  color: colorScheme.error,
                  size: 36,
                ),
                const SizedBox(height: 14),
                Text(
                  '启动认证状态失败',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('重试'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
