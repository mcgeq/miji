import { useAuthStore } from '@/stores/auth';
import type { Permission, Role } from '@/types/auth';
/**
 * 认证权限指令
 * 基于 RBAC 的权限控制指令
 *
 * 用法：
 * v-auth-permission="Permission.TRANSACTION_DELETE" - 单个权限
 * v-auth-permission="[Permission.TRANSACTION_EDIT, Permission.TRANSACTION_DELETE]" - 多个权限（OR）
 * v-auth-permission.all="[Permission.TRANSACTION_EDIT, Permission.TRANSACTION_DELETE]" - 多个权限（AND）
 * v-auth-role="Role.ADMIN" - 角色检查
 * v-auth-role="[Role.ADMIN, Role.OWNER]" - 多角色检查（OR）
 */
import type { Directive, DirectiveBinding } from 'vue';

/**
 * 权限指令
 */
export const vAuthPermission: Directive = {
  mounted(el: HTMLElement, binding: DirectiveBinding<Permission | Permission[]>) {
    checkPermission(el, binding);
  },
  updated(el: HTMLElement, binding: DirectiveBinding<Permission | Permission[]>) {
    checkPermission(el, binding);
  },
};

/**
 * 角色指令
 */
export const vAuthRole: Directive = {
  mounted(el: HTMLElement, binding: DirectiveBinding<Role | Role[]>) {
    checkRole(el, binding);
  },
  updated(el: HTMLElement, binding: DirectiveBinding<Role | Role[]>) {
    checkRole(el, binding);
  },
};

/**
 * 检查权限
 */
function checkPermission(el: HTMLElement, binding: DirectiveBinding<Permission | Permission[]>) {
  const authStore = useAuthStore();
  const { value, modifiers } = binding;

  let hasAccess = false;

  try {
    if (Array.isArray(value)) {
      // 多个权限
      if (modifiers.all) {
        // AND 关系：必须有所有权限
        hasAccess = authStore.hasAllPermissions(value);
      } else {
        // OR 关系：至少有一个权限
        hasAccess = authStore.hasAnyPermission(value);
      }
    } else {
      // 单个权限
      hasAccess = authStore.hasPermission(value);
    }

    // 根据权限结果显示或隐藏元素
    toggleElement(el, hasAccess);
  } catch (error) {
    console.error('Auth permission directive error:', error);
    // 出错时隐藏元素，保证安全
    el.style.display = 'none';
  }
}

/**
 * 检查角色
 */
function checkRole(el: HTMLElement, binding: DirectiveBinding<Role | Role[]>) {
  const authStore = useAuthStore();
  const { value } = binding;

  let hasAccess = false;

  try {
    if (Array.isArray(value)) {
      // 多个角色（OR 关系）
      hasAccess = authStore.hasAnyRole(value);
    } else {
      // 单个角色
      hasAccess = authStore.hasAnyRole([value]);
    }

    // 根据角色结果显示或隐藏元素
    toggleElement(el, hasAccess);
  } catch (error) {
    console.error('Auth role directive error:', error);
    // 出错时隐藏元素，保证安全
    el.style.display = 'none';
  }
}

/**
 * 切换元素显示/隐藏
 */
function toggleElement(el: HTMLElement, show: boolean) {
  if (!show) {
    // 保存原始display样式（第一次时）
    if (!el.dataset.originalDisplay) {
      el.dataset.originalDisplay = el.style.display || '';
    }
    el.style.display = 'none';
  } else {
    // 恢复原始display样式
    const originalDisplay = el.dataset.originalDisplay || '';
    el.style.display = originalDisplay;
    // 清除保存的样式
    if (el.dataset.originalDisplay) {
      delete el.dataset.originalDisplay;
    }
  }
}

/**
 * 默认导出（用于 v-permission）
 */
export default vAuthPermission;
