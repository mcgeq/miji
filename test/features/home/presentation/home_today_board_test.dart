import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miji/core/theme/app_theme.dart';
import 'package:miji/features/home/application/home_today_board_providers.dart';
import 'package:miji/features/home/domain/home_block.dart';
import 'package:miji/features/home/presentation/home_today_board.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(body: child),
  );

  testWidgets('renders the four layers of every cell', (tester) async {
    var tapped = 0;
    await tester.pumpWidget(
      wrap(
        HomeTodayBoard(
          data: const HomeTodayBoardData(
            cells: [
              HomeBoardCell(
                id: HomeBlockId.boardMoney,
                emoji: '💰',
                title: '记账',
                value: '¥413',
                label: '本月还可花',
                noteLabel: '今日支出',
                noteValue: '¥51.17',
              ),
              HomeBoardCell(
                id: HomeBlockId.boardHealth,
                emoji: '🩺',
                title: '健康',
                value: '第 3 天',
                label: '经期',
                noteLabel: '今天已记录',
              ),
            ],
          ),
          onTapCell: (_) => tapped++,
        ),
      ),
    );

    // 模块名、主值、主值口径、次要指标四层都要在。
    expect(find.text('记账'), findsOneWidget);
    expect(find.text('¥413'), findsOneWidget);
    expect(find.text('本月还可花'), findsOneWidget);
    expect(find.text('今日支出'), findsOneWidget);
    expect(find.text('¥51.17'), findsOneWidget);
    expect(find.text('健康'), findsOneWidget);
    expect(find.text('第 3 天'), findsOneWidget);
    expect(find.text('经期'), findsOneWidget);

    await tester.tap(find.text('¥413'));
    expect(tapped, 1);
  });

  testWidgets('does not overflow at a three-column phone width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      wrap(
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: HomeTodayBoard(
            data: HomeTodayBoardData(
              cells: [
                HomeBoardCell(
                  id: HomeBlockId.boardMoney,
                  emoji: '💰',
                  title: '记账',
                  value: '¥1.2w',
                  label: '本月还可花',
                  noteLabel: '今日支出',
                  noteValue: '¥1,238.00',
                ),
                HomeBoardCell(
                  id: HomeBlockId.boardHealth,
                  emoji: '🩺',
                  title: '健康',
                  value: '—',
                  label: '周期记录',
                  noteLabel: '记录一次即可预测',
                ),
                HomeBoardCell(
                  id: HomeBlockId.boardAction,
                  emoji: '✅',
                  title: '计划',
                  value: '2 / 5',
                  label: '今日已完成',
                  noteLabel: '下一件',
                  noteValue: '交房租',
                ),
              ],
            ),
            onTapCell: _noop,
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('renders nothing when there are no cells', (tester) async {
    await tester.pumpWidget(
      wrap(
        const HomeTodayBoard(
          data: HomeTodayBoardData(cells: []),
          onTapCell: _noop,
        ),
      ),
    );
    expect(find.byType(HomeTodayBoard), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

void _noop(HomeBlockId _) {}
