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

function baseClasses(color: string) {
  return {
    toastClassName: [
      `bg-${color}-500/90 text-white rounded-lg shadow border border-${color}-300/30`,
      'p-4 flex items-center gap-2 animate__animated animate__fadeInRight pointer-events-auto',
    ].join(' '),

    bodyClassName: 'text-sm',
    titleClassName: 'font-semibold text-white',
    // 提升层级到最高，确保在所有 modal 之上（Modal 最高 z-index: 999999）
    containerClassName: '!z-[99999999] pointer-events-none',
  };
}

export const toast = {
  success: (msg: string) =>
    toastInstance.success(msg, {
      timeout: 2000,
      hideProgressBar: false,
      draggable: true,
      ...baseClasses('green'),
    }),

  error: (msg: string) =>
    toastInstance.error(msg, {
      timeout: 3000,
      hideProgressBar: false,
      draggable: true,
      ...baseClasses('red'),
    }),

  info: (msg: string) =>
    toastInstance.info(msg, {
      timeout: 2000,
      hideProgressBar: false,
      draggable: true,
      ...baseClasses('blue'),
    }),

  warning: (msg: string) =>
    toastInstance.warning(msg, {
      timeout: 2500,
      hideProgressBar: false,
      draggable: true,
      ...baseClasses('yellow'),
    }),
};
