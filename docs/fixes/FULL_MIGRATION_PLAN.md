# 完整错误处理迁移计划

## 概述

本文档列出项目中所有需要迁移到统一错误处理的文件。

## 迁移状态

### ✅ 已完成（第一批 + 第二批）
- `src/stores/auth.ts` - 部分完成（核心方法已迁移）
- `src/stores/tagStore.ts` - 完成
- `src/stores/projectStore.ts` - 完成
- `src/stores/todoStore.ts` - 完成（性能优化）
- `src/stores/money/family-split-store.ts` - 完成
- `src/stores/money/budget-allocation-store.ts` - 完成
- `src/stores/money/family-ledger-store.ts` - 完成
- `src/stores/money/family-member-store.ts` - 完成
- `src/stores/money/currency-store.ts` - 完成

### 🔄 待迁移文件

#### 高优先级（核心功能）

1. **src/stores/auth.ts** - 扩展方法部分（6处）
   - `updateProfile()` - 3处
   - `uploadAvatar()` - 2处
   - `verifyEmailAddress()` - 2处
   - `sendEmailVerification()` - 2处
   - `changePassword()` - 2处
   - 状态：部分完成，扩展方法需要迁移

2. **src/stores/money/budget-allocation-store.ts** - API 响应验证（7处）
   - 所有 `if (!response.success)` 后的错误抛出
   - 状态：已使用 `wrapError` 包装 catch 块，但 response 验证未迁移

3. **src/stores/periodStore.ts** - 错误重新抛出（1处）
   - `withLoadingAndError()` 中的 `throw new Error(errorMessage)`
   - 状态：已有完善的错误处理系统，但有一处需要优化

#### 中优先级（常用功能）

4. **src/services/family/familyApi.ts** - API 客户端（3处）
   - HTTP 错误处理
   - 导出功能错误处理
   - 状态：需要统一 API 错误处理

5. **src/features/money/composables/useTransactionDataLoader.ts** - 数据加载（1处）
   - 交易未找到错误
   - 状态：需要迁移

6. **src/composables/useFamilyBudgetActions.ts** - 预算操作（1处）
   - 预算创建失败验证
   - 状态：需要迁移

7. **src/composables/usePermission.ts** - 权限检查（1处）
   - 权限装饰器错误
   - 状态：需要迁移

#### 低优先级（工具和服务）

8. **src/utils/zodFactory.ts** - 数据验证（2处）
   - Zod 验证失败
   - 不支持的重复周期类型
   - 状态：需要迁移

9. **src/utils/dbUtils.ts** - 数据库工具（1处）
   - WAL 模式启用失败
   - 状态：需要迁移

10. **src/schema/common.ts** - Schema 验证（1处）
    - 字段缺失验证
    - 状态：需要迁移

11. **src/features/tags/services/tags.ts** - 标签服务（2处）
    - 数据库错误
    - 插入失败
    - 状态：需要迁移

12. **src/features/projects/services/projects.ts** - 项目服务（2处）
    - 数据库错误
    - 插入失败
    - 状态：需要迁移

13. **src/services/money/family-member.ts** - 家庭成员服务（1处）
    - 未实现功能占位符
    - 状态：需要迁移

## 迁移优先级说明

### 高优先级
- 用户直接交互的功能
- 核心业务逻辑
- 频繁调用的代码路径

### 中优先级
- API 客户端和服务层
- Composables（组合式函数）
- 数据加载器

### 低优先级
- 工具函数
- Schema 验证
- 数据库底层操作
- 未实现的功能占位符

## 迁移策略

### 第三批：Auth Store 扩展方法
完成 `auth.ts` 中剩余的扩展方法迁移。

### 第四批：API 响应验证
统一处理所有 API 响应验证错误。

### 第五批：服务层和 Composables
迁移所有服务层和组合式函数。

### 第六批：工具函数和底层代码
迁移工具函数、Schema 验证和数据库操作。

## 统计

- **总文件数**: 13 个文件
- **总错误处理数**: 约 35+ 处
- **已完成**: 9 个文件，23+ 处
- **待完成**: 13 个文件（部分重叠），约 35+ 处

## 预期完成时间

- 第三批：10 分钟
- 第四批：15 分钟
- 第五批：20 分钟
- 第六批：15 分钟

**总计**: 约 60 分钟

## 验证计划

每批完成后：
1. 运行 `getDiagnostics` 检查类型错误
2. 更新 `FIXES_SUMMARY.md`
3. 记录迁移进度

全部完成后：
1. 运行完整的类型检查
2. 运行单元测试（如果有）
3. 手动测试关键功能
4. 更新所有相关文档

## 相关文档

- [错误处理迁移指南](./error-handling-migration.md)
- [修复总结](./FIXES_SUMMARY.md)
- [迁移完成报告](./MIGRATION_COMPLETE.md)
