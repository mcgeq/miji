import 'package:flutter_test/flutter_test.dart';
import 'package:miji/features/bookkeeping/domain/money_split_entity.dart';
import 'package:miji/features/bookkeeping/presentation/transactions/transaction_split_dialog.dart';

void main() {
  final now = DateTime.utc(2026, 1, 1);

  MoneyMemberEntity member({
    required String id,
    required String name,
    required String role,
    String? userId = 'user_1',
  }) {
    return MoneyMemberEntity(
      id: id,
      userId: userId!,
      name: name,
      role: role,
      status: 'active',
      color: null,
      createdAt: now,
      updatedAt: now,
    );
  }

  test('resolves the default member even when it is not first in the list', () {
    // 故意把“家人”放在“我”前面，验证按 id 匹配而非列表顺序。
    final members = [
      member(id: 'member_partner', name: '家人', role: 'participant'),
      member(id: 'default_member_user_1', name: '我', role: 'owner'),
    ];

    expect(
      resolveSelfMemberId(members: members, currentUserId: 'user_1'),
      'default_member_user_1',
    );
  });

  test('falls back to the owner member for legacy/imported data', () {
    final members = [
      member(id: 'legacy_member_1', name: '家人', role: 'participant'),
      member(id: 'legacy_owner_1', name: '我', role: 'owner'),
    ];

    expect(
      resolveSelfMemberId(members: members, currentUserId: 'user_1'),
      'legacy_owner_1',
    );
  });

  test('returns null when no self member exists', () {
    final members = [
      member(id: 'member_partner', name: '家人', role: 'participant'),
      member(id: 'member_manager', name: '管理员', role: 'manager'),
    ];

    expect(
      resolveSelfMemberId(members: members, currentUserId: 'user_1'),
      isNull,
    );
  });

  test('returns null when current user id is unavailable', () {
    final members = [
      member(id: 'default_member_user_1', name: '我', role: 'owner'),
    ];

    expect(resolveSelfMemberId(members: members, currentUserId: null), isNull);
    expect(resolveSelfMemberId(members: members, currentUserId: ''), isNull);
  });

  test('returns null for an empty member list', () {
    expect(
      resolveSelfMemberId(members: const [], currentUserId: 'user_1'),
      isNull,
    );
  });
}
