import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:miji/core/auth/domain/auth_session.dart';
import 'package:miji/core/auth/domain/app_lock.dart';
import 'package:miji/core/auth/providers/auth_session_store_provider.dart';
import 'package:miji/core/auth/application/sensitive_access_controller.dart';
import 'package:miji/core/auth/providers/app_lock_providers.dart';

final authSessionControllerProvider =
    NotifierProvider<AuthSessionController, AuthSession>(
      AuthSessionController.new,
    );

class AuthSessionController extends Notifier<AuthSession> {
  @override
  AuthSession build() {
    unawaited(_restoreLastUser());
    return const AuthSession.restoring();
  }

  void unlock(String userId) {
    unawaited(_rememberUser(userId));
    state = AuthSession(
      userId: userId,
      isUnlocked: true,
      unlockedAt: DateTime.now().toUtc(),
    );
  }

  void lock() {
    unawaited(_lockIfEnabled());
  }

  Future<void> _lockIfEnabled() async {
    final userId = state.userId;
    if (userId == null || userId.isEmpty) {
      return;
    }
    final settings = await _readAppLockSettings(userId);
    if (!settings.canLock) {
      return;
    }

    state = state.copyWith(
      isUnlocked: false,
      isRestoring: false,
      clearUnlockedAt: true,
    );
  }

  void clear() {
    ref.read(sensitiveAccessControllerProvider.notifier).clear();
    unawaited(_forgetUser());
    state = const AuthSession.locked();
  }

  Future<void> _restoreLastUser() async {
    String? userId;
    try {
      userId = await ref.read(authSessionStoreProvider).readLastUserId();
    } catch (_) {
      userId = null;
    }

    if (!state.isRestoring) {
      return;
    }

    if (userId == null || userId.isEmpty) {
      state = const AuthSession.locked();
      return;
    }

    final settings = await _readAppLockSettings(userId);
    if (!state.isRestoring) {
      return;
    }
    state = AuthSession(userId: userId, isUnlocked: !settings.canLock);
  }

  Future<AppLockSettings> _readAppLockSettings(String userId) async {
    try {
      return await ref.read(appLockStoreProvider).readSettings(userId);
    } catch (_) {
      return const AppLockSettings.disabled();
    }
  }

  Future<void> _rememberUser(String userId) async {
    try {
      await ref.read(authSessionStoreProvider).writeLastUserId(userId);
    } catch (_) {
      // Session memory is best-effort; login should not fail if secure storage
      // is temporarily unavailable.
    }
  }

  Future<void> _forgetUser() async {
    try {
      await ref.read(authSessionStoreProvider).clearLastUserId();
    } catch (_) {
      // Explicit logout still clears in-memory state even if storage cleanup
      // fails; the next successful logout attempt can remove stale storage.
    }
  }
}
