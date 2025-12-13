# 错误处理迁移指南

## 概述

为了统一项目中的错误处理，我们引入了 `src/utils/errorHandler.ts` 工具模块。所有直接使用 `throw new Error()` 的代码应该迁移到使用统一的错误处理函数。

## 迁移步骤

### 1. 导入错误处理工具

```typescript
import { throwAppError, assertExists, assert } from '@/utils/errorHandler';
import { AppErrorSeverity } from '@/errors/appError';
```

### 2. 替换 `throw new Error()`

#### 之前：
```typescript
if (!user) {
  throw new Error('用户未登录');
}
```

#### 之后：
```typescript
import { throwAppError } from '@/utils/errorHandler';
import { AppErrorSeverity } from '@/errors/appError';

if (!user) {
  throwAppError('ModuleName', 'NOT_AUTHENTICATED', '用户未登录', AppErrorSeverity.MEDIUM);
}
```

### 3. 使用 `assertExists` 简化空值检查

#### 之前：
```typescript
const user = getUser();
if (!user) {
  throw new Error('用户不存在');
}
// 使用 user
```

#### 之后：
```typescript
import { assertExists } from '@/utils/errorHandler';
import { AppErrorSeverity } from '@/errors/appError';

const user = getUser();
assertExists(user, 'ModuleName', 'USER_NOT_FOUND', '用户不存在', AppErrorSeverity.MEDIUM);
// TypeScript 现在知道 user 不是 null/undefined
```

### 4. 使用 `assert` 进行条件验证

#### 之前：
```typescript
if (amount < 0) {
  throw new Error('金额不能为负数');
}
```

#### 之后：
```typescript
import { assert } from '@/utils/errorHandler';
import { AppErrorSeverity } from '@/errors/appError';

assert(amount >= 0, 'Transaction', 'INVALID_AMOUNT', '金额不能为负数', AppErrorSeverity.MEDIUM);
```

## 需要迁移的文件

以下文件包含直接的 `throw new Error()` 调用，需要迁移：

### Stores
- `src/stores/tagStore.ts` (4 处)
- `src/stores/projectStore.ts` (4 处)
- `src/stores/periodStore.ts` (1 处)
- `src/stores/money/family-split-store.ts` (5 处)
- `src/stores/money/family-member-store.ts` (1 处)
- `src/stores/money/family-ledger-store.ts` (1 处)
- `src/stores/money/currency-store.ts` (1 处)
- `src/stores/money/budget-allocation-store.ts` (7 处)
- `src/stores/auth.ts` (部分已迁移)

### 错误代码命名规范

使用大写下划线命名法，描述性强：

- `NOT_FOUND` - 资源不存在
- `ALREADY_EXISTS` - 资源已存在
- `INVALID_INPUT` - 无效输入
- `NOT_AUTHENTICATED` - 未认证
- `UNAUTHORIZED` - 未授权
- `OPERATION_FAILED` - 操作失败
- `INVALID_STATE` - 无效状态

### 严重程度选择

- `AppErrorSeverity.CRITICAL` - 系统级错误，需要立即处理
- `AppErrorSeverity.HIGH` - 重要错误，影响核心功能
- `AppErrorSeverity.MEDIUM` - 一般错误，影响部分功能（默认）
- `AppErrorSeverity.LOW` - 轻微错误，不影响主要功能

## 示例：完整迁移

### tagStore.ts 迁移示例

#### 之前：
```typescript
function addTag(input: TagInput) {
  const tag = createTag(input);
  if (tags.value.has(tag.serialNum)) {
    throw new Error(`Tag with serialNum ${tag.serialNum} already exists.`);
  }
  tags.value.set(tag.serialNum, tag);
}
```

#### 之后：
```typescript
import { throwAppError } from '@/utils/errorHandler';
import { AppErrorSeverity } from '@/errors/appError';

function addTag(input: TagInput) {
  const tag = createTag(input);
  if (tags.value.has(tag.serialNum)) {
    throwAppError(
      'TagStore',
      'TAG_ALREADY_EXISTS',
      `标签已存在: ${tag.serialNum}`,
      AppErrorSeverity.MEDIUM
    );
  }
  tags.value.set(tag.serialNum, tag);
}
```

## 好处

1. **一致性** - 所有错误都使用相同的格式和结构
2. **可追踪** - 错误包含模块名、错误代码、严重程度等元数据
3. **类型安全** - `assertExists` 和 `assert` 提供类型守卫
4. **易于调试** - 统一的错误日志格式
5. **更好的用户体验** - 可以根据错误类型提供更友好的提示

## 注意事项

1. 模块名应该使用 PascalCase（如 `TagStore`、`AuthService`）
2. 错误代码应该使用 UPPER_SNAKE_CASE（如 `NOT_FOUND`、`INVALID_INPUT`）
3. 错误消息应该清晰、具体，便于用户理解
4. 选择合适的严重程度，不要滥用 CRITICAL
