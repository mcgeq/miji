import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:miji/core/auth/application/auth_session_controller.dart';
import 'package:miji/features/bookkeeping/domain/money_transaction_entity.dart';
import 'package:miji/features/bookkeeping/providers/bookkeeping_providers.dart';
import 'package:miji/features/gtd/domain/checkin_models.dart';
import 'package:miji/features/gtd/providers/checkin_providers.dart';
import 'package:miji/features/health/providers/health_providers.dart';
import 'package:miji/features/life_energy/providers/life_energy_providers.dart';
import 'package:miji/features/timeline/domain/timeline_assembler.dart';
import 'package:miji/features/timeline/domain/timeline_event.dart';
import 'package:miji/features/todo/domain/todo_models.dart';
import 'package:miji/features/todo/providers/todo_providers.dart';

/// 时间线看哪一段。
enum TimelineScope {
  day('今天'),
  week('本周'),
  month('本月');

  const TimelineScope(this.label);

  final String label;
}

/// 看日程还是看回顾。两者共用同一份事件，只是过滤与排序不同。
enum TimelineViewMode {
  schedule('日程'),
  history('回顾');

  const TimelineViewMode(this.label);

  final String label;
}

/// 当前窗口：选中日 + 范围 + 视图。日期条与分段控件都改它。
final timelineScopeProvider =
    NotifierProvider<TimelineScopeController, TimelineSelection>(
      TimelineScopeController.new,
    );

/// 选中的日期与范围。
@immutable
class TimelineSelection {
  const TimelineSelection({
    required this.anchor,
    required this.scope,
    this.viewMode = TimelineViewMode.schedule,
  });

  final DateTime anchor;
  final TimelineScope scope;
  final TimelineViewMode viewMode;

  TimelineSelection copyWith({
    DateTime? anchor,
    TimelineScope? scope,
    TimelineViewMode? viewMode,
  }) => TimelineSelection(
    anchor: anchor ?? this.anchor,
    scope: scope ?? this.scope,
    viewMode: viewMode ?? this.viewMode,
  );
}

class TimelineScopeController extends Notifier<TimelineSelection> {
  @override
  TimelineSelection build() =>
      TimelineSelection(anchor: _today(), scope: TimelineScope.week);

  void selectDay(DateTime day) {
    state = state.copyWith(anchor: _dayKey(day));
  }

  void setScope(TimelineScope scope) {
    state = state.copyWith(scope: scope);
  }

  void setViewMode(TimelineViewMode mode) {
    state = state.copyWith(viewMode: mode);
  }

  void shift(int days) {
    state = state.copyWith(
      anchor: DateTime.utc(
        state.anchor.year,
        state.anchor.month,
        state.anchor.day + days,
      ),
    );
  }

  static DateTime _dayKey(DateTime value) =>
      DateTime.utc(value.year, value.month, value.day);

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime.utc(now.year, now.month, now.day);
  }
}

/// 窗口本身（供日期条与查询共用）。
final timelineWindowProvider = Provider<TimelineWindow>((ref) {
  final selected = ref.watch(timelineScopeProvider);
  // 回顾永远按月：一天的回顾只有一行摘要，一周的回顾看不出趋势。
  if (selected.viewMode == TimelineViewMode.history) {
    return TimelineWindow.monthOf(selected.anchor);
  }
  return switch (selected.scope) {
    TimelineScope.day => TimelineWindow.dayOf(selected.anchor),
    TimelineScope.week => TimelineWindow.weekOf(selected.anchor),
    TimelineScope.month => TimelineWindow.monthOf(selected.anchor),
  };
});

/// 某一路数据读取失败。**不抛给整页**：时间线是四路聚合，一路挂了其余照常。
class TimelineSourceFailure {
  const TimelineSourceFailure({required this.module, required this.error});

  final TimelineModule module;
  final Object error;
}

/// 时间线的完整结果。
class TimelineResult {
  const TimelineResult({required this.timeline, required this.failures});

  final Timeline timeline;
  final List<TimelineSourceFailure> failures;

  bool get hasFailures => failures.isNotEmpty;

  TimelineModule? failedModuleNamed(TimelineModule module) =>
      failures.any((failure) => failure.module == module) ? module : null;
}

/// 一路事件的读取器。
///
/// 做成 provider 而不是直接调仓库，是为了**能在测试里替换**：不然要测「某一路
/// 失败时其余照常」，就得把四个真实仓库全造出来。
typedef TimelineEventReader =
    Future<List<TimelineEvent>> Function(Ref ref, TimelineWindow window);

final timelineMoneyReaderProvider = Provider<TimelineEventReader>((ref) {
  return (ref, window) => _moneyEvents(ref, window);
});

final timelineTodoReaderProvider = Provider<TimelineEventReader>((ref) {
  return (ref, window) => _todoEvents(ref, window);
});

final timelineHabitReaderProvider = Provider<TimelineEventReader>((ref) {
  return (ref, window) => _habitEvents(ref, window);
});

final timelineHealthReaderProvider = Provider<TimelineEventReader>((ref) {
  return (ref, window) => _healthEvents(ref, window);
});

final timelineLifeEnergyReaderProvider = Provider<TimelineEventReader>((ref) {
  return (ref, window) => _lifeEnergyEvents(ref, window);
});

/// 聚合。
///
/// 每一路单独 try：健康那一页要二次验证、记账可能在重算，任何一路抛错都不该
/// 让「今天要面对什么」整块消失。
final timelineProvider = FutureProvider.autoDispose<TimelineResult>((
  ref,
) async {
  final window = ref.watch(timelineWindowProvider);
  return loadTimeline(ref, window);
});

/// 按给定窗口读满五路并组装。
///
/// 抽出来是为了让首页的「接下来」能用自己的窗口（未来 7 天）复用同一套读取器，
/// 而不是把五个仓库的调用再抄一遍——抄一次的代价是两边永远不同步。
Future<TimelineResult> loadTimeline(Ref ref, TimelineWindow window) async {
  final session = ref.read(authSessionControllerProvider);
  final failures = <TimelineSourceFailure>[];
  final groups = <List<TimelineEvent>>[];

  Future<void> load(
    TimelineModule module,
    Future<List<TimelineEvent>> Function() read,
  ) async {
    try {
      groups.add(await read());
    } catch (error) {
      failures.add(TimelineSourceFailure(module: module, error: error));
    }
  }

  if (session.isUnlocked && session.userId != null) {
    await load(
      TimelineModule.money,
      () => ref.read(timelineMoneyReaderProvider)(ref, window),
    );
    await load(
      TimelineModule.action,
      () => ref.read(timelineTodoReaderProvider)(ref, window),
    );
    await load(
      TimelineModule.action,
      () => ref.read(timelineHabitReaderProvider)(ref, window),
    );
    await load(
      TimelineModule.health,
      () => ref.read(timelineHealthReaderProvider)(ref, window),
    );
    await load(
      TimelineModule.lifeEnergy,
      () => ref.read(timelineLifeEnergyReaderProvider)(ref, window),
    );
  }

  return TimelineResult(
    timeline: assembleTimeline(window: window, eventGroups: groups),
    failures: failures,
  );
}

Future<List<TimelineEvent>> _moneyEvents(Ref ref, TimelineWindow window) async {
  final userId = ref.read(authSessionControllerProvider).userId;
  if (userId == null) {
    return const <TimelineEvent>[];
  }
  final repository = ref.watch(moneyRepositoryProvider);
  // 流水：窗口内的事实。按时间倒序，与流水列表同一口径。
  final page = await repository.listTransactions(
    userId,
    MoneyTransactionQuery(
      pageSize: 200,
      dateStart: window.start,
      dateEnd: DateTime.utc(
        window.end.year,
        window.end.month,
        window.end.day,
        23,
        59,
        59,
      ),
    ),
  );
  // 未来义务：和「本月还能自由花」「未来现金流」同一套来源（含去重）。
  final commitments = await repository.upcomingExpenseCommitments(
    userId,
    start: window.start,
    end: DateTime.utc(window.end.year, window.end.month, window.end.day + 1),
    includePendingTransactions: false,
  );
  return moneyEvents(transactions: page.items, commitments: commitments);
}

Future<List<TimelineEvent>> _todoEvents(Ref ref, TimelineWindow window) async {
  final userId = ref.read(authSessionControllerProvider).userId;
  if (userId == null) {
    return const <TimelineEvent>[];
  }
  final repository = ref.watch(todoRepositoryProvider);
  // 待办量级在几百条，一次取回按窗口过滤，比按天查 31 次划算。
  final tasks = await repository.getTasks(userId, const TodoTaskFilter());
  return todoEvents(tasks.where((task) => _inWindow(task, window)));
}

bool _inWindow(TodoTask task, TimelineWindow window) {
  final completedAt = task.completedAt;
  if (completedAt != null) {
    return window.contains(completedAt.toUtc());
  }
  final day = task.dueAt?.toUtc() ?? task.scheduledDate?.toUtc();
  return day != null && window.contains(day);
}

Future<List<TimelineEvent>> _habitEvents(Ref ref, TimelineWindow window) async {
  final userId = ref.read(authSessionControllerProvider).userId;
  if (userId == null) {
    return const <TimelineEvent>[];
  }
  final repository = ref.watch(checkinRepositoryProvider);
  final plans = await repository.getActivePlans(userId);
  final records = <CheckinRecord>[];
  // 打卡按天查（仓库没有「按用户 + 区间」的读口）；窗口最多 31 天。
  for (final day in window.days) {
    records.addAll(await repository.getRecordsByDate(userId, day));
  }
  return habitEvents(records: records, plans: plans);
}

Future<List<TimelineEvent>> _lifeEnergyEvents(
  Ref ref,
  TimelineWindow window,
) async {
  final userId = ref.read(authSessionControllerProvider).userId;
  if (userId == null) {
    return const <TimelineEvent>[];
  }
  final repository = ref.watch(lifeEnergyRepositoryProvider);
  // 段与年终奖量级很小（几十年也就几十条），一次取回按窗口过滤。
  final segments = await repository.fetchSalarySegments(userId);
  final wishlist = await repository.watchWishlist(userId: userId).first;
  return lifeEnergyEvents(
    segments: segments.where(
      (segment) => window.contains(
        DateTime.utc(segment.effectiveYear, segment.effectiveMonth, 1),
      ),
    ),
    wishlist: wishlist.where(
      (entry) =>
          entry.cooldownUntil != null && window.contains(entry.cooldownUntil!),
    ),
  );
}

Future<List<TimelineEvent>> _healthEvents(
  Ref ref,
  TimelineWindow window,
) async {
  final markers = await ref.watch(
    currentUserHealthCalendarMarkersProvider(
      DateTimeRange(start: window.start, end: window.end),
    ).future,
  );
  return healthEvents(markers);
}
