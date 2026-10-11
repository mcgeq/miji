import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:miji/core/auth/application/auth_session_controller.dart';

/// 「这不是同一笔还款」的忽略名单。
///
/// 冲突判定是启发式的（同账户 + 同日 + 同金额），确实可能把「每月 15 日还花呗
/// 1000」和「每月 15 日充话费 1000」认成同一笔。用户点过「这是两笔不同支出」
/// 之后就不能再反复弹，否则提示会变成噪声，用户会习惯性忽略真正的冲突。
///
/// 这是纯 UI 偏好（跟设备走，不参与同步）：即使换设备重新提示一次，也只是多
/// 看一眼，不会造成任何账务错误。
abstract final class AutoPostingConflictIgnoreStore {
  static String _keyFor(String userId) =>
      'money_auto_posting_conflict_ignored_$userId';

  static Future<Set<String>> load(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_keyFor(userId));
    if (raw == null) {
      return <String>{};
    }
    return raw.toSet();
  }

  static Future<void> save(String userId, Set<String> keys) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_keyFor(userId), keys.toList(growable: false));
  }
}

final autoPostingConflictIgnoreProvider =
    AsyncNotifierProvider<AutoPostingConflictIgnoreController, Set<String>>(
      AutoPostingConflictIgnoreController.new,
    );

class AutoPostingConflictIgnoreController extends AsyncNotifier<Set<String>> {
  @override
  Future<Set<String>> build() async {
    final userId = ref.watch(authSessionControllerProvider).userId;
    if (userId == null || userId.isEmpty) {
      return const <String>{};
    }
    return AutoPostingConflictIgnoreStore.load(userId);
  }

  Future<void> ignore(String conflictKey) async {
    final userId = ref.read(authSessionControllerProvider).userId;
    final current = state.value ?? const <String>{};
    final next = {...current, conflictKey};
    state = AsyncData(next);
    if (userId == null || userId.isEmpty) {
      return;
    }
    await AutoPostingConflictIgnoreStore.save(userId, next);
  }

  /// 清空忽略名单。
  ///
  /// 用户点「两笔不同支出」时可能只是手滑，没有这个出口他就再也看不到那条
  /// 冲突了——于是真正的重复记账会被永久藏起来。
  Future<void> clear() async {
    final userId = ref.read(authSessionControllerProvider).userId;
    state = const AsyncData(<String>{});
    if (userId == null || userId.isEmpty) {
      return;
    }
    await AutoPostingConflictIgnoreStore.save(userId, const <String>{});
  }

  Future<void> restore(String conflictKey) async {
    final userId = ref.read(authSessionControllerProvider).userId;
    final current = state.value ?? const <String>{};
    final next = {...current}..remove(conflictKey);
    state = AsyncData(next);
    if (userId == null || userId.isEmpty) {
      return;
    }
    await AutoPostingConflictIgnoreStore.save(userId, next);
  }
}
