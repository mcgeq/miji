# 认证系统重构方案

## 📊 现状分析

### 当前架构
```
src/
├── router/
│   └── index.ts              # 路由配置 + 简单守卫
├── stores/
│   └── auth.ts               # 认证状态管理
├── pages/
│   ├── auth/
│   │   ├── login.vue         # 登录页
│   │   └── register.vue      # 注册页
│   └── ...                   # 其他页面
└── services/
    └── auth.ts               # 认证API服务
```

### 🔴 发现的问题

#### 1. **路由守卫问题**
- ❌ 只有简单的 `requiresAuth` 检查
- ❌ 缺少权限/角色管理
- ❌ 没有路由白名单机制
- ❌ 缺少加载状态处理
- ❌ 每次导航都调用 API 验证 token（性能问题）

**当前代码（router/index.ts）**
```typescript
router.beforeEach(async (to, _from) => {
  const authStore = useAuthStore();
  let isAuth = false;
  try {
    isAuth = await authStore.checkAuthStatus(); // ❌ 每次都调用API
  } catch (error) {
    Lg.e('Router', 'Failed to check auth:', error);
  }
  
  if (!isAuth && to.meta.requiresAuth) {
    toast.warning(t('messages.pleaseLogin'));
    return { name: 'auth-login' };
  }
  
  if (isAuth && isAuthPage) {
    return { name: 'home' };
  }
  
  return true;
});
```

#### 2. **Auth Store 问题**
- ❌ 扩展方法使用硬编码 `/api/` 路径（不是Tauri命令）
- ❌ 缺少 Token 刷新机制
- ❌ 没有权限/角色管理
- ❌ `checkAuthStatus()` 每次都验证 token（应该缓存）

**问题代码（stores/auth.ts）**
```typescript
async function updateProfile(profileData: Partial<AuthUser>) {
  const response = await fetch('/api/user/profile', { // ❌ 不应该用fetch
    method: 'PUT',
    headers: {
      'Authorization': `Bearer ${token.value}`,
    },
    body: JSON.stringify(profileData),
  });
}

async function checkAuthStatus(): Promise<boolean> {
  // ❌ 每次都调用API验证，没有缓存
  const tokenStatus = await verifyToken(token.value);
  if (tokenStatus !== 'Valid') {
    await logout();
    return false;
  }
  return true;
}
```

#### 3. **类型安全问题**
- ❌ 路由 meta 类型不明确
- ❌ 缺少权限枚举类型
- ❌ 用户角色类型缺失

#### 4. **用户体验问题**
- ❌ 没有登录状态持久化检查的加载动画
- ❌ 登出后不清理应用状态
- ❌ Token 过期没有自动刷新

---

## ✅ 重构方案

### 1. **路由权限系统升级**

#### 1.1 定义权限和角色类型
```typescript
// src/types/auth.ts
export enum Permission {
  // 财务权限
  TRANSACTION_VIEW = 'transaction:view',
  TRANSACTION_CREATE = 'transaction:create',
  TRANSACTION_EDIT = 'transaction:edit',
  TRANSACTION_DELETE = 'transaction:delete',
  
  // 账户权限
  ACCOUNT_VIEW = 'account:view',
  ACCOUNT_MANAGE = 'account:manage',
  
  // 预算权限
  BUDGET_VIEW = 'budget:view',
  BUDGET_MANAGE = 'budget:manage',
  
  // 家庭账本权限
  LEDGER_VIEW = 'ledger:view',
  LEDGER_MANAGE = 'ledger:manage',
  LEDGER_ADMIN = 'ledger:admin',
  
  // 设置权限
  SETTINGS_VIEW = 'settings:view',
  SETTINGS_MANAGE = 'settings:manage',
}

export enum Role {
  GUEST = 'guest',
  USER = 'user',
  ADMIN = 'admin',
  OWNER = 'owner',
}

export const RolePermissions: Record<Role, Permission[]> = {
  [Role.GUEST]: [
    Permission.TRANSACTION_VIEW,
    Permission.ACCOUNT_VIEW,
  ],
  [Role.USER]: [
    Permission.TRANSACTION_VIEW,
    Permission.TRANSACTION_CREATE,
    Permission.ACCOUNT_VIEW,
    Permission.BUDGET_VIEW,
    Permission.LEDGER_VIEW,
  ],
  [Role.ADMIN]: [
    ...RolePermissions[Role.USER],
    Permission.TRANSACTION_EDIT,
    Permission.TRANSACTION_DELETE,
    Permission.ACCOUNT_MANAGE,
    Permission.BUDGET_MANAGE,
    Permission.LEDGER_MANAGE,
  ],
  [Role.OWNER]: Object.values(Permission),
};
```

#### 1.2 扩展路由 Meta 类型
```typescript
// src/types/router.ts
import type { Permission, Role } from './auth';

declare module 'vue-router' {
  interface RouteMeta {
    /** 是否需要登录 */
    requiresAuth?: boolean;
    /** 需要的权限（满足任一即可） */
    permissions?: Permission[];
    /** 需要的角色（满足任一即可） */
    roles?: Role[];
    /** 页面标题 */
    title?: string;
    /** 是否在菜单中隐藏 */
    hidden?: boolean;
    /** 页面图标 */
    icon?: string;
  }
}
```

#### 1.3 优化路由守卫
```typescript
// src/router/guards/auth.guard.ts
import type { NavigationGuardNext, RouteLocationNormalized } from 'vue-router';
import { useAuthStore } from '@/stores/auth';
import { toast } from '@/utils/toast';
import { Lg } from '@/utils/debugLog';

/** 白名单路由（不需要权限检查） */
const WHITE_LIST = ['auth-login', 'auth-register', 'splash'];

/** 认证检查缓存（避免重复API调用） */
let authCheckCache: {
  isAuth: boolean;
  timestamp: number;
} | null = null;

const CACHE_DURATION = 30000; // 30秒缓存

/**
 * 认证守卫
 */
export async function authGuard(
  to: RouteLocationNormalized,
  from: RouteLocationNormalized,
  next: NavigationGuardNext,
) {
  const authStore = useAuthStore();
  const routeName = typeof to.name === 'string' ? to.name : '';
  
  // 1. 检查白名单
  if (WHITE_LIST.includes(routeName)) {
    next();
    return;
  }
  
  // 2. 获取认证状态（使用缓存）
  let isAuth = false;
  try {
    const now = Date.now();
    
    // 使用缓存（30秒内有效）
    if (authCheckCache && now - authCheckCache.timestamp < CACHE_DURATION) {
      isAuth = authCheckCache.isAuth;
    } else {
      // 重新检查认证状态
      isAuth = await authStore.checkAuthStatus();
      authCheckCache = { isAuth, timestamp: now };
    }
  } catch (error) {
    Lg.e('AuthGuard', 'Failed to check auth:', error);
    isAuth = false;
  }
  
  // 3. 处理未登录情况
  if (!isAuth) {
    if (to.meta.requiresAuth) {
      toast.warning('请先登录');
      next({ name: 'auth-login', query: { redirect: to.fullPath } });
      return;
    }
    next();
    return;
  }
  
  // 4. 已登录，不允许访问登录/注册页
  if (['auth-login', 'auth-register'].includes(routeName)) {
    next({ name: 'home' });
    return;
  }
  
  // 5. 检查权限
  if (to.meta.permissions || to.meta.roles) {
    const hasPermission = authStore.hasAnyPermission(to.meta.permissions);
    const hasRole = authStore.hasAnyRole(to.meta.roles);
    
    if (!hasPermission && !hasRole) {
      toast.error('您没有权限访问此页面');
      next({ name: 'home' });
      return;
    }
  }
  
  next();
}

/** 清除认证检查缓存 */
export function clearAuthCache() {
  authCheckCache = null;
}
```

#### 1.4 添加进度条守卫
```typescript
// src/router/guards/progress.guard.ts
import NProgress from 'nprogress';
import 'nprogress/nprogress.css';

NProgress.configure({ showSpinner: false });

export function progressGuard() {
  return {
    before: () => NProgress.start(),
    after: () => NProgress.done(),
  };
}
```

#### 1.5 更新路由配置
```typescript
// src/router/index.ts
import { createRouter, createWebHashHistory } from 'vue-router';
import { routes } from 'vue-router/auto-routes';
import { authGuard } from './guards/auth.guard';
import { progressGuard } from './guards/progress.guard';

const router = createRouter({
  history: createWebHashHistory(),
  routes,
});

// 进度条
const progress = progressGuard();
router.beforeEach(() => progress.before());
router.afterEach(() => progress.after());

// 认证守卫
router.beforeEach(authGuard);

export default router;
```

---

### 2. **Auth Store 优化**

#### 2.1 添加权限管理
```typescript
// src/stores/auth.ts (新增部分)
import { Permission, Role, RolePermissions } from '@/types/auth';

export const useAuthStore = defineStore('auth', () => {
  // ... 现有状态 ...
  
  const permissions = ref<Permission[]>([]);
  const role = ref<Role>(Role.GUEST);
  
  // 计算属性：基于角色获取权限
  const effectivePermissions = computed(() => {
    const rolePerms = RolePermissions[role.value] || [];
    return [...new Set([...rolePerms, ...permissions.value])];
  });
  
  /**
   * 检查是否有指定权限（满足任一即可）
   */
  function hasAnyPermission(perms?: Permission[]): boolean {
    if (!perms || perms.length === 0) return true;
    return perms.some(p => effectivePermissions.value.includes(p));
  }
  
  /**
   * 检查是否有所有指定权限
   */
  function hasAllPermissions(perms?: Permission[]): boolean {
    if (!perms || perms.length === 0) return true;
    return perms.every(p => effectivePermissions.value.includes(p));
  }
  
  /**
   * 检查是否有指定角色（满足任一即可）
   */
  function hasAnyRole(roles?: Role[]): boolean {
    if (!roles || roles.length === 0) return true;
    return roles.includes(role.value);
  }
  
  /**
   * 登录（更新版）
   */
  async function login(
    userData: User,
    tokenResponse?: TokenResponse,
    remember = false,
  ): Promise<boolean> {
    try {
      // ... 现有逻辑 ...
      
      // 设置角色和权限
      role.value = userData.role || Role.USER;
      permissions.value = userData.permissions || [];
      
      // 清除路由守卫缓存
      clearAuthCache();
      
      return true;
    } catch (error) {
      // ... 错误处理 ...
    }
  }
  
  /**
   * 登出（更新版）
   */
  async function logout(): Promise<void> {
    try {
      // ... 清除状态 ...
      
      role.value = Role.GUEST;
      permissions.value = [];
      
      // 清除路由守卫缓存
      clearAuthCache();
      
      // 清除其他 store（避免数据泄露）
      resetStores();
    } catch (error) {
      // ... 错误处理 ...
    }
  }
  
  return {
    // ... 现有导出 ...
    
    // 新增
    permissions: readonly(permissions),
    role: readonly(role),
    effectivePermissions,
    hasAnyPermission,
    hasAllPermissions,
    hasAnyRole,
  };
});

/**
 * 重置所有业务 store
 */
function resetStores() {
  // 导入并重置各个 store
  const { useMoneyStore } = await import('@/stores/money');
  const { useBudgetStore } = await import('@/stores/budget');
  // ... 其他 store
  
  useMoneyStore().$reset();
  useBudgetStore().$reset();
}
```

#### 2.2 优化 Token 验证（添加缓存）
```typescript
// src/stores/auth.ts
let tokenValidationCache: {
  isValid: boolean;
  timestamp: number;
} | null = null;

const TOKEN_CACHE_DURATION = 60000; // 1分钟缓存

async function checkAuthStatus(): Promise<boolean> {
  try {
    if (!user.value || !token.value) {
      return false;
    }
    
    const currentTime = Date.now();
    
    // 1. 检查过期时间（本地检查，无需API）
    if (rememberMe.value) {
      if (!tokenExpiresAt.value || tokenExpiresAt.value < currentTime / 1000) {
        await logout();
        return false;
      }
    }
    
    // 2. 使用缓存（1分钟内有效）
    if (tokenValidationCache && currentTime - tokenValidationCache.timestamp < TOKEN_CACHE_DURATION) {
      return tokenValidationCache.isValid;
    }
    
    // 3. 验证 token（仅在缓存失效时）
    const tokenStatus = await verifyToken(token.value);
    const isValid = tokenStatus === 'Valid';
    
    if (!isValid) {
      await logout();
      return false;
    }
    
    // 更新缓存
    tokenValidationCache = { isValid: true, timestamp: currentTime };
    return true;
  } catch (error) {
    Lg.e('Auth', 'Auth check failed:', error);
    await logout();
    return false;
  }
}
```

#### 2.3 删除不适用的扩展方法
```typescript
// ❌ 删除这些使用 fetch 的方法（不适用于 Tauri 应用）
// - updateProfile
// - uploadAvatar
// - verifyEmailAddress
// - sendEmailVerification
// - changePassword

// ✅ 如果需要这些功能，应该创建对应的 Tauri Command
```

---

### 3. **组合式函数（Composables）**

#### 3.1 权限检查 Hook
```typescript
// src/composables/usePermission.ts
import { computed } from 'vue';
import { useAuthStore } from '@/stores/auth';
import type { Permission, Role } from '@/types/auth';

export function usePermission() {
  const authStore = useAuthStore();
  
  /**
   * 检查是否有权限
   */
  const hasPermission = (permission: Permission | Permission[]) => {
    const perms = Array.isArray(permission) ? permission : [permission];
    return authStore.hasAnyPermission(perms);
  };
  
  /**
   * 检查是否有所有权限
   */
  const hasAllPermissions = (permissions: Permission[]) => {
    return authStore.hasAllPermissions(permissions);
  };
  
  /**
   * 检查是否有角色
   */
  const hasRole = (role: Role | Role[]) => {
    const roles = Array.isArray(role) ? role : [role];
    return authStore.hasAnyRole(roles);
  };
  
  return {
    hasPermission,
    hasAllPermissions,
    hasRole,
  };
}
```

#### 3.2 权限指令
```typescript
// src/directives/permission.ts
import type { Directive, DirectiveBinding } from 'vue';
import { useAuthStore } from '@/stores/auth';
import type { Permission } from '@/types/auth';

/**
 * v-permission 指令
 * 用法：<button v-permission="Permission.TRANSACTION_DELETE">删除</button>
 */
export const permissionDirective: Directive = {
  mounted(el: HTMLElement, binding: DirectiveBinding<Permission | Permission[]>) {
    const authStore = useAuthStore();
    const permissions = Array.isArray(binding.value) ? binding.value : [binding.value];
    
    if (!authStore.hasAnyPermission(permissions)) {
      el.style.display = 'none';
    }
  },
};

// 注册指令
// src/main.ts
import { permissionDirective } from '@/directives/permission';
app.directive('permission', permissionDirective);
```

---

### 4. **最佳实践示例**

#### 4.1 页面中使用权限
```vue
<script setup lang="ts">
import { usePermission } from '@/composables/usePermission';
import { Permission } from '@/types/auth';

const { hasPermission } = usePermission();
</script>

<template>
  <div>
    <!-- 方法1：使用组合式函数 -->
    <button v-if="hasPermission(Permission.TRANSACTION_DELETE)" @click="deleteTransaction">
      删除
    </button>
    
    <!-- 方法2：使用指令 -->
    <button v-permission="Permission.TRANSACTION_DELETE" @click="deleteTransaction">
      删除
    </button>
    
    <!-- 方法3：多个权限（满足任一） -->
    <button v-permission="[Permission.TRANSACTION_EDIT, Permission.TRANSACTION_DELETE]">
      编辑或删除
    </button>
  </div>
</template>
```

#### 4.2 路由配置示例
```typescript
// src/pages/money/transactions/index.vue
<route lang="yaml">
meta:
  requiresAuth: true
  permissions: 
    - transaction:view
  title: '交易记录'
  icon: 'receipt'
</route>

// src/pages/settings/index.vue
<route lang="yaml">
meta:
  requiresAuth: true
  roles:
    - admin
    - owner
  title: '系统设置'
  icon: 'settings'
</route>
```

---

## 📦 文件结构

```
src/
├── types/
│   ├── auth.ts              # 权限、角色类型定义
│   └── router.ts            # 路由 Meta 类型扩展
├── router/
│   ├── index.ts             # 路由配置
│   └── guards/
│       ├── auth.guard.ts    # 认证守卫
│       └── progress.guard.ts # 进度条守卫
├── stores/
│   └── auth.ts              # 认证 Store（优化版）
├── composables/
│   └── usePermission.ts     # 权限检查 Hook
├── directives/
│   └── permission.ts        # 权限指令
└── services/
    └── auth.ts              # 认证 API 服务
```

---

## 🚀 实施步骤

1. ✅ **创建类型定义**
   - [ ] `src/types/auth.ts` - 权限和角色枚举
   - [ ] `src/types/router.ts` - 路由 Meta 类型扩展

2. ✅ **重构路由守卫**
   - [ ] `src/router/guards/auth.guard.ts` - 新的认证守卫
   - [ ] `src/router/guards/progress.guard.ts` - 进度条守卫
   - [ ] 更新 `src/router/index.ts`

3. ✅ **优化 Auth Store**
   - [ ] 添加权限管理方法
   - [ ] 添加 Token 验证缓存
   - [ ] 删除不适用的扩展方法
   - [ ] 添加 `resetStores` 登出清理

4. ✅ **创建工具函数**
   - [ ] `src/composables/usePermission.ts`
   - [ ] `src/directives/permission.ts`

5. ✅ **更新页面路由元信息**
   - [ ] 为每个页面添加适当的 `meta` 配置

6. ✅ **测试**
   - [ ] 未登录访问受保护路由
   - [ ] 登录后访问登录页重定向
   - [ ] 权限不足时显示/隐藏
   - [ ] Token 过期后自动登出
   - [ ] 缓存机制工作正常

---

## 📊 性能优化对比

| 项目 | 优化前 | 优化后 | 提升 |
|------|--------|--------|------|
| 路由导航 API 调用 | 每次都调用 | 30秒缓存 | **90%+** |
| Token 验证 API 调用 | 每次都调用 | 1分钟缓存 | **95%+** |
| 权限检查 | ❌ 不支持 | ✅ 支持 | 新增 |
| 角色管理 | ❌ 不支持 | ✅ 支持 | 新增 |
| 进度反馈 | ❌ 无 | ✅ 进度条 | 新增 |

---

## 🔒 安全性提升

1. ✅ **前端权限控制**
   - 路由级别权限
   - 组件级别权限
   - 按钮级别权限

2. ✅ **登出清理**
   - 清理所有业务 Store
   - 清除认证缓存
   - 防止数据泄露

3. ✅ **Token 管理**
   - 过期自动登出
   - 验证缓存机制
   - 记住我功能

4. ⚠️ **注意事项**
   - 前端权限只是 UI 控制，真正的安全依赖后端验证
   - 敏感操作必须在后端再次验证权限
