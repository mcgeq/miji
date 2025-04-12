// -----------------------------------------------------------------------------
//    Copyright (C) 2025 mcge. All rights reserved.
// Author:         mcge
// Email:          <mcgeq@outlook.com>
// File:           todo_page_provider.dart
// Description:    About page
// Create   Date:  2025-04-12 10:53:02
// Last Modified:  2025-04-12 10:53:08
// Modified   By:  mcgeq <mcgeq@outlook.com>
// -----------------------------------------------------------------------------
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'todo_page_provider.g.dart';

// Using a simple provider for the page state
@riverpod
class TodoPage extends _$TodoPage {
  @override
  int build() {
    return 1; // Default page
  }

  void setPage(int newPage) {
    state = newPage;
  }

  void nextPage(int totalPages) {
    if (state < totalPages) {
      state++;
    }
  }

  void previousPage() {
    if (state > 1) {
      state--;
    }
  }

  void firstPage() {
    state = 1;
  }

  void lastPage(int totalPages) {
    state = totalPages;
  }
}
