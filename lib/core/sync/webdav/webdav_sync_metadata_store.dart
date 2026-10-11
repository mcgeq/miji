import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class WebDavSyncActivityEntry {
  const WebDavSyncActivityEntry({
    required this.finishedAt,
    required this.outcome,
    this.reason = 'manual',
    this.errorMessage,
    this.uploadedChanges = 0,
    this.uploadedPackages = 0,
    this.downloadedPackages = 0,
    this.appliedRemoteChanges = 0,
    this.remoteConflicts = 0,
  });

  final DateTime finishedAt;
  final String outcome;
  final String reason;
  final String? errorMessage;
  final int uploadedChanges;
  final int uploadedPackages;
  final int downloadedPackages;
  final int appliedRemoteChanges;
  final int remoteConflicts;

  Map<String, Object?> toJson() {
    return {
      'finishedAt': finishedAt.toUtc().toIso8601String(),
      'outcome': outcome,
      'reason': reason,
      'uploadedChanges': uploadedChanges,
      'uploadedPackages': uploadedPackages,
      'downloadedPackages': downloadedPackages,
      'appliedRemoteChanges': appliedRemoteChanges,
      'remoteConflicts': remoteConflicts,
      if (errorMessage != null && errorMessage!.trim().isNotEmpty)
        'errorMessage': errorMessage,
    };
  }

  static WebDavSyncActivityEntry? fromJson(Object? value) {
    if (value is! Map<String, Object?>) {
      return null;
    }
    final finishedAt = DateTime.tryParse(value['finishedAt'] as String? ?? '');
    final outcome = (value['outcome'] as String?)?.trim();
    if (finishedAt == null || outcome == null || outcome.isEmpty) {
      return null;
    }
    final errorMessage = (value['errorMessage'] as String?)?.trim();
    return WebDavSyncActivityEntry(
      finishedAt: finishedAt.toUtc(),
      outcome: outcome,
      reason: (value['reason'] as String?)?.trim().isNotEmpty == true
          ? (value['reason'] as String).trim()
          : 'manual',
      errorMessage: errorMessage == null || errorMessage.isEmpty
          ? null
          : errorMessage,
      uploadedChanges: _readInt(value['uploadedChanges']),
      uploadedPackages: _readInt(value['uploadedPackages']),
      downloadedPackages: _readInt(value['downloadedPackages']),
      appliedRemoteChanges: _readInt(value['appliedRemoteChanges']),
      remoteConflicts: _readInt(value['remoteConflicts']),
    );
  }

  static int _readInt(Object? value) {
    if (value is int) {
      return value;
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class WebDavSyncMetadata {
  const WebDavSyncMetadata({
    required this.lastUploadedAt,
    required this.lastRestoredAt,
    required this.lastDeletedAt,
    required this.lastAutoSyncStartedAt,
    required this.lastAutoSyncSucceededAt,
    required this.lastAutoSyncFailedAt,
    required this.lastAutoSyncError,
    this.recentSyncActivities = const [],
  });

  final DateTime? lastUploadedAt;
  final DateTime? lastRestoredAt;
  final DateTime? lastDeletedAt;
  final DateTime? lastAutoSyncStartedAt;
  final DateTime? lastAutoSyncSucceededAt;
  final DateTime? lastAutoSyncFailedAt;
  final String? lastAutoSyncError;
  final List<WebDavSyncActivityEntry> recentSyncActivities;

  static const empty = WebDavSyncMetadata(
    lastUploadedAt: null,
    lastRestoredAt: null,
    lastDeletedAt: null,
    lastAutoSyncStartedAt: null,
    lastAutoSyncSucceededAt: null,
    lastAutoSyncFailedAt: null,
    lastAutoSyncError: null,
    recentSyncActivities: [],
  );
}

abstract class WebDavSyncMetadataStore {
  Future<WebDavSyncMetadata> readMetadata();

  Future<void> markUploaded(DateTime value);

  Future<void> markRestored(DateTime value);

  Future<void> markDeleted(DateTime value);

  Future<void> markAutoSyncStarted(DateTime value);

  Future<void> markAutoSyncSucceeded(
    DateTime value, {
    String reason = 'manual',
    int uploadedChanges = 0,
    int uploadedPackages = 0,
    int downloadedPackages = 0,
    int appliedRemoteChanges = 0,
    int remoteConflicts = 0,
  });

  Future<void> markAutoSyncFailed(
    DateTime value,
    String errorMessage, {
    String reason = 'manual',
  });

  Future<void> clearMetadata();
}

class SharedPreferencesWebDavSyncMetadataStore
    implements WebDavSyncMetadataStore {
  const SharedPreferencesWebDavSyncMetadataStore();

  static const _lastUploadedAtKey = 'sync.webdav.lastUploadedAt';
  static const _lastRestoredAtKey = 'sync.webdav.lastRestoredAt';
  static const _lastDeletedAtKey = 'sync.webdav.lastDeletedAt';
  static const _lastAutoSyncStartedAtKey = 'sync.webdav.lastAutoSyncStartedAt';
  static const _lastAutoSyncSucceededAtKey =
      'sync.webdav.lastAutoSyncSucceededAt';
  static const _lastAutoSyncFailedAtKey = 'sync.webdav.lastAutoSyncFailedAt';
  static const _lastAutoSyncErrorKey = 'sync.webdav.lastAutoSyncError';
  static const _recentSyncActivitiesKey = 'sync.webdav.recentActivities';
  static const _maxRecentSyncActivities = 10;

  @override
  Future<WebDavSyncMetadata> readMetadata() async {
    final preferences = await SharedPreferences.getInstance();
    return WebDavSyncMetadata(
      lastUploadedAt: _readDateTime(preferences, _lastUploadedAtKey),
      lastRestoredAt: _readDateTime(preferences, _lastRestoredAtKey),
      lastDeletedAt: _readDateTime(preferences, _lastDeletedAtKey),
      lastAutoSyncStartedAt: _readDateTime(
        preferences,
        _lastAutoSyncStartedAtKey,
      ),
      lastAutoSyncSucceededAt: _readDateTime(
        preferences,
        _lastAutoSyncSucceededAtKey,
      ),
      lastAutoSyncFailedAt: _readDateTime(
        preferences,
        _lastAutoSyncFailedAtKey,
      ),
      lastAutoSyncError: preferences.getString(_lastAutoSyncErrorKey),
      recentSyncActivities: _readRecentSyncActivities(preferences),
    );
  }

  @override
  Future<void> markUploaded(DateTime value) async {
    await _writeDateTime(_lastUploadedAtKey, value);
  }

  @override
  Future<void> markRestored(DateTime value) async {
    await _writeDateTime(_lastRestoredAtKey, value);
  }

  @override
  Future<void> markDeleted(DateTime value) async {
    await _writeDateTime(_lastDeletedAtKey, value);
  }

  @override
  Future<void> markAutoSyncStarted(DateTime value) async {
    await _writeDateTime(_lastAutoSyncStartedAtKey, value);
  }

  @override
  Future<void> markAutoSyncSucceeded(
    DateTime value, {
    String reason = 'manual',
    int uploadedChanges = 0,
    int uploadedPackages = 0,
    int downloadedPackages = 0,
    int appliedRemoteChanges = 0,
    int remoteConflicts = 0,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _lastAutoSyncSucceededAtKey,
      value.toUtc().toIso8601String(),
    );
    await preferences.remove(_lastAutoSyncErrorKey);
    await _appendRecentSyncActivity(
      preferences,
      WebDavSyncActivityEntry(
        finishedAt: value,
        outcome: 'success',
        reason: reason,
        uploadedChanges: uploadedChanges,
        uploadedPackages: uploadedPackages,
        downloadedPackages: downloadedPackages,
        appliedRemoteChanges: appliedRemoteChanges,
        remoteConflicts: remoteConflicts,
      ),
    );
  }

  @override
  Future<void> markAutoSyncFailed(
    DateTime value,
    String errorMessage, {
    String reason = 'manual',
  }) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _lastAutoSyncFailedAtKey,
      value.toUtc().toIso8601String(),
    );
    await preferences.setString(_lastAutoSyncErrorKey, errorMessage);
    await _appendRecentSyncActivity(
      preferences,
      WebDavSyncActivityEntry(
        finishedAt: value,
        outcome: 'failed',
        reason: reason,
        errorMessage: errorMessage,
      ),
    );
  }

  @override
  Future<void> clearMetadata() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_lastUploadedAtKey);
    await preferences.remove(_lastRestoredAtKey);
    await preferences.remove(_lastDeletedAtKey);
    await preferences.remove(_lastAutoSyncStartedAtKey);
    await preferences.remove(_lastAutoSyncSucceededAtKey);
    await preferences.remove(_lastAutoSyncFailedAtKey);
    await preferences.remove(_lastAutoSyncErrorKey);
    await preferences.remove(_recentSyncActivitiesKey);
  }

  List<WebDavSyncActivityEntry> _readRecentSyncActivities(
    SharedPreferences preferences,
  ) {
    final encoded = preferences.getString(_recentSyncActivitiesKey);
    if (encoded == null || encoded.isEmpty) {
      return const [];
    }

    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! List) {
        return const [];
      }
      return decoded
          .whereType<Map>()
          .map((value) => value.cast<String, Object?>())
          .map(WebDavSyncActivityEntry.fromJson)
          .nonNulls
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<void> _appendRecentSyncActivity(
    SharedPreferences preferences,
    WebDavSyncActivityEntry entry,
  ) async {
    final entries = [
      entry,
      ..._readRecentSyncActivities(preferences),
    ].take(_maxRecentSyncActivities).toList(growable: false);
    await preferences.setString(
      _recentSyncActivitiesKey,
      jsonEncode(entries.map((entry) => entry.toJson()).toList()),
    );
  }

  DateTime? _readDateTime(SharedPreferences preferences, String key) {
    final value = preferences.getString(key);
    if (value == null || value.isEmpty) {
      return null;
    }
    return DateTime.tryParse(value)?.toUtc();
  }

  Future<void> _writeDateTime(String key, DateTime value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(key, value.toUtc().toIso8601String());
  }
}
