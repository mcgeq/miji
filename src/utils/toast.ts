// -----------------------------------------------------------------------------
//    Copyright (C) 2025 mcge. All rights reserved.
// Author:         mcge
// Email:          <mcgeq@outlook.com>
// File:           toast.ts
// Description:    About Custom Toast
// Create   Date:  2025-06-28 13:50:28
// Last Modified:  2025-06-28 15:55:19
// Modified   By:  mcgeq <mcgeq@outlook.com>
// -----------------------------------------------------------------------------

// src/utils/toast.ts
import { useToast } from 'vue-toastification';

const toastInstance = useToast();

const baseClasses = (color: string) => ({
  toastClassName: [
    `bg-${color}-500/90 text-white rounded-lg shadow border border-${color}-300/30`,
    'p-4 flex items-center gap-2 animate__animated animate__fadeInRight',
  ].join(' '),

  bodyClassName: 'text-sm',
  titleClassName: 'font-semibold text-white',
  // you can define more if needed
});

export const toast = {
  success: (msg: string) =>
    toastInstance.success(msg, {
      timeout: 3000,
      hideProgressBar: false,
      draggable: true,
      ...baseClasses('green'),
    }),

  error: (msg: string) =>
    toastInstance.error(msg, {
      timeout: 4000,
      hideProgressBar: false,
      draggable: true,
      ...baseClasses('red'),
    }),

  info: (msg: string) =>
    toastInstance.info(msg, {
      timeout: 3000,
      hideProgressBar: false,
      draggable: true,
      ...baseClasses('blue'),
    }),

  warning: (msg: string) =>
    toastInstance.warning(msg, {
      timeout: 3500,
      hideProgressBar: false,
      draggable: true,
      ...baseClasses('yellow'),
    }),
};
