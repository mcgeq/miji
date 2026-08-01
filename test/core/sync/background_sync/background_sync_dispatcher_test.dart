import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:miji/core/sync/background_sync/background_sync_dispatcher.dart';

void main() {
  test('trigger runs sync for the given reason', () async {
    final reasons = <BackgroundSyncReason>[];
    final dispatcher = BackgroundSyncDispatcher(
      runSync: (reason) async => reasons.add(reason),
    );

    await dispatcher.trigger(BackgroundSyncReason.conflictResolved);

    expect(reasons, [BackgroundSyncReason.conflictResolved]);
  });

  test(
    'trigger swallows sync errors so fire and forget callers stay safe',
    () async {
      final dispatcher = BackgroundSyncDispatcher(
        runSync: (_) async => throw StateError('network unavailable'),
      );

      await dispatcher.trigger(BackgroundSyncReason.conflictResolved);
    },
  );

  test('trigger reports sync errors to failure callback', () async {
    final failures = <({BackgroundSyncReason reason, Object error})>[];
    final dispatcher = BackgroundSyncDispatcher(
      runSync: (_) async => throw StateError('network unavailable'),
      onFailure: ({required reason, required error}) async {
        failures.add((reason: reason, error: error));
      },
    );

    await dispatcher.trigger(BackgroundSyncReason.conflictResolved);

    expect(failures, hasLength(1));
    expect(failures.single.reason, BackgroundSyncReason.conflictResolved);
    expect(failures.single.error, isA<StateError>());
  });
  test('trigger swallows failure callback errors too', () async {
    final dispatcher = BackgroundSyncDispatcher(
      runSync: (_) async => throw StateError('network unavailable'),
      onFailure: ({required reason, required error}) async {
        throw StateError('metadata unavailable');
      },
    );

    await dispatcher.trigger(BackgroundSyncReason.conflictResolved);
  });
  test('trigger skips concurrent runs', () async {
    final gate = Completer<void>();
    var runCount = 0;
    final dispatcher = BackgroundSyncDispatcher(
      runSync: (_) async {
        runCount += 1;
        await gate.future;
      },
    );

    final first = dispatcher.trigger(BackgroundSyncReason.conflictResolved);
    await Future<void>.delayed(Duration.zero);
    await dispatcher.trigger(BackgroundSyncReason.conflictResolved);

    expect(runCount, 1);
    gate.complete();
    await first;
  });
}
