import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:miji/core/auth/domain/sensitive_access_session.dart';
import 'package:miji/core/auth/domain/sensitive_access_ttl_option.dart';

final sensitiveAccessControllerProvider =
    NotifierProvider<SensitiveAccessController, SensitiveAccessSession>(
      SensitiveAccessController.new,
    );

class SensitiveAccessController extends Notifier<SensitiveAccessSession> {
  static const _verifiedAtKey = 'auth.sensitiveAccess.verifiedAt';

  @override
  SensitiveAccessSession build() {
    unawaited(_restoreVerifiedAt());
    return const SensitiveAccessSession.locked();
  }

  void verify() {
    final verifiedAt = DateTime.now().toUtc();
    unawaited(_writeVerifiedAt(verifiedAt));
    state = SensitiveAccessSession(
      ttlOption: state.ttlOption,
      verifiedAt: verifiedAt,
    );
  }

  void clear() {
    unawaited(_clearVerifiedAt());
    state = SensitiveAccessSession(ttlOption: state.ttlOption);
  }

  void setTtlOption(SensitiveAccessTtlOption ttlOption) {
    if (state.ttlOption == ttlOption) {
      return;
    }

    state = SensitiveAccessSession(
      ttlOption: ttlOption,
      verifiedAt: state.verifiedAt,
    );
  }

  Future<void> _restoreVerifiedAt() async {
    DateTime? verifiedAt;
    try {
      final preferences = await SharedPreferences.getInstance();
      final value = preferences.getString(_verifiedAtKey);
      if (value != null && value.isNotEmpty) {
        verifiedAt = DateTime.tryParse(value)?.toUtc();
      }
    } catch (_) {
      verifiedAt = null;
    }

    if (verifiedAt == null || state.verifiedAt != null) {
      return;
    }

    state = SensitiveAccessSession(
      ttlOption: state.ttlOption,
      verifiedAt: verifiedAt,
    );
  }

  Future<void> _writeVerifiedAt(DateTime verifiedAt) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(_verifiedAtKey, verifiedAt.toIso8601String());
    } catch (_) {
      // Persisting this timestamp is best-effort. In-memory verification still
      // works for the current process if preferences storage is unavailable.
    }
  }

  Future<void> _clearVerifiedAt() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.remove(_verifiedAtKey);
    } catch (_) {
      // Lock/logout should never fail because preference cleanup failed.
    }
  }
}
