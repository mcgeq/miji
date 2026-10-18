import 'dart:async';

/// 通知点击的传输通道。
///
/// `flutter_local_notifications` 的回调在插件层注册，而路由在 Widget 树里；
/// 这里用一个广播流把两者解耦：插件回调只负责 `emit`，由 App 根组件监听后
/// 交给 go_router 导航。
///
/// 用广播流而不是单个回调，是因为回调注册发生在插件 `initialize` 时（可能早于
/// 路由可用），而消费者可能在生命周期内反复挂载 / 卸载。
class NotificationTapBus {
  final StreamController<String> _controller =
      StreamController<String>.broadcast();

  Stream<String> get taps => _controller.stream;

  void emit(String payload) {
    if (_controller.isClosed) {
      return;
    }
    _controller.add(payload);
  }

  void close() {
    unawaited(_controller.close());
  }
}
