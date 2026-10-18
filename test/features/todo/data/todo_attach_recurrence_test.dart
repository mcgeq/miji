import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:miji/core/database/app_database.dart' hide TodoRecurrenceRule;
import 'package:miji/features/todo/data/drift_todo_repository.dart';
import 'package:miji/features/todo/domain/todo_models.dart';

/// 「把一条已有的任务变成重复」——这是编辑器新建模式的目的地。
/// 它要同时做三件事：任务打上模板标记、规则落库、补出实例。少一件的话，
/// 用户看到的是「设了重复但什么都没发生」。
void main() {
  late AppDatabase database;
  late DriftTodoRepository repository;
  final now = DateTime.utc(2026, 10, 18, 9);

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    repository = DriftTodoRepository(database: database, now: () => now);
    await database
        .into(database.users)
        .insert(
          UsersCompanion.insert(
            id: 'user-1',
            username: 'demo',
            email: 'demo@example.com',
            displayName: 'Demo',
            createdAt: now,
            updatedAt: now,
          ),
        );
  });

  tearDown(() async {
    await database.close();
  });

  TodoRecurrenceRule dailyRule() => TodoRecurrenceRule(
    id: '',
    userId: 'user-1',
    templateTaskId: '',
    frequencyType: RecurrenceFrequencyType.daily,
    createdAt: now,
    updatedAt: now,
  );

  test('任务变成模板、规则落库、并生成未来实例', () async {
    final task = await repository.createTask(
      const TodoTaskDraft(title: '每天喝水'),
      'user-1',
    );

    final rule = await repository.attachRecurrenceRule(task, dailyRule());

    // 1) 任务自身成了模板，并指向这条规则。
    final template = await repository.getTask(task.id);
    expect(template, isNotNull);
    expect(template!.isRecurrenceTemplate, isTrue);
    expect(template.recurrenceRuleId, rule.id);
    expect(template.title, '每天喝水', reason: '标题等字段不能丢');

    // 2) 规则读得回来。
    final saved = await repository.getRecurrenceRule(rule.id);
    expect(saved, isNotNull);
    expect(saved!.frequencyType, RecurrenceFrequencyType.daily);
    expect(saved.templateTaskId, task.id);

    // 3) 模板不再出现在任务列表里，实例出现在列表里。
    final list = await repository.getTasks('user-1', const TodoTaskFilter());
    expect(
      list.any((task) => task.id == template.id),
      isFalse,
      reason: '模板不进任务列表',
    );
    expect(list, isNotEmpty, reason: '应该按规则补出未来实例');
    for (final instance in list) {
      expect(instance.recurrenceRuleId, rule.id);
      expect(instance.title, '每天喝水');
    }
  });
}
