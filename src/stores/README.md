# Stores 架构文档

## 概述

本目录包含应用的所有 Pinia stores，负责状态管理和业务逻辑。

## 目录结构

```
stores/
├── index.ts              # 全局 store 初始化
├── auth.ts               # 认证状态
├── locales.ts            # 国际化
├── theme.ts              # 主题偏好
├── todoStore.ts          # 待办事项管理
├── periodStore.ts        # 经期记录
├── projectStore.ts       # 项目管理
├── tagStore.ts           # 标签管理
├── menuStore.ts          # 菜单状态
├── mediaQueries.ts       # 媒体查询
├── transition.ts         # 过渡动画
└── money/                # 财务模块 stores
    ├── index.ts          # 模块导出
    ├── init.ts           # 模块初始化
    ├── store-events.ts   # 事件总线（解耦核心）
    ├── account-store.ts  # 账户管理
    ├── transaction-store.ts  # 交易管理
    ├── budget-store.ts   # 预算管理
    ├── category-store.ts # 分类管理
    ├── currency-store.ts # 货币管理
    ├── reminder-store.ts # 提醒管理
    ├── family-ledger-store.ts    # 家庭账本
    ├── family-member-store.ts    # 家庭成员
    ├── family-split-store.ts     # 分账管理
    ├── budget-allocation-store.ts # 预算分配
    ├── money-config-store.ts     # 配置管理
    └── money-errors.ts   # 错误处理
```

## 依赖关系图

```
┌─────────────────────────────────────────────────────────────┐
│                      store-events.ts                        │
│                    (事件总线 - 无依赖)                       │
└─────────────────────────────────────────────────────────────┘
                              ▲
                              │ 导入事件函数
        ┌─────────────────────┼─────────────────────┐
        │                     │                     │
        ▼                     ▼                     ▼
┌───────────────┐   ┌───────────────┐   ┌───────────────┐
│ account-store │   │transaction-   │   │ family-ledger │
│               │   │    store      │   │    -store     │
└───────────────┘   └───────────────┘   └───────────────┘
        │                     │                     │
        │    emitStoreEvent   │                     │
        │◄────────────────────┤                     │
        │                     │                     │
        └─────────────────────┴─────────────────────┘
                              │
                              ▼
                    ┌───────────────┐
                    │    init.ts    │
                    │ (初始化监听器) │
                    └───────────────┘
```

## 设计原则

### 1. 避免循环依赖

- **事件总线模式**: 使用 `store-events.ts` 作为中央事件总线
- **单向依赖**: stores 只导入事件函数，不直接导入其他 stores
- **延迟初始化**: 通过 `init.ts` 在运行时设置事件监听器

### 2. 不可变状态更新

所有 store 的状态更新都遵循不可变模式：

```typescript
// ✅ 正确：创建新数组
this.transactions = [newTransaction, ...this.transactions];

// ❌ 错误：直接修改
this.transactions.push(newTransaction);
```

### 3. 统一错误处理

使用 `AppError` 类进行错误包装：

```typescript
handleError(
  err: unknown,
  code: StoreErrorCode,
  message: string,
  showToast = true,
): AppError {
  const appError = AppError.wrap(STORE_MODULE, err, code, message);
  this.error = appError;
  appError.log();
  if (showToast) {
    toast.error(appError.getUserMessage());
  }
  return appError;
}
```

### 4. 结构化日志

使用 `Lg` 工具进行日志记录：

```typescript
Lg.i(STORE_MODULE, '操作描述', { context: data });
Lg.w(STORE_MODULE, '警告信息', { details });
Lg.e(STORE_MODULE, '错误信息', error);
```

## 事件通信

### 事件类型

| 事件名 | 触发时机 | 数据 |
|--------|----------|------|
| `transaction:created` | 创建交易后 | `{ transactionSerialNum, accountSerialNum }` |
| `transaction:updated` | 更新交易后 | `{ transactionSerialNum, accountSerialNum }` |
| `transaction:deleted` | 删除交易后 | `{ transactionSerialNum, accountSerialNum }` |
| `transfer:created` | 创建转账后 | `{ fromAccountSerialNum, toAccountSerialNum, ... }` |
| `transfer:updated` | 更新转账后 | `{ fromAccountSerialNum, toAccountSerialNum, ... }` |
| `transfer:deleted` | 删除转账后 | `{ fromAccountSerialNum, toAccountSerialNum, ... }` |
| `ledger:updated` | 更新账本后 | `{ serialNum }` |
| `member:created` | 创建成员后 | `{ serialNum, ledgerSerialNum }` |

### 使用示例

发送事件：
```typescript
import { emitStoreEvent } from './store-events';

emitStoreEvent('transaction:created', {
  transactionSerialNum: transaction.serialNum,
  accountSerialNum: transaction.accountSerialNum,
});
```

监听事件：
```typescript
import { onStoreEvent } from './store-events';

onStoreEvent('transaction:created', async ({ accountSerialNum }) => {
  await this.refreshAccount(accountSerialNum);
});
```

## 最佳实践

1. **新建 store 时**：
   - 定义明确的状态接口
   - 使用 `createInitialState()` 函数
   - 实现 `$reset()` 方法
   - 添加 `errorMessage` getter

2. **添加 action 时**：
   - 使用 `withLoadingSafe` 包装异步操作
   - 添加结构化日志
   - 发送相关事件通知其他 stores

3. **跨 store 通信时**：
   - 使用事件总线，不直接导入其他 store
   - 在 `init.ts` 中设置事件监听器
