import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:miji/core/sync/delta_sync/delta_conflict_models.dart';
import 'package:miji/core/sync/delta_sync/delta_conflict_resolver.dart';
import 'package:miji/core/sync/delta_sync/delta_conflict_store.dart';
import 'package:miji/core/sync/delta_sync/delta_package_models.dart';
import 'package:miji/core/sync/delta_sync/delta_sync_providers.dart';
import 'package:miji/core/sync/delta_sync/sync_identity_store.dart';
import 'package:miji/core/sync/background_sync/background_sync_dispatcher.dart';
import 'package:miji/core/sync/background_sync/background_sync_providers.dart';
import 'package:miji/features/bookkeeping/application/money_delta_conflict_apply_service.dart';
import 'package:miji/features/bookkeeping/providers/bookkeeping_providers.dart';
import 'package:miji/features/settings/presentation/widgets/sync_conflict_panel.dart';

void main() {
  testWidgets('shows empty conflict state', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserOpenDeltaConflictsProvider.overrideWith(
            (ref) async => const <StoredDeltaConflict>[],
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: SyncConflictPanel())),
      ),
    );
    await tester.pump();

    expect(find.text('同步冲突'), findsOneWidget);
    expect(find.text('暂无同步冲突'), findsOneWidget);
  });

  testWidgets('shows unresolved conflict rows', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserOpenDeltaConflictsProvider.overrideWith(
            (ref) async => [_storedConflict()],
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: SyncConflictPanel())),
      ),
    );
    await tester.pump();

    expect(find.text('同步冲突'), findsOneWidget);
    expect(find.text('money_transactions · tx-1'), findsOneWidget);
    expect(find.textContaining('基础信息'), findsOneWidget);
    expect(find.textContaining('备注'), findsOneWidget);
  });

  testWidgets('opens conflict detail and resolves with field choices', (
    tester,
  ) async {
    final applyService = _FakeMoneyDeltaConflictApplyService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserOpenDeltaConflictsProvider.overrideWith(
            (ref) async => [_storedConflict()],
          ),
          moneyDeltaConflictApplyServiceProvider.overrideWithValue(
            applyService,
          ),
          syncIdentityResolverProvider.overrideWithValue(
            const FixedSyncIdentityResolver(
              SyncIdentity(deviceId: 'device-a', datasetId: 'dataset-1'),
            ),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: SyncConflictPanel())),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('money_transactions · tx-1'));
    await tester.pumpAndSettle();

    expect(find.text('处理冲突'), findsOneWidget);
    expect(find.text('本地'), findsWidgets);
    expect(find.text('远端'), findsWidgets);

    await tester.tap(find.text('远端').first);
    await tester.pump();
    await tester.tap(find.byTooltip('确认'));
    await tester.pumpAndSettle();

    expect(applyService.conflictIds, ['conflict-1']);
    expect(applyService.deviceIds, ['device-a']);
    expect(
      applyService.choices.single
          .where((choice) => choice.side == DeltaConflictSide.remote)
          .map((choice) => choice.group),
      [TransactionConflictFieldGroup.basic],
    );
  });

  testWidgets('triggers background sync after successful resolution', (
    tester,
  ) async {
    final applyService = _FakeMoneyDeltaConflictApplyService();
    final syncTrigger = _FakeConflictResolvedSyncTrigger();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserOpenDeltaConflictsProvider.overrideWith(
            (ref) async => [_storedConflict()],
          ),
          moneyDeltaConflictApplyServiceProvider.overrideWithValue(
            applyService,
          ),
          syncIdentityResolverProvider.overrideWithValue(
            const FixedSyncIdentityResolver(
              SyncIdentity(deviceId: 'device-a', datasetId: 'dataset-1'),
            ),
          ),
          backgroundSyncTriggerProvider.overrideWithValue(syncTrigger.call),
        ],
        child: const MaterialApp(home: Scaffold(body: SyncConflictPanel())),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('money_transactions · tx-1'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('确认'));
    await tester.pumpAndSettle();

    expect(syncTrigger.callCount, 1);
    expect(find.text('处理冲突'), findsNothing);
  });
  testWidgets('keeps detail open and shows error when resolution fails', (
    tester,
  ) async {
    final applyService = _FakeMoneyDeltaConflictApplyService(
      error: StateError('balance rejected'),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserOpenDeltaConflictsProvider.overrideWith(
            (ref) async => [_storedConflict()],
          ),
          moneyDeltaConflictApplyServiceProvider.overrideWithValue(
            applyService,
          ),
          syncIdentityResolverProvider.overrideWithValue(
            const FixedSyncIdentityResolver(
              SyncIdentity(deviceId: 'device-a', datasetId: 'dataset-1'),
            ),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: SyncConflictPanel())),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('money_transactions · tx-1'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('确认'));
    await tester.pumpAndSettle();

    expect(find.text('处理冲突'), findsOneWidget);
    expect(find.textContaining('冲突处理失败'), findsOneWidget);
    expect(applyService.conflictIds, ['conflict-1']);
  });
  testWidgets('does not offer remote choice for unsupported field groups', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserOpenDeltaConflictsProvider.overrideWith(
            (ref) async => [
              _storedConflict(
                fieldGroups: const {TransactionConflictFieldGroup.split},
                changedFields: const {'split_details': []},
              ),
            ],
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: SyncConflictPanel())),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('money_transactions · tx-1'));
    await tester.pumpAndSettle();

    expect(find.text('处理冲突'), findsOneWidget);
    expect(find.text('暂不支持远端应用'), findsOneWidget);
    expect(find.text('远端'), findsNothing);
  });
}

StoredDeltaConflict _storedConflict({
  Set<TransactionConflictFieldGroup> fieldGroups = const {
    TransactionConflictFieldGroup.basic,
    TransactionConflictFieldGroup.text,
  },
  Map<String, Object?> changedFields = const {
    'amount_minor': 1200,
    'notes': 'remote',
  },
}) {
  return StoredDeltaConflict(
    id: 'conflict-1',
    datasetId: 'dataset-1',
    userId: 'user-1',
    tableName: 'money_transactions',
    recordId: 'tx-1',
    fieldGroups: fieldGroups,
    localSnapshot: const {'amount_minor': 900, 'notes': 'local'},
    remoteChange: DeltaChangeRecord(
      table: 'money_transactions',
      recordId: 'tx-1',
      operation: 'update',
      baseVersion: 1,
      newVersion: 2,
      changedFields: changedFields,
      recordSnapshot: {'amount_minor': 1200, 'notes': 'remote'},
    ),
    createdAt: DateTime.utc(2026, 7, 11, 12),
    updatedAt: DateTime.utc(2026, 7, 11, 12),
  );
}

class _FakeMoneyDeltaConflictApplyService
    implements MoneyDeltaConflictApplyService {
  _FakeMoneyDeltaConflictApplyService({this.error});

  final Object? error;
  final conflictIds = <String>[];
  final deviceIds = <String>[];
  final choices = <List<DeltaConflictFieldChoice>>[];

  @override
  Future<void> applyTransactionConflict({
    required StoredDeltaConflict conflict,
    required String deviceId,
    required List<DeltaConflictFieldChoice> choices,
  }) async {
    conflictIds.add(conflict.id);
    deviceIds.add(deviceId);
    this.choices.add(choices);
    final error = this.error;
    if (error != null) {
      throw error;
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeConflictResolvedSyncTrigger {
  int callCount = 0;
  final _completer = Completer<void>();

  Future<void> call(BackgroundSyncReason reason) {
    callCount += 1;
    return _completer.future;
  }
}
