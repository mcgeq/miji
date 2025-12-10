// directives/permission.ts
import type { Directive, DirectiveBinding } from 'vue';
import { usePermission } from '@/composables/usePermission';

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

/**
 * 检查角色权限
 */
function checkRoleAccess(value: unknown, currentRole: string | null): boolean {
  if (typeof value === 'string') {
    return currentRole === value;
  }
  if (Array.isArray(value)) {
    return value.includes(currentRole);
  }
  return false;
}

/**
 * 检查功能权限
 */
function checkPermissionAccess(
  value: unknown,
  hasPermission: (permission: string) => boolean,
  useAndMode: boolean,
): boolean {
  if (typeof value === 'string') {
    return hasPermission(value);
  }
  if (Array.isArray(value)) {
    return useAndMode
      ? value.every(permission => hasPermission(permission))
      : value.some(permission => hasPermission(permission));
  }
  return false;
}

/**
 * 设置元素显示状态
 */
function setElementVisibility(el: HTMLElement, hasAccess: boolean): void {
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
}

function checkPermission(el: HTMLElement, binding: DirectiveBinding) {
  const { hasPermission, currentRole } = usePermission();
  const { value, arg, modifiers } = binding;

  try {
    const hasAccess =
      arg === 'role'
        ? checkRoleAccess(value, currentRole.value)
        : checkPermissionAccess(value, hasPermission, !!modifiers.and);

    setElementVisibility(el, hasAccess);
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
    }
    if (Array.isArray(options.role)) {
      return options.role.includes(currentRole.value || '');
    }
  }

  if (typeof permission === 'string') {
    return hasPermission(permission);
  }
  if (Array.isArray(permission)) {
    if (options?.mode === 'and') {
      return permission.every(p => hasPermission(p));
    }
    return permission.some(p => hasPermission(p));
  }

  return false;
}
