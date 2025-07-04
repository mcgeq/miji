// -----------------------------------------------------------------------------
//    Copyright (C) 2025 mcge. All rights reserved.
// Author:         mcge
// Email:          <mcgeq@outlook.com>
// File:           transition.ts
// Description:    About Transition
// Create   Date:  2025-06-29 12:30:48
// Last Modified:  2025-06-29 12:35:28
// Modified   By:  mcgeq <mcgeq@outlook.com>
// -----------------------------------------------------------------------------

import { defineStore } from 'pinia';

export const useTransitionsStore = defineStore('transition', {
  state: () => ({
    name: 'fade' as 'fade' | 'slide-left' | 'slide-right',
  }),
  actions: {
    setTransition(name: 'fade' | 'slide-left' | 'slide-right') {
      this.name = name;
    },
  },
});
