class UserEntity {
  const UserEntity({
    required this.id,
    required this.username,
    required this.email,
    required this.displayName,
    required this.syncEnabled,
    required this.version,
    required this.isDeleted,
    required this.createdAt,
    required this.updatedAt,
    this.emailVerifiedAt,
    this.phoneNumber,
    this.phoneVerifiedAt,
    this.avatarUri,
    this.remoteUserId,
    this.lastSyncedAt,
    this.deviceId,
  });

  final String id;
  final String username;
  final String email;
  final DateTime? emailVerifiedAt;
  final String? phoneNumber;
  final DateTime? phoneVerifiedAt;
  final String displayName;
  final String? avatarUri;
  final String? remoteUserId;
  final bool syncEnabled;
  final DateTime? lastSyncedAt;
  final String? deviceId;
  final int version;
  final bool isDeleted;
  final DateTime createdAt;
  final DateTime updatedAt;
}
