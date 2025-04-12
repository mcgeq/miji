// -----------------------------------------------------------------------------
//    Copyright (C) 2025 mcge. All rights reserved.
// Author:         mcge
// Email:          <mcgeq@outlook.com>
// File:           todo_filter_provider.dart
// Description:    About filter
// Create   Date:  2025-04-12 10:53:19
// Last Modified:  2025-04-12 10:53:26
// Modified   By:  mcgeq <mcgeq@outlook.com>
// -----------------------------------------------------------------------------
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'todo_filter_provider.g.dart';

// Using a simple provider for the filter state
@riverpod
class TodoFilter extends _$TodoFilter {
  @override
  String build() {
    return '今'; // Default filter
  }

  void setFilter(String newFilter) {
    state = newFilter;
  }
}
