import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:miji/core/auth/application/auth_session_controller.dart';
import 'package:miji/features/gtd/domain/checkin_enums.dart';
import 'package:miji/features/gtd/domain/checkin_models.dart';
import 'package:miji/features/gtd/providers/checkin_providers.dart';
import 'package:miji/features/todo/domain/todo_models.dart';
import 'package:miji/features/todo/providers/todo_providers.dart';

class HomeTodoEntry {
  const HomeTodoEntry({required this.task});

  final TodoTask task;
}

class HomeHabitEntry {
  const HomeHabitEntry({required this.progress});

  final PlanProgress progress;

  String get name => progress.plan.name;
  String get icon => progress.plan.icon;
  CheckinPlanCategory get category => progress.plan.category;

  String get progressLabel {
    final value = progress.currentValue;
    final formatted = value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toStringAsFixed(1);
    return '$formatted/${progress.plan.targetValue.toInt()} '
        '${progress.plan.targetUnit}';
  }

  double get ratio => progress.completionRate;
  int? get streak => progress.streak;
  bool get isDone => progress.completionRate >= 1.0;
}

class HomeActionBrief {
  const HomeActionBrief({
    required this.todos,
    required this.habits,
    required this.completedCount,
    required this.totalCount,
    required this.streakDays,
  });

  static const empty = HomeActionBrief(
    todos: [],
    habits: [],
    completedCount: 0,
    totalCount: 0,
    streakDays: 0,
  );

  final List<HomeTodoEntry> todos;
  final List<HomeHabitEntry> habits;
  final int completedCount;
  final int totalCount;
  final int streakDays;
}

final homeActionBriefProvider = FutureProvider<HomeActionBrief>((ref) async {
  final session = ref.watch(authSessionControllerProvider);
  if (session.userId == null) {
    return HomeActionBrief.empty;
  }

  final results = await Future.wait([
    ref.watch(todayActionItemsProvider.future),
    ref.watch(todayProgressProvider.future),
    ref.watch(checkinStreakProvider.future),
  ]);

  return buildHomeActionBrief(
    view: results[0] as TodayActionView,
    habits: results[1] as List<PlanProgress>,
    cap: 5,
    streakDays: (results[2] as CheckinStreak).currentStreak,
  );
});

HomeActionBrief buildHomeActionBrief({
  required TodayActionView? view,
  required List<PlanProgress> habits,
  required int cap,
  int streakDays = 0,
}) {
  final todoEntries = <HomeTodoEntry>[];
  if (view != null) {
    for (final item in view.items) {
      if (item is TodayTodoActionItem) {
        todoEntries.add(HomeTodoEntry(task: item.task));
        if (todoEntries.length >= cap) {
          break;
        }
      }
    }
  }

  return HomeActionBrief(
    todos: todoEntries,
    habits: [for (final progress in habits) HomeHabitEntry(progress: progress)],
    completedCount: view?.completedCount ?? 0,
    totalCount: view?.totalCount ?? 0,
    streakDays: streakDays,
  );
}
