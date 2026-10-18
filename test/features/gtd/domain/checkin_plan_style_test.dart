import 'package:flutter_test/flutter_test.dart';

import 'package:miji/features/gtd/domain/checkin_plan_style.dart';

/// 内置 emoji / 配色的三条规则：图钉视为未选、分类默认、用户选择优先。
void main() {
  test('历史默认值「📌」等同于没选：落到分类默认', () {
    expect(
      resolvePlanEmoji(icon: legacyDefaultPlanIcon, category: '运动'),
      defaultPlanEmojiFor('运动'),
    );
    expect(resolvePlanEmoji(icon: '', category: '纪念日'), '🎂');
  });

  test('用户自己挑的 emoji 原样保留（包括不在内置集合里的）', () {
    expect(resolvePlanEmoji(icon: '🐳', category: '运动'), '🐳');
    expect(resolvePlanEmoji(icon: '🚴', category: '运动'), '🚴');
  });

  test('未知分类落到「其他」的默认值，不抛异常', () {
    expect(resolvePlanEmoji(icon: '📌', category: '不存在的分类'), '⭐');
    expect(defaultPlanColorFor('不存在的分类'), isNotEmpty);
  });

  test('每个分类都有内置 emoji，且默认值就是列表第一个', () {
    for (final category in checkinPlanCategories) {
      final list = checkinPlanEmojis[category];
      expect(list, isNotNull, reason: category);
      expect(list!, isNotEmpty, reason: category);
      expect(defaultPlanEmojiFor(category), list.first, reason: category);
      // 同一个分类里不该有重复 emoji。
      expect(list.toSet().length, list.length, reason: category);
    }
  });

  test('种子模板用过的 emoji 都在内置表里（换图标不会变成两套风格）', () {
    for (final emoji in [
      '💧',
      '🌙',
      '🍚',
      '🚽',
      '🚿', // 健康习惯
      '📖',
      '📚',
      '📝', // 学习成长
      '🏃',
      '🚶', // 运动
      '📸',
      '🍜',
      '🗺️', // 生活记录
      '🎂',
      '💕',
      '💼', // 纪念日
    ]) {
      final categories = checkinPlanEmojis.entries
          .where((entry) => entry.value.contains(emoji))
          .map((entry) => entry.key);
      expect(categories, isNotEmpty, reason: '$emoji 不在任何分类里');
    }
  });

  test('isBuiltInPlanEmoji 能区分内置与自定义', () {
    expect(isBuiltInPlanEmoji('🚶', '运动'), isTrue);
    expect(isBuiltInPlanEmoji('🐳', '运动'), isFalse);
  });

  test('颜色解析：#RRGGBB 可解析，坏值返回 null', () {
    expect(planColorValue('#0EA5E9'), 0xFF0EA5E9);
    expect(planColorValue('0EA5E9'), 0xFF0EA5E9);
    expect(planColorValue('#XYZ'), isNull);
    expect(planColorValue(null), isNull);
  });

  test('没有颜色时按分类给默认色，有颜色就照用', () {
    expect(planVisualFor(icon: '📌', category: '运动').colorHex, isNotEmpty);
    expect(
      planVisualFor(icon: '🚶', category: '运动', color: '#123456').colorHex,
      '#123456',
    );
  });

  test('换分类：没手动选过时，图标与颜色都跟着换', () {
    const initial = PlanStyleSelection(
      emoji: '⭐',
      colorHex: '#0EA5E9',
      customized: false,
    );

    final next = initial.onCategoryChanged('运动');
    expect(next.emoji, defaultPlanEmojiFor('运动'));
    expect(next.colorHex, defaultPlanColorFor('运动'));
    expect(next.customized, isFalse);
  });

  test('换分类：手动选过之后一律不动', () {
    const customized = PlanStyleSelection(
      emoji: '🐳',
      colorHex: '#123456',
      customized: true,
    );

    final next = customized.onCategoryChanged('纪念日');
    expect(next.emoji, '🐳', reason: '用户自己的选择不能被分类默认顶掉');
    expect(next.colorHex, '#123456');
    expect(next.customized, isTrue);
  });

  test('点 emoji 会标记为自定义；点颜色不改变这个标记', () {
    const initial = PlanStyleSelection(
      emoji: '⭐',
      colorHex: '#0EA5E9',
      customized: false,
    );

    final pickedEmoji = initial.withEmoji('🎁');
    expect(pickedEmoji.customized, isTrue);
    expect(pickedEmoji.emoji, '🎁');

    final pickedColor = pickedEmoji.withColor('#10B981');
    expect(pickedColor.customized, isTrue, reason: '换颜色不等于换图标');
    expect(pickedColor.colorHex, '#10B981');
  });

  test('编辑已有计划：内置 emoji 不算自定义，图钉算未选', () {
    final builtIn = PlanStyleSelection.fromPlan(
      icon: '🚶',
      category: '运动',
      color: '#84CC16',
    );
    expect(builtIn.customized, isFalse);
    expect(builtIn.colorHex, '#84CC16');

    final legacy = PlanStyleSelection.fromPlan(
      icon: legacyDefaultPlanIcon,
      category: '运动',
      color: '',
    );
    expect(legacy.customized, isTrue, reason: '图钉不属于内置集合，显示为自定义');
    expect(legacy.colorHex, defaultPlanColorFor('运动'), reason: '旧数据没颜色时补默认');

    final custom = PlanStyleSelection.fromPlan(
      icon: '🐳',
      category: '运动',
      color: '#123456',
    );
    expect(custom.customized, isTrue);
  });
}
