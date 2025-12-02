# 认证系统高级功能使用指南

> 本文档介绍认证系统的高级功能和最佳实践

---

## 📋 目录

1. [组件级权限守卫](#组件级权限守卫)
2. [Token自动刷新](#token自动刷新)
3. [权限审计日志](#权限审计日志)
4. [应用启动权限修复](#应用启动权限修复)
5. [最佳实践](#最佳实践)

---

## 1. 组件级权限守卫

### 基础用法

```vue
<script setup lang="ts">
import { useAuthGuard } from '@/composables/useAuthGuard';
import { Permission } from '@/types/auth';

const { hasAccess, checkAccess, requireAccess } = useAuthGuard({
  permissions: [Permission.TRANSACTION_DELETE],
  showToast: true,
});
</script>

<template>
  <!-- 响应式显示/隐藏 -->
  <button v-if="hasAccess" @click="deleteTransaction">
    删除交易
  </button>
</template>
```

### 高级用法

#### 1. 操作前检查权限

```typescript
import { useAuthGuard } from '@/composables/useAuthGuard';
import { Permission } from '@/types/auth';

const { checkAccess } = useAuthGuard({
  permissions: [Permission.TRANSACTION_DELETE],
  showToast: true,
  onDenied: () => {
    // 权限不足时的回调
    console.log('用户无权限删除');
  },
});

function handleDelete() {
  // 检查权限
  if (!checkAccess()) {
    return; // 权限不足，已显示提示
  }
  
  // 执行删除操作
  deleteTransaction();
}
```

#### 2. 要求权限（失败则跳转）

```typescript
import { useAuthGuard } from '@/composables/useAuthGuard';
import { Permission } from '@/types/auth';

const { requireAccess } = useAuthGuard({
  permissions: [Permission.MEMBER_MANAGE],
  redirectTo: '/home',
});

onMounted(() => {
  // 页面加载时要求权限，失败则跳转
  requireAccess();
});
```

#### 3. 多权限检查

```typescript
// OR逻辑：拥有任一权限即可
const { hasAccess } = useAuthGuard({
  permissions: [
    Permission.TRANSACTION_EDIT,
    Permission.TRANSACTION_DELETE,
  ],
});

// AND逻辑：需要同时拥有多个权限
const { checkAccess: checkEditAccess } = useAuthGuard({
  permissions: [Permission.TRANSACTION_EDIT],
});
const { checkAccess: checkDeleteAccess } = useAuthGuard({
  permissions: [Permission.TRANSACTION_DELETE],
});

function handleAction() {
  if (checkEditAccess() && checkDeleteAccess()) {
    // 同时拥有编辑和删除权限
  }
}
```

#### 4. 角色检查

```typescript
import { useAuthGuard } from '@/composables/useAuthGuard';
import { Role } from '@/types/auth';

const { hasAccess } = useAuthGuard({
  roles: [Role.ADMIN, Role.OWNER],  // 仅管理员和所有者
});
```

### 快捷方法

```typescript
import { 
  requireAuth,
  requirePermission,
  requireRole,
} from '@/composables/useAuthGuard';
import { Permission, Role } from '@/types/auth';

// 1. 要求登录
if (!requireAuth()) {
  return; // 未登录，已跳转到登录页
}

// 2. 要求权限
if (!requirePermission(Permission.TRANSACTION_DELETE)) {
  return; // 无权限，已提示
}

// 3. 要求角色
if (!requireRole(Role.ADMIN)) {
  return; // 非管理员，已提示
}

// 执行操作
performAdminAction();
```

---

## 2. Token自动刷新

### 工作原理

```
用户登录 → Token有效期7天
    ↓
每次路由导航或API调用时检查Token
    ↓
Token剩余时间 < 5分钟？
    ├─ Yes → 自动刷新Token
    │        ├─ 成功：延长7天
    │        └─ 失败：继续使用旧Token
    └─ No → 继续
```

### 配置说明

```typescript
// src/stores/auth.ts

// Token过期前5分钟自动刷新
const timeUntilExpiry = tokenExpiresAt.value - currentTime;
if (timeUntilExpiry < 5 * 60) {  // 5分钟
  await refreshToken();
}
```

### 后端集成

后端需要提供刷新Token的API：

```typescript
// POST /api/auth/refresh
// Headers: Authorization: Bearer <current_token>
// Response: { token: string, expiresAt: number }

async function refreshToken(): Promise<void> {
  const response = await fetch('/api/auth/refresh', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${token.value}`,
    },
  });
  
  if (!response.ok) {
    throw new Error('Token refresh failed');
  }
  
  const { token: newToken, expiresAt } = await response.json();
  token.value = newToken;
  tokenExpiresAt.value = expiresAt;
}
```

### 手动刷新

```typescript
import { useAuthStore } from '@/stores/auth';

const authStore = useAuthStore();

// 手动刷新Token
try {
  await authStore.refreshToken();
  console.log('Token refreshed successfully');
} catch (error) {
  console.error('Token refresh failed:', error);
}
```

---

## 3. 权限审计日志

### 功能特性

- ✅ 自动记录登录/登出事件
- ✅ 记录所有权限检查（通过/拒绝）
- ✅ 记录角色变更
- ✅ 生成统计报告
- ✅ 导出日志为JSON

### 基础用法

```typescript
import { authAudit } from '@/utils/auth-audit';

// 查看所有日志
const logs = authAudit.getLogs();
console.log('Total logs:', logs.length);

// 查看特定用户的日志
const userLogs = authAudit.getUserLogs('user123');

// 查看被拒绝的权限
const deniedLogs = authAudit.getDeniedLogs();
console.log('Denied:', deniedLogs.length);
```

### 生成报告

```typescript
import { authAudit } from '@/utils/auth-audit';

const report = authAudit.generateReport();

console.log('统计报告:', {
  totalLogs: report.totalLogs,           // 总日志数
  loginCount: report.loginCount,         // 登录次数
  logoutCount: report.logoutCount,       // 登出次数
  deniedCount: report.deniedCount,       // 拒绝次数
  denialRate: report.denialRate,         // 拒绝率
  roleDistribution: report.roleDistribution, // 角色分布
  topDeniedPermissions: report.topDeniedPermissions, // 最常被拒绝的权限
});
```

### 导出日志

```typescript
import { authAudit } from '@/utils/auth-audit';

// 导出为JSON字符串
const json = authAudit.exportLogs();

// 保存到文件
const blob = new Blob([json], { type: 'application/json' });
const url = URL.createObjectURL(blob);
const a = document.createElement('a');
a.href = url;
a.download = `auth-audit-${Date.now()}.json`;
a.click();
```

### 时间范围查询

```typescript
import { authAudit } from '@/utils/auth-audit';

// 查询最近24小时的日志
const now = Date.now();
const oneDayAgo = now - 24 * 60 * 60 * 1000;
const recentLogs = authAudit.getLogsByTimeRange(oneDayAgo, now);

console.log('Recent logs:', recentLogs.length);
```

### 配置选项

```typescript
import { authAudit } from '@/utils/auth-audit';

// 启用/禁用审计日志
authAudit.setEnabled(true);

// 设置最大日志数量（默认1000）
authAudit.setMaxLogs(5000);

// 清空日志
authAudit.clearLogs();
```

---

## 4. 应用启动权限修复

### 工作原理

```typescript
// src/App.vue

onMounted(async () => {
  // 等待持久化数据加载
  await nextTick();
  
  // 权限修复：检测并修复零权限问题
  if (authStore.isAuthenticated && authStore.effectivePermissions.length === 0) {
    console.warn('检测到零权限，正在修复...');
    
    // 触发计算属性重新计算
    const perms = authStore.effectivePermissions;
    
    console.log('权限已修复:', {
      role: authStore.role,
      effectiveCount: perms.length,
    });
  }
});
```

### 触发场景

1. **应用重启后** - 持久化数据加载完成
2. **角色规范化失败** - 大小写不匹配
3. **Store迁移后** - 数据结构变更
4. **强制关闭后** - 数据不完整

### 日志输出

```
[App] Auth check - token: exists rememberMe: true
[App] ⚠️ Detected zero effective permissions for authenticated user, fixing...
[App] Permissions fixed: { role: 'user', effectiveCount: 13 }
```

---

## 5. 最佳实践

### 1. 组件中使用权限守卫

```vue
<script setup lang="ts">
import { useAuthGuard } from '@/composables/useAuthGuard';
import { Permission } from '@/types/auth';

// ✅ 推荐：使用 Composable
const { hasAccess: canDelete, checkAccess: canDeleteCheck } = useAuthGuard({
  permissions: [Permission.TRANSACTION_DELETE],
});

// ❌ 不推荐：直接使用 authStore
// const authStore = useAuthStore();
// const canDelete = computed(() => authStore.hasPermission(Permission.TRANSACTION_DELETE));
</script>

<template>
  <!-- 响应式显示/隐藏 -->
  <button v-if="canDelete" @click="handleDelete">
    删除
  </button>
  
  <!-- 或使用指令 -->
  <button v-auth-permission="Permission.TRANSACTION_DELETE" @click="handleDelete">
    删除
  </button>
</template>
```

### 2. API调用前检查权限

```typescript
import { requirePermission } from '@/composables/useAuthGuard';
import { Permission } from '@/types/auth';

async function deleteTransaction(id: string) {
  // ✅ 推荐：操作前检查权限
  if (!requirePermission(Permission.TRANSACTION_DELETE)) {
    return;
  }
  
  try {
    await api.deleteTransaction(id);
    toast.success('删除成功');
  } catch (error) {
    toast.error('删除失败');
  }
}
```

### 3. 页面加载时验证权限

```vue
<script setup lang="ts">
import { useAuthGuard } from '@/composables/useAuthGuard';
import { Permission } from '@/types/auth';

const { requireAccess } = useAuthGuard({
  permissions: [Permission.MEMBER_MANAGE],
  redirectTo: '/home',
});

onMounted(() => {
  // ✅ 推荐：页面加载时要求权限
  requireAccess();
});
</script>
```

### 4. 错误处理

```typescript
import { useAuthGuard } from '@/composables/useAuthGuard';
import { Permission } from '@/types/auth';

const { checkAccess } = useAuthGuard({
  permissions: [Permission.TRANSACTION_DELETE],
  showToast: true,  // ✅ 自动显示错误提示
  onDenied: () => {
    // ✅ 自定义错误处理
    console.log('权限不足，记录到日志');
    analytics.track('permission_denied', {
      permission: Permission.TRANSACTION_DELETE,
    });
  },
});
```

### 5. 定期查看审计日志

```typescript
import { authAudit } from '@/utils/auth-audit';

// 定期生成报告
setInterval(() => {
  const report = authAudit.generateReport();
  
  // 如果拒绝率过高，发送警告
  if (parseInt(report.denialRate) > 20) {
    console.warn('权限拒绝率过高:', report.denialRate);
    // 发送通知或记录到监控系统
  }
}, 60 * 60 * 1000);  // 每小时检查一次
```

---

## 6. 性能优化

### 1. 权限检查缓存

```typescript
// 路由守卫使用30秒缓存
const CACHE_DURATION = 30000;

if (authCheckCache && now - authCheckCache.timestamp < CACHE_DURATION) {
  isAuth = authCheckCache.isAuth;  // 使用缓存 ✅
}
```

### 2. 计算属性优化

```typescript
// ✅ 使用计算属性，自动缓存
const effectivePermissions = computed(() => {
  const rolePerms = RolePermissions[role.value] || [];
  return [...new Set([...rolePerms, ...permissions.value])];
});

// ❌ 避免在每次渲染时重新计算
function getEffectivePermissions() {
  // 每次调用都重新计算，性能差
}
```

### 3. 审计日志限制

```typescript
// 限制日志数量，避免内存泄漏
authAudit.setMaxLogs(1000);  // 最多保留1000条

// 在生产环境禁用详细日志
if (import.meta.env.PROD) {
  authAudit.setEnabled(false);
}
```

---

## 7. 故障排查

### 问题1：权限修复无效

**症状：** 应用启动后effectivePermissions仍为0

**解决：**
```typescript
// 1. 检查角色是否正确
console.log('Role:', authStore.role);  // 应该是'user'而不是'User'

// 2. 手动触发修复
if (authStore.effectivePermissions.length === 0) {
  // 强制重新计算
  authStore.role = authStore.role;  // 触发响应式更新
}

// 3. 检查RolePermissions
console.log('Role Permissions:', RolePermissions[authStore.role]);
```

### 问题2：Token刷新失败

**症状：** Token即将过期但没有自动刷新

**解决：**
```typescript
// 1. 检查后端API是否实现
// POST /api/auth/refresh

// 2. 检查Token过期时间
console.log('Token expires at:', new Date(authStore.tokenExpiresAt * 1000));

// 3. 手动刷新测试
await authStore.refreshToken();
```

### 问题3：审计日志过多

**症状：** 审计日志占用大量内存

**解决：**
```typescript
// 1. 限制日志数量
authAudit.setMaxLogs(500);

// 2. 定期清理旧日志
setInterval(() => {
  const sevenDaysAgo = Date.now() - 7 * 24 * 60 * 60 * 1000;
  const recentLogs = authAudit.getLogsByTimeRange(sevenDaysAgo, Date.now());
  authAudit.clearLogs();
  // 重新添加最近7天的日志
}, 24 * 60 * 60 * 1000);

// 3. 生产环境禁用
if (import.meta.env.PROD) {
  authAudit.setEnabled(false);
}
```

---

## 8. 总结

### 已实现功能

- ✅ 组件级权限守卫 (`useAuthGuard`)
- ✅ Token自动刷新（5分钟内过期）
- ✅ 权限审计日志系统
- ✅ 应用启动权限修复
- ✅ 改进的错误处理

### 使用建议

1. **优先使用Composable** - 而不是直接访问authStore
2. **操作前检查权限** - 防止无权限的API调用
3. **定期查看审计日志** - 发现潜在的权限配置问题
4. **生产环境优化** - 禁用详细日志，限制审计日志数量
5. **后端集成** - 实现Token刷新API

### 下一步

- [ ] 实施Token刷新后端API
- [ ] 添加权限缓存优化
- [ ] 实现权限变更实时推送
- [ ] 完善审计日志分析工具

---

**文档版本:** 1.0  
**最后更新:** 2025-11-29
