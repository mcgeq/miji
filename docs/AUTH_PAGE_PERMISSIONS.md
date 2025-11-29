# 页面权限配置指南

## 已完成的页面配置

### ✅ 核心页面
- `src/pages/money.vue` - 财务管理
  - Permission: `TRANSACTION_VIEW`
  
- `src/pages/settings.vue` - 设置
  - Permission: `SETTINGS_VIEW`
  
- `src/pages/family-ledger.vue` - 家庭账本
  - Permission: `LEDGER_VIEW`

## 待配置页面清单

### 财务相关 (money/)
| 文件 | 权限 | 标题 | 说明 |
|------|------|------|------|
| `money/budget-allocations.vue` | `BUDGET_VIEW` | 预算分配 | 查看预算分配 |
| `money/debt-relations.vue` | `TRANSACTION_VIEW` | 债务关系 | 查看债务关系 |
| `money/members.vue` | `MEMBER_VIEW` | 成员管理 | 查看账本成员 |
| `money/settlement-records.vue` | `TRANSACTION_VIEW` | 结算记录 | 查看结算记录 |
| `money/settlement-suggestion.vue` | `TRANSACTION_VIEW` | 结算建议 | 查看结算建议 |
| `money/split-records.vue` | `TRANSACTION_VIEW` | 分摊记录 | 查看分摊记录 |
| `money/split-templates.vue` | `TRANSACTION_VIEW` | 分摊模板 | 查看分摊模板 |
| `money/statistics.vue` | `STATS_VIEW` | 统计分析 | 查看统计数据 |

### 家庭账本相关 (family-ledger/)
| 文件 | 权限 | 标题 | 说明 |
|------|------|------|------|
| `family-ledger/[serialNum].vue` | `LEDGER_VIEW` | 账本详情 | 查看账本详情 |
| `family-ledger/member/[memberSerialNum].vue` | `MEMBER_VIEW` | 成员详情 | 查看成员详情 |

### 其他页面
| 文件 | 权限 | 标题 | 说明 |
|------|------|------|------|
| `index.vue` | - | 首页 | 无需权限 |
| `budget-stats.vue` | `BUDGET_VIEW`, `STATS_VIEW` | 预算统计 | 查看预算统计 |
| `transaction-stats.vue` | `TRANSACTION_VIEW`, `STATS_VIEW` | 交易统计 | 查看交易统计 |
| `projects.vue` | - | 项目 | 待定 |
| `todos.vue` | - | 待办 | 待定 |
| `tags.vue` | - | 标签 | 待定 |
| `health/period.vue` | - | 经期管理 | 待定 |

### 认证页面（不需要权限）
| 文件 | 说明 |
|------|------|
| `auth/login.vue` | 登录页 - 白名单 |
| `auth/register.vue` | 注册页 - 白名单 |
| `splash.vue` | 启动页 - 白名单 |

## 配置模板

### 标准页面配置
```typescript
import { Permission } from '@/types/auth';

definePage({
  name: 'page-name',
  meta: {
    requiresAuth: true,
    layout: 'default',
    permissions: [Permission.XXX_VIEW],
    title: '页面标题',
    icon: 'icon-name',
  },
});
```

### 多权限配置（OR 关系）
```typescript
definePage({
  name: 'page-name',
  meta: {
    requiresAuth: true,
    permissions: [Permission.XXX_VIEW, Permission.YYY_VIEW], // 满足任一即可
    title: '页面标题',
  },
});
```

### 角色配置
```typescript
import { Role } from '@/types/auth';

definePage({
  name: 'page-name',
  meta: {
    requiresAuth: true,
    roles: [Role.ADMIN, Role.OWNER], // 只有管理员和所有者可访问
    title: '页面标题',
  },
});
```

## 实施步骤

### 批量更新脚本

为了快速更新，可以使用以下模式：

1. **查看页面**
   ```bash
   cat src/pages/money/statistics.vue
   ```

2. **添加权限**
   - 导入 Permission
   - 在 meta 中添加 permissions 数组
   - 添加 title 和 icon

3. **测试**
   - 以不同角色登录
   - 验证页面访问权限
   - 确认重定向正常

## 进度追踪

- ✅ 核心页面 (3/3) - 100%
- ⏳ 财务页面 (0/8) - 0%
- ⏳ 账本页面 (0/2) - 0%
- ⏳ 其他页面 (0/6) - 0%

**总进度: 3/19 - 16%**

## 注意事项

1. **权限选择原则**
   - 使用最小权限原则
   - 查看页面用 `XXX_VIEW`
   - 管理页面用 `XXX_MANAGE` 或 `XXX_ADMIN`

2. **测试要点**
   - 未登录访问 → 跳转登录页
   - 无权限访问 → 跳转首页并提示
   - 有权限访问 → 正常显示

3. **图标命名**
   - 使用 lucide-vue-next 图标名称
   - 小写，用连字符分隔

4. **标题命名**
   - 简短明了
   - 中文优先
   - 与功能对应
