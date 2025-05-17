import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';

/// 状态类，包含当前时间
class ClockState {
  final DateTime dateTime;
  const ClockState(this.dateTime);
}

/// BLoC：每秒更新一次状态
class ClockBloc extends Cubit<ClockState> {
  late final Timer _timer;

  ClockBloc() : super(ClockState(DateTime.now())) {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      emit(ClockState(DateTime.now()));
    });
  }

  @override
  Future<void> close() {
    _timer.cancel();
    return super.close();
  }
}