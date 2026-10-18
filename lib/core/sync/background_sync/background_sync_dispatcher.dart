enum BackgroundSyncReason { conflictResolved }

typedef BackgroundSyncRunner =
    Future<void> Function(BackgroundSyncReason reason);

typedef BackgroundSyncFailureHandler =
    Future<void> Function({
      required BackgroundSyncReason reason,
      required Object error,
    });

class BackgroundSyncDispatcher {
  BackgroundSyncDispatcher({required this.runSync, this.onFailure});

  final BackgroundSyncRunner runSync;
  final BackgroundSyncFailureHandler? onFailure;
  bool _running = false;

  Future<void> trigger(BackgroundSyncReason reason) async {
    if (_running) {
      return;
    }

    _running = true;
    try {
      await runSync(reason);
    } catch (error) {
      try {
        await onFailure?.call(reason: reason, error: error);
      } catch (_) {
        // Failure reporting is also best-effort.
      }
      // Background sync is opportunistic; callers should not fail because a
      // network sync failed after the user action already succeeded.
    } finally {
      _running = false;
    }
  }
}

class BackgroundSyncException implements Exception {
  const BackgroundSyncException(this.message);

  final String message;

  @override
  String toString() => 'BackgroundSyncException: $message';
}
