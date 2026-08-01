import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:miji/core/auth/application/auth_session_controller.dart';
import 'package:miji/core/database/seed/seed_providers.dart';
import 'package:miji/core/preferences/domain/user_preferences_entity.dart';
import 'package:miji/core/preferences/providers/preferences_providers.dart';
import 'package:miji/core/router/app_router.dart';
import 'package:miji/core/sync/webdav/webdav_providers.dart';
import 'package:miji/core/theme/app_theme.dart';
import 'package:miji/features/bookkeeping/providers/bookkeeping_providers.dart';

void main() {
  runApp(const ProviderScope(child: MijiApp()));
}

class MijiApp extends ConsumerStatefulWidget {
  const MijiApp({super.key});

  @override
  ConsumerState<MijiApp> createState() => _MijiAppState();
}

class _MijiAppState extends ConsumerState<MijiApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      return;
    }

    Future<void>.microtask(() {
      if (!mounted) {
        return;
      }
      ref.read(webDavAutoSyncControllerProvider.notifier).refresh();
      unawaited(
        ref.read(currentUserBudgetAlertNotificationActionsProvider).scanNow(),
      );
      unawaited(
        ref.read(currentUserBillReminderNotificationActionsProvider).scanNow(),
      );
    });
  }

  void _seedCurrentUserAfterFirstFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(
        Future<void>.delayed(const Duration(milliseconds: 160), () async {
          if (!mounted) {
            return;
          }
          await ref.read(currentUserDatabaseSeedProvider.future);
        }),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(globalDatabaseSeedProvider);
    ref.watch(webDavAutoSyncControllerProvider);

    ref.listen(authSessionControllerProvider, (_, next) {
      if (next.isUnlocked && next.userId != null) {
        _seedCurrentUserAfterFirstFrame();
        unawaited(
          ref.read(currentUserBudgetAlertNotificationActionsProvider).scanNow(),
        );
        unawaited(
          ref
              .read(currentUserBillReminderNotificationActionsProvider)
              .scanNow(),
        );
      }
    });

    final themeMode = ref.watch(effectiveThemeModePreferenceProvider).themeMode;
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Miji',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      themeAnimationDuration: const Duration(milliseconds: 420),
      themeAnimationCurve: Curves.easeInOutCubic,
      builder: FToastBuilder(),
      routerConfig: router,
    );
  }
}
