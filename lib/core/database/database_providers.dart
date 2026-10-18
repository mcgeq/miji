import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:miji/core/database/app_database.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(database.close);
  return database;
});

final databaseRestoreModeProvider =
    NotifierProvider<DatabaseRestoreModeController, bool>(
      DatabaseRestoreModeController.new,
    );

class DatabaseRestoreModeController extends Notifier<bool> {
  @override
  bool build() => false;

  void enter() {
    state = true;
  }

  void leave() {
    state = false;
  }
}
