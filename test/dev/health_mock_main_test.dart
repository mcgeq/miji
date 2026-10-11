import 'package:flutter_test/flutter_test.dart';

import 'package:miji/dev/health_mock_main.dart';

void main() {
  testWidgets('health mock app renders without a database', (tester) async {
    await tester.pumpWidget(const HealthMockApp());

    expect(find.text('日历'), findsOneWidget);
    expect(find.text('趋势'), findsOneWidget);
    expect(find.text('设置'), findsOneWidget);

    await tester.tap(find.text('趋势'));
    await tester.pumpAndSettle();

    expect(find.text('周期长度'), findsWidgets);
    expect(find.text('经期时长'), findsWidgets);
    expect(find.text('情绪分布'), findsOneWidget);
    expect(find.text('数据完整度'), findsOneWidget);
  });
}
