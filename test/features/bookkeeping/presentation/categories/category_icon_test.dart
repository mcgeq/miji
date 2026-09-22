import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miji/features/bookkeeping/presentation/categories/category_icon.dart';

void main() {
  group('materialIconForCategoryIcon', () {
    test('maps seed icon names to real Material icons', () {
      // 种子数据里存的是 Material 图标名；修复前这些字符串被当作 emoji
      // 直接 Text() 画出来，分类下拉菜单里会出现英文单词。
      expect(materialIconForCategoryIcon('restaurant'), Icons.restaurant);
      expect(
        materialIconForCategoryIcon('breakfast_dining'),
        Icons.breakfast_dining,
      );
      expect(materialIconForCategoryIcon('category'), Icons.category);
      expect(
        materialIconForCategoryIcon('directions_bus'),
        Icons.directions_bus,
      );
      // 用户自建分类硬编码的 icon 值。
      expect(materialIconForCategoryIcon('trending_up'), Icons.trending_up);
    });

    test('returns null for unknown or empty names', () {
      expect(materialIconForCategoryIcon('not_a_real_icon'), isNull);
      expect(materialIconForCategoryIcon(''), isNull);
      expect(materialIconForCategoryIcon(null), isNull);
      expect(materialIconForCategoryIcon('  '), isNull);
    });

    test(
      'accepts emoji as unknown material names so callers can fall back',
      () {
        expect(materialIconForCategoryIcon('🍜'), isNull);
      },
    );
  });

  group('isEmojiCategoryIcon', () {
    test('detects emoji and rejects material names', () {
      expect(isEmojiCategoryIcon('🍜'), isTrue);
      expect(isEmojiCategoryIcon('restaurant'), isFalse);
      expect(isEmojiCategoryIcon(''), isFalse);
      expect(isEmojiCategoryIcon(null), isFalse);
    });
  });

  group('CategoryIconWidget', () {
    testWidgets('renders an Icon for a material name', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: CategoryIconWidget('restaurant')),
        ),
      );

      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.icon, Icons.restaurant);
      // 关键回归：不能再把图标名当文本画出来。
      expect(find.text('restaurant'), findsNothing);
    });

    testWidgets('renders text for an emoji', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: CategoryIconWidget('🍜'))),
      );

      expect(find.text('🍜'), findsOneWidget);
      expect(find.byType(Icon), findsNothing);
    });

    testWidgets('falls back when the name is unknown', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CategoryIconWidget(
              'not_a_real_icon',
              fallback: Icons.label_rounded,
            ),
          ),
        ),
      );

      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.icon, Icons.label_rounded);
    });
  });
}
