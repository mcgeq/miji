import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:miji/core/sync/webdav/webdav_models.dart';
import 'package:miji/core/sync/webdav/webdav_restore_timeout.dart';

void main() {
  test('returns completed restore operation result', () async {
    final result = await withWebDavRestoreApplyTimeout(
      Future<String>.value('restored'),
      timeout: const Duration(milliseconds: 20),
    );

    expect(result, 'restored');
  });

  test(
    'throws restoreTimedOut when restore operation never completes',
    () async {
      final pending = Completer<void>();

      await expectLater(
        withWebDavRestoreApplyTimeout(
          pending.future,
          timeout: const Duration(milliseconds: 1),
        ),
        throwsA(
          isA<WebDavSyncException>().having(
            (error) => error.code,
            'code',
            WebDavSyncErrorCode.restoreTimedOut,
          ),
        ),
      );
    },
  );
}
