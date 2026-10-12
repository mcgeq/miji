import 'package:flutter_test/flutter_test.dart';
import 'package:miji/features/home/domain/home_block.dart';

void main() {
  test('defaults follow registry defaults and order', () {
    final layout = HomeBlockLayout.defaults();
    expect(layout.isVisible(HomeBlockId.healthForecast), isFalse);
    expect(layout.isVisible(HomeBlockId.boardMoney), isTrue);
    expect(layout.order.first, HomeBlockId.boardMoney);
    expect(layout.order.length, HomeBlockId.values.length);
  });

  test('toggle flips only the target block', () {
    final layout = HomeBlockLayout.defaults().toggle(
      HomeBlockId.moneyRecent,
      false,
    );
    expect(layout.isVisible(HomeBlockId.moneyRecent), isFalse);
    expect(layout.isVisible(HomeBlockId.moneyCategories), isTrue);
  });

  test('fromStorage tolerates unknown keys and missing blocks', () {
    final layout = HomeBlockLayout.fromStorage(
      visibilityJson: '{"money.recent":false,"nope.x":true}',
      orderJson: '["action.todo","nope.x"]',
    );
    expect(layout.isVisible(HomeBlockId.moneyRecent), isFalse);
    // 未知 key 被丢弃，未列出的块按默认补到末尾，顺序不丢块。
    expect(layout.order.toSet(), HomeBlockId.values.toSet());
    expect(layout.order.first, HomeBlockId.actionTodo);
  });

  test('fromStorage survives malformed json', () {
    final layout = HomeBlockLayout.fromStorage(
      visibilityJson: 'not-json',
      orderJson: '{oops',
    );
    expect(layout.order.length, HomeBlockId.values.length);
  });

  test('reorder moves the item', () {
    final base = HomeBlockLayout.defaults();
    final moved = base.reorder(0, 3);
    expect(moved.order[3], base.order[0]);
    expect(moved.order.toSet(), base.order.toSet());
  });

  test('json round-trips', () {
    final layout = HomeBlockLayout.defaults()
        .toggle(HomeBlockId.actionHabit, false)
        .reorder(0, 5);
    final restored = HomeBlockLayout.fromStorage(
      visibilityJson: layout.visibilityJson,
      orderJson: layout.orderJson,
    );
    expect(restored.visibilityJson, layout.visibilityJson);
    expect(restored.orderJson, layout.orderJson);
  });

  test('board cell count helper', () {
    final layout = HomeBlockLayout.defaults().toggle(
      HomeBlockId.boardHealth,
      false,
    );
    expect(layout.visibleBoardCellCount, 2);
  });

  test('layout mode defaults to pager and only list maps to list', () {
    expect(HomeLayoutMode.fromStorage(null), HomeLayoutMode.pager);
    expect(HomeLayoutMode.fromStorage(''), HomeLayoutMode.pager);
    expect(HomeLayoutMode.fromStorage('pager'), HomeLayoutMode.pager);
    expect(HomeLayoutMode.fromStorage('garbage'), HomeLayoutMode.pager);
    expect(HomeLayoutMode.fromStorage('list'), HomeLayoutMode.list);
  });
}
