import 'package:miji/core/auth/domain/sensitive_access_ttl_option.dart';

class SensitiveAccessSession {
  const SensitiveAccessSession({required this.ttlOption, this.verifiedAt});

  const SensitiveAccessSession.locked()
    : ttlOption = SensitiveAccessTtlOption.defaultOption,
      verifiedAt = null;

  final DateTime? verifiedAt;
  final SensitiveAccessTtlOption ttlOption;

  bool get isVerified {
    final verifiedAt = this.verifiedAt;
    if (verifiedAt == null) {
      return false;
    }

    final duration = ttlOption.duration;
    if (duration == null) {
      return true;
    }

    return DateTime.now().toUtc().difference(verifiedAt) <= duration;
  }
}
