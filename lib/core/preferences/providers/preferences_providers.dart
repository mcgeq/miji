import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:miji/core/auth/application/auth_session_controller.dart';
import 'package:miji/core/database/database_providers.dart';
import 'package:miji/core/preferences/data/drift_preferences_repository.dart';
import 'package:miji/core/preferences/domain/preferences_repository.dart';
import 'package:miji/core/preferences/domain/user_preferences_entity.dart';

final preferencesRepositoryProvider = Provider<PreferencesRepository>((ref) {
  return DriftPreferencesRepository(database: ref.watch(appDatabaseProvider));
});

final currentUserPreferencesProvider = FutureProvider<UserPreferencesEntity?>((
  ref,
) {
  final session = ref.watch(authSessionControllerProvider);
  if (!session.isUnlocked || session.userId == null) {
    return null;
  }

  return ref
      .watch(preferencesRepositoryProvider)
      .getPreferencesForUser(session.userId!);
});

final userThemeModePreferenceProvider =
    FutureProvider.family<AppThemeModePreference?, String>((ref, userId) async {
      final preferences = await ref
          .watch(preferencesRepositoryProvider)
          .getPreferencesForUser(userId);
      return preferences?.themeMode;
    });

final activeThemeModePreferenceProvider =
    NotifierProvider<
      ActiveThemeModePreferenceController,
      AppThemeModePreference?
    >(ActiveThemeModePreferenceController.new);

class ActiveThemeModePreferenceController
    extends Notifier<AppThemeModePreference?> {
  @override
  AppThemeModePreference? build() {
    ref.watch(
      authSessionControllerProvider.select((session) => session.userId),
    );
    return null;
  }

  void set(AppThemeModePreference themeMode) {
    state = themeMode;
  }

  void clear() {
    state = null;
  }
}

final effectiveThemeModePreferenceProvider = Provider<AppThemeModePreference>((
  ref,
) {
  final activeThemeMode = ref.watch(activeThemeModePreferenceProvider);
  if (activeThemeMode != null) {
    return activeThemeMode;
  }

  final session = ref.watch(authSessionControllerProvider);
  final userId = session.userId;
  if (userId == null) {
    return AppThemeModePreference.system;
  }

  return ref
          .watch(userThemeModePreferenceProvider(userId))
          .maybeWhen(data: (themeMode) => themeMode, orElse: () => null) ??
      AppThemeModePreference.system;
});
