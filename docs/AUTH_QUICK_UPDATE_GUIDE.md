# 快速更新权限配置指南

## 已完成页面 ✅

1. ✅ `src/pages/money.vue` - 财务管理
2. ✅ `src/pages/settings.vue` - 设置
3. ✅ `src/pages/family-ledger.vue` - 家庭账本
4. ✅ `src/pages/money/statistics.vue` - 统计分析

## 剩余页面快速配置

### 配置模式

每个页面只需要在 `<script setup>` 中：
1. 导入 `Permission`
2. 在 `definePage` 的 `meta` 中添加 `permissions` 数组

### 批量配置清单

#### 财务相关页面

```typescript
// money/budget-allocations.vue
import { Permission } from '@/types/auth';
definePage({
  meta: {
    requiresAuth: true,
    permissions: [Permission.BUDGET_VIEW],
    title: '预算分配',
  },
});

// money/members.vue
import { Permission } from '@/types/auth';
definePage({
  meta: {
    requiresAuth: true,
    permissions: [Permission.MEMBER_VIEW],
    title: '成员管理',
  },
});

// money/debt-relations.vue
// money/settlement-records.vue
// money/settlement-suggestion.vue
// money/split-records.vue
// money/split-templates.vue
import { Permission } from '@/types/auth';
definePage({
  meta: {
    requiresAuth: true,
    permissions: [Permission.TRANSACTION_VIEW],
    title: '相应标题',
  },
});
```

#### 统计页面

```typescript
// budget-stats.vue
// transaction-stats.vue
import { Permission } from '@/types/auth';
definePage({
  meta: {
    requiresAuth: true,
    permissions: [Permission.STATS_VIEW],
    title: '相应标题',
  },
});
```

#### 家庭账本页面

```typescript
// family-ledger/[serialNum].vue
import { Permission } from '@/types/auth';
definePage({
  meta: {
    requiresAuth: true,
    permissions: [Permission.LEDGER_VIEW],
    title: '账本详情',
  },
});

// family-ledger/member/[memberSerialNum].vue
import { Permission } from '@/types/auth';
definePage({
  meta: {
    requiresAuth: true,
    permissions: [Permission.MEMBER_VIEW],
    title: '成员详情',
  },
});
```

## 验证步骤

### 1. 编译检查
```bash
npm run type-check
```

### 2. 运行测试
```bash
npm run dev
```

### 3. 手动测试
- [ ] 以普通用户登录
- [ ] 访问各个页面
- [ ] 验证权限控制
- [ ] 测试无权限时的重定向

## 完成标准

所有页面应该：
1. ✅ 导入 Permission 类型
2. ✅ 在 meta 中配置 permissions
3. ✅ 添加有意义的 title
4. ✅ 编译无错误
5. ✅ 权限验证正常

## 进度追踪

### 当前进度
- ✅ 核心页面: 4/4 (100%)
- ⏳ 财务页面: 1/8 (12.5%)
- ⏳ 其他页面: 0/7 (0%)

### 总体进度: 5/19 (26%)

## 注意事项

1. **不要修改已有功能**
   - 只添加 Permission 导入
   - 只修改 meta 配置
   - 不改变现有逻辑

2. **权限选择**
   - 查看类页面用 `_VIEW`
   - 管理类页面用 `_MANAGE`
   - 统计页面用 `STATS_VIEW`

3. **测试重点**
   - Guest 角色应该只能查看
   - User 角色可以查看和创建
   - Admin 可以管理
   - Owner 有所有权限

## 批量更新建议

由于页面较多，建议分批处理：
1. **第一批**: 剩余财务页面（7个文件）
2. **第二批**: 统计相关页面（2个文件）
3. **第三批**: 其他页面（5个文件）

每批完成后：
- 提交代码
- 运行测试
- 验证功能

## 下一步

完成所有页面配置后：
1. 更新 `AUTH_REFACTORING_PROGRESS.md`
2. 测试所有权限场景
3. 编写权限测试用例
4. 更新用户文档
