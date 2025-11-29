# 默认用户权限说明

## 问题背景

在实施RBAC权限系统后，默认创建的用户可能没有明确的`role`和`permissions`字段，导致无法访问任何页面，出现"您没有权限访问此页面"的错误。

## 解决方案

### 自动角色和权限授予

Auth Store在用户登录时会自动处理缺失的角色和权限：

```typescript
// 如果用户数据中没有role，默认为USER角色
const userRole = ((userData as any).role as Role) || Role.USER;

// 如果用户数据中没有permissions，使用空数组
const userPermissions = ((userData as any).permissions as Permission[]) || [];

role.value = userRole;
permissions.value = userPermissions;
```

### 有效权限计算

即使用户的`permissions`为空数组，`effectivePermissions`计算属性会自动从`RolePermissions`中获取角色对应的权限：

```typescript
const effectivePermissions = computed(() => {
  const rolePerms = RolePermissions[role.value] || [];
  return [...new Set([...rolePerms, ...permissions.value])];
});
```

## 默认权限列表

### Role.USER 默认权限

当用户以`USER`角色登录时，自动获得以下权限：

#### 查看权限
- ✅ `TRANSACTION_VIEW` - 查看交易
- ✅ `ACCOUNT_VIEW` - 查看账户
- ✅ `BUDGET_VIEW` - 查看预算
- ✅ `REMINDER_VIEW` - 查看提醒
- ✅ `LEDGER_VIEW` - 查看账本
- ✅ `STATS_VIEW` - 查看统计
- ✅ `SETTINGS_VIEW` - 查看设置

#### 创建权限
- ✅ `TRANSACTION_CREATE` - 创建交易
- ✅ `ACCOUNT_CREATE` - 创建账户
- ✅ `BUDGET_CREATE` - 创建预算
- ✅ `REMINDER_CREATE` - 创建提醒

#### 编辑权限
- ✅ `TRANSACTION_EDIT` - 编辑交易
- ✅ `ACCOUNT_EDIT` - 编辑账户
- ✅ `BUDGET_EDIT` - 编辑预算
- ✅ `REMINDER_EDIT` - 编辑提醒

### Role.ADMIN 默认权限

管理员角色继承USER的所有权限，并额外获得：

#### 删除权限
- ✅ `TRANSACTION_DELETE` - 删除交易
- ✅ `ACCOUNT_DELETE` - 删除账户
- ✅ `BUDGET_DELETE` - 删除预算
- ✅ `REMINDER_DELETE` - 删除提醒

#### 管理权限
- ✅ `LEDGER_EDIT` - 编辑账本
- ✅ `LEDGER_DELETE` - 删除账本
- ✅ `MEMBER_VIEW` - 查看成员
- ✅ `MEMBER_MANAGE` - 管理成员
- ✅ `SETTINGS_MANAGE` - 管理设置

### Role.OWNER

所有者拥有系统的所有26个权限。

## 页面访问权限

### 核心页面
| 页面 | 需要权限 | USER | ADMIN | OWNER |
|------|----------|------|-------|-------|
| 财务管理 | `TRANSACTION_VIEW` | ✅ | ✅ | ✅ |
| 设置 | `SETTINGS_VIEW` | ✅ | ✅ | ✅ |
| 家庭账本 | `LEDGER_VIEW` | ✅ | ✅ | ✅ |
| 统计分析 | `STATS_VIEW` | ✅ | ✅ | ✅ |

### 管理页面
| 页面 | 需要权限 | USER | ADMIN | OWNER |
|------|----------|------|-------|-------|
| 成员管理 | `MEMBER_VIEW` | ❌ | ✅ | ✅ |
| 设置管理 | `SETTINGS_MANAGE` | ❌ | ✅ | ✅ |

## 工作流程

### 1. 用户登录
```
用户登录 → Auth Store.login()
  ↓
检查 userData.role
  ├─ 有 role → 使用该 role
  └─ 无 role → 默认 Role.USER
  ↓
检查 userData.permissions  
  ├─ 有 permissions → 使用该 permissions
  └─ 无 permissions → 使用空数组 []
  ↓
计算 effectivePermissions
  = RolePermissions[role] + permissions
  ↓
用户可以访问对应权限的页面
```

### 2. 权限检查
```
访问页面 → 路由守卫检查
  ↓
页面需要 permissions: [TRANSACTION_VIEW]
  ↓
Auth Store.hasAnyPermission([TRANSACTION_VIEW])
  ↓
检查 effectivePermissions 是否包含 TRANSACTION_VIEW
  ↓
USER角色: RolePermissions[Role.USER] 包含 TRANSACTION_VIEW → 允许访问 ✅
```

## 后端集成

### 推荐方案

**方案1：后端不返回role和permissions**
- 前端默认使用 Role.USER
- 适用于单用户系统或简单权限需求

**方案2：后端返回role，不返回permissions**
- 前端根据角色自动授予权限
- 适用于基于角色的权限管理

**方案3：后端返回role和permissions**（推荐）
- 支持细粒度权限控制
- 可以为用户授予额外权限或限制某些权限

### 后端返回示例

```json
{
  "serialNum": "user123",
  "name": "张三",
  "email": "zhangsan@example.com",
  "role": "User",
  "permissions": [
    "transaction:view",
    "transaction:create",
    "account:view"
  ]
}
```

## 调试信息

登录时会在控制台输出权限信息：

```
Auth | User logged in successfully
{
  hasUser: true,
  hasToken: true,
  rememberMe: false,
  role: 'user',
  explicitPermissions: 0,      // 明确授予的权限数量
  effectivePermissions: 13     // 有效权限总数（角色权限 + 明确权限）
}
```

## 常见问题

### Q: 为什么我的用户无法访问任何页面？
A: 检查以下几点：
1. 用户是否已登录？
2. 控制台是否显示权限信息？
3. `effectivePermissions` 数量是否大于0？
4. 路由守卫缓存是否已清除？

### Q: 如何给用户授予特殊权限？
A: 后端返回用户数据时，包含`permissions`数组：
```json
{
  "role": "User",
  "permissions": ["ledger:admin"]  // 普通用户也可以管理账本
}
```

### Q: 如何限制用户权限？
A: 使用更低的角色（如Guest），或后端只返回需要的权限列表。

## 总结

- ✅ 默认用户自动获得`Role.USER`角色
- ✅ USER角色包含13个基础权限
- ✅ 可以正常访问财务、账本、统计等核心功能
- ✅ 支持后端自定义角色和权限
- ✅ 前端权限检查完全基于`effectivePermissions`
