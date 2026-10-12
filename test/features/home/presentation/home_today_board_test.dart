import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miji/core/theme/app_theme.dart';
import 'package:miji/features/home/application/home_today_board_providers.dart';
import 'package:miji/features/home/domain/home_block.dart';
import 'package:miji/features/home/presentation/home_today_board.dart';

void main() {
  testWidgets('renders one cell per entry', (tester) async {
    var tapped = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: HomeTodayBoard(
            data: const HomeTodayBoardData(
              cells: [
                HomeBoardCell(
                  id: HomeBlockId.boardMoney,
                  emoji: '💰',
                  value: '¥413',
                  sub: '本月还可花',
                ),
                HomeBoardCell(
                  id: HomeBlockId.boardHealth,
                  emoji: '🩺',
                  value: '第 3 天',
                  sub: '今天已记录',
                ),
              ],
            ),
            onTapCell: (_) => tapped++,
          ),
        ),
      ),
    );

    expect(find.text('¥413'), findsOneWidget);
    expect(find.text('第 3 天'), findsOneWidget);
    await tester.tap(find.text('¥413'));
    expect(tapped, 1);
  });

  testWidgets('renders nothing when there are no cells', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: HomeTodayBoard(
            data: const HomeTodayBoardData(cells: []),
            onTapCell: (_) {},
          ),
        ),
      ),
    );
    expect(find.byType(HomeTodayBoard), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
