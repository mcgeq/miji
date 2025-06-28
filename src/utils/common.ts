// -----------------------------------------------------------------------------
//    Copyright (C) 2025 mcge. All rights reserved.
// Author:         mcge
// Email:          <mcgeq@outlook.com>
// File:           common.ts
// Description:    About Common
// Create   Date:  2025-06-22 20:39:52
// Last Modified:  2025-06-22 23:07:50
// Modified   By:  mcgeq <mcgeq@outlook.com>
// -----------------------------------------------------------------------------

export function toCamelCase<T = any>(obj: any): T {
  if (Array.isArray(obj)) {
    return obj.map(toCamelCase) as any;
  } else if (obj !== null && typeof obj === 'object') {
    const newObj: Record<string, any> = {};
    for (const [key, value] of Object.entries(obj)) {
      const camelKey = key.replace(/_([a-z])/g, (_, char) =>
        char.toUpperCase(),
      );
      newObj[camelKey] = toCamelCase(value);
    }
    return newObj as T;
  }
  return obj;
}

export const toSnakeCase = (str: string): string =>
  str.replace(/[A-Z]/g, (letter) => `_${letter.toLowerCase()}`);
