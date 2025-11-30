import { usePermission } from '@/composables/usePermission';
// directives/permission.ts
import type { Directive, DirectiveBinding } from 'vue';

/**
 * 权限控制指令
 * 用法：
 * v-permission="'transaction:add'" - 检查单个权限
 * v-permission="['transaction:add', 'transaction:edit']" - 检查多个权限（OR关系）
 * v-permission:and="['transaction:add', 'transaction:edit']" - 检查多个权限（AND关系）
 * v-permission:role="'Admin'" - 检查角色
 */
export const vPermission: Directive = {
  mounted(el: HTMLElement, binding: DirectiveBinding) {
    checkPermission(el, binding);
  },
  updated(el: HTMLElement, binding: DirectiveBinding) {
    checkPermission(el, binding);
  },
};

function checkPermission(el: HTMLElement, binding: DirectiveBinding) {
  const { hasPermission, currentRole } = usePermission();
  const { value, arg, modifiers } = binding;

  let hasAccess = false;

  try {
    if (arg === 'role') {
      // 角色检查
      if (typeof value === 'string') {
        hasAccess = currentRole.value === value;
      } else if (Array.isArray(value)) {
        hasAccess = value.includes(currentRole.value);
      }
    } else {
      // 权限检查
      if (typeof value === 'string') {
        hasAccess = hasPermission(value);
      } else if (Array.isArray(value)) {
        if (modifiers.and) {
          // AND关系：所有权限都必须有
          hasAccess = value.every(permission => hasPermission(permission));
        } else {
          // OR关系：至少有一个权限
          hasAccess = value.some(permission => hasPermission(permission));
        }
      }
    }

    // 根据权限结果显示或隐藏元素
    if (!hasAccess) {
      // 保存原始display样式
      if (!el.dataset.originalDisplay) {
        el.dataset.originalDisplay = el.style.display || '';
      }
      el.style.display = 'none';
    } else {
      // 恢复原始display样式
      const originalDisplay = el.dataset.originalDisplay || '';
      el.style.display = originalDisplay;
    }
  } catch (error) {
    console.error('Permission directive error:', error);
    // 出错时隐藏元素，保证安全
    el.style.display = 'none';
  }
}

/**
 * 权限检查函数，用于在JavaScript中检查权限
 */
export function checkElementPermission(
  permission: string | string[],
  options?: {
    mode?: 'and' | 'or';
    role?: string | string[];
  },
): boolean {
  const { hasPermission, currentRole } = usePermission();

  if (options?.role) {
    if (typeof options.role === 'string') {
      return currentRole.value === options.role;
    } else if (Array.isArray(options.role)) {
      return options.role.includes(currentRole.value || '');
    }
  }

  if (typeof permission === 'string') {
    return hasPermission(permission);
  } else if (Array.isArray(permission)) {
    if (options?.mode === 'and') {
      return permission.every(p => hasPermission(p));
    } else {
      return permission.some(p => hasPermission(p));
    }
  }

  return false;
}
