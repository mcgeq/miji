import 'package:flutter/foundation.dart';

class CounterController {
  final ValueNotifier<int> counter = ValueNotifier(0);

  void increment() => counter.value++;
}
