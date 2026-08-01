class AuthSession {
  const AuthSession({
    required this.userId,
    required this.isUnlocked,
    this.isRestoring = false,
    this.unlockedAt,
  });

  const AuthSession.locked()
    : userId = null,
      isUnlocked = false,
      isRestoring = false,
      unlockedAt = null;

  const AuthSession.restoring()
    : userId = null,
      isUnlocked = false,
      isRestoring = true,
      unlockedAt = null;

  final String? userId;
  final bool isUnlocked;
  final bool isRestoring;
  final DateTime? unlockedAt;

  bool get hasUser {
    return userId != null;
  }

  AuthSession copyWith({
    String? userId,
    bool? isUnlocked,
    bool? isRestoring,
    DateTime? unlockedAt,
    bool clearUserId = false,
    bool clearUnlockedAt = false,
  }) {
    return AuthSession(
      userId: clearUserId ? null : userId ?? this.userId,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      isRestoring: isRestoring ?? this.isRestoring,
      unlockedAt: clearUnlockedAt ? null : unlockedAt ?? this.unlockedAt,
    );
  }
}
