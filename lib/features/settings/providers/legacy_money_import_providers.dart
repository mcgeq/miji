import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:miji/core/auth/application/auth_session_controller.dart';
import 'package:miji/core/database/database_providers.dart';
import 'package:miji/features/bookkeeping/providers/bookkeeping_providers.dart';
import 'package:miji/features/settings/data/legacy_money_import_models.dart';
import 'package:miji/features/settings/data/legacy_money_import_service.dart';

final legacyMoneyImportServiceProvider = Provider<LegacyMoneyImportService>((
  ref,
) {
  return LegacyMoneyImportService(database: ref.watch(appDatabaseProvider));
});

final legacyMoneyImportControllerProvider =
    NotifierProvider<LegacyMoneyImportController, LegacyMoneyImportState>(
      LegacyMoneyImportController.new,
    );

enum LegacyMoneyImportOperation { idle, preview, importNow }

class LegacyMoneyImportState {
  const LegacyMoneyImportState({
    required this.operation,
    required this.isLoading,
    this.preview,
    this.result,
    this.error,
  });

  final LegacyMoneyImportOperation operation;
  final bool isLoading;
  final LegacyMoneyImportPreview? preview;
  final LegacyMoneyImportResult? result;
  final Object? error;

  static const idle = LegacyMoneyImportState(
    operation: LegacyMoneyImportOperation.idle,
    isLoading: false,
  );

  LegacyMoneyImportState copyWith({
    LegacyMoneyImportOperation? operation,
    bool? isLoading,
    LegacyMoneyImportPreview? preview,
    LegacyMoneyImportResult? result,
    Object? error,
    bool clearPreview = false,
    bool clearResult = false,
    bool clearError = false,
  }) {
    return LegacyMoneyImportState(
      operation: operation ?? this.operation,
      isLoading: isLoading ?? this.isLoading,
      preview: clearPreview ? null : preview ?? this.preview,
      result: clearResult ? null : result ?? this.result,
      error: clearError ? null : error ?? this.error,
    );
  }
}

class LegacyMoneyImportController extends Notifier<LegacyMoneyImportState> {
  @override
  LegacyMoneyImportState build() {
    return LegacyMoneyImportState.idle;
  }

  Future<void> preview(String sourcePath) async {
    final path = sourcePath.trim();
    if (path.isEmpty) {
      state = state.copyWith(
        operation: LegacyMoneyImportOperation.preview,
        isLoading: false,
        error: const LegacyMoneyImportException('请输入旧版数据文件路径'),
        clearPreview: true,
        clearResult: true,
      );
      return;
    }

    state = state.copyWith(
      operation: LegacyMoneyImportOperation.preview,
      isLoading: true,
      clearPreview: true,
      clearResult: true,
      clearError: true,
    );

    try {
      final preview = await ref
          .read(legacyMoneyImportServiceProvider)
          .preview(path);
      state = LegacyMoneyImportState(
        operation: LegacyMoneyImportOperation.preview,
        isLoading: false,
        preview: preview,
      );
    } catch (error) {
      state = LegacyMoneyImportState(
        operation: LegacyMoneyImportOperation.preview,
        isLoading: false,
        error: error,
      );
    }
  }

  Future<LegacyMoneyImportResult?> importNow(String sourcePath) async {
    final path = sourcePath.trim();
    if (path.isEmpty) {
      state = state.copyWith(
        operation: LegacyMoneyImportOperation.importNow,
        isLoading: false,
        error: const LegacyMoneyImportException('请输入旧版数据文件路径'),
      );
      return null;
    }

    state = state.copyWith(
      operation: LegacyMoneyImportOperation.importNow,
      isLoading: true,
      clearResult: true,
      clearError: true,
    );

    try {
      final userId = _requireUnlockedUserId();
      final result = await ref
          .read(legacyMoneyImportServiceProvider)
          .importNow(
            LegacyMoneyImportOptions(
              sourcePath: path,
              userId: userId,
              personalLedgerId: _defaultLedgerId(userId),
              defaultMemberId: _defaultMemberId(userId),
            ),
          );
      await _refreshDerivedMoneyData(userId);
      _refreshMoneyProviders();
      state = state.copyWith(
        operation: LegacyMoneyImportOperation.importNow,
        isLoading: false,
        result: result,
        clearError: true,
      );
      return result;
    } catch (error) {
      state = state.copyWith(
        operation: LegacyMoneyImportOperation.importNow,
        isLoading: false,
        error: error,
      );
      return null;
    }
  }

  void reset() {
    state = LegacyMoneyImportState.idle;
  }

  String _requireUnlockedUserId() {
    final session = ref.read(authSessionControllerProvider);
    final userId = session.userId;
    if (!session.isUnlocked || userId == null || userId.isEmpty) {
      throw const LegacyMoneyImportException('请先登录后再导入旧版记账数据');
    }
    return userId;
  }

  void _refreshMoneyProviders() {
    ref
        .read(moneyDataRefreshCoordinatorProvider)
        .refreshAllMoneyData(clearLedgerSelection: true);
  }

  Future<void> _refreshDerivedMoneyData(String userId) async {
    try {
      await ref.read(moneyRepositoryProvider).refreshUsageStatsForUser(userId);
    } catch (_) {
      // Usage stats are derived from imported transactions and can be rebuilt
      // later; import success should not depend on this cache.
    }
  }

  String _defaultMemberId(String userId) => 'default_member_$userId';

  String _defaultLedgerId(String userId) => 'default_ledger_$userId';
}
