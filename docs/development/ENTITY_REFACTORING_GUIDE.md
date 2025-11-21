# 实体引用系统重构指南

## 📋 概述

本次重构引入了统一的实体引用类型系统，为 Currency、Category、SubCategory、Account 提供了类型安全和一致性保证。

## 🎯 重构目标

1. **类型安全**：为所有实体引用添加类型约束
2. **一致性**：统一响应和创建时的数据格式
3. **可维护性**：集中管理实体引用类型定义
4. **向后兼容**：保持现有 API 接口不变

## 📦 新增类型

### 基础类型约束

```typescript
// src/schema/common.ts

// 分类名称约束（2-20字符）
export const CategoryNameSchema = z.string().min(2).max(20);
export type CategoryName = z.infer<typeof CategoryNameSchema>;

// 子分类名称约束（2-20字符）
export const SubCategoryNameSchema = z.string().min(2).max(20);
export type SubCategoryName = z.infer<typeof SubCategoryNameSchema>;
```

### 实体引用类型

```typescript
// 货币引用（创建时用 code，响应时用完整对象）
export const CurrencyRefSchema = z.union([
  z.string().length(3),
  z.lazy(() => CurrencySchema),
]);

// 分类引用（支持字符串或完整对象）
export const CategoryRefSchema = z.union([
  CategoryNameSchema,
  z.lazy(() => CategorySchema),
]);

// 子分类引用（支持字符串或完整对象）
export const SubCategoryRefSchema = z.union([
  SubCategoryNameSchema,
  z.lazy(() => SubCategorySchema),
]);

// 账户引用（创建时用 serialNum，响应时用完整对象）
export const AccountRefSchema = z.union([
  SerialNumSchema,
  z.lazy(() => AccountSchema),
]);
```

## 🔄 Schema 变更

### 1. Category & SubCategory

**变更前**：
```typescript
export const CategorySchema = z.object({
  name: NameSchema,  // 通用名称约束
  icon: z.string(),
  createdAt: DateTimeSchema,
  updatedAt: DateTimeSchema.optional().nullable(),
});
```

**变更后**：
```typescript
export const CategorySchema = z.object({
  name: CategoryNameSchema,  // ✅ 专用分类名称约束
  icon: z.string(),
  createdAt: DateTimeSchema,
  updatedAt: DateTimeSchema.optional().nullable(),
});

export const SubCategorySchema = z.object({
  name: SubCategoryNameSchema,  // ✅ 专用子分类名称约束
  icon: z.string(),
  categoryName: CategoryNameSchema,  // ✅ 关联分类名称
  createdAt: DateTimeSchema,
  updatedAt: DateTimeSchema.optional().nullable(),
});
```

### 2. Transaction

**变更前**：
```typescript
export const TransactionSchema = z.object({
  // ...
  category: z.string(),  // ❌ 无约束
  subCategory: z.string().optional().nullable(),  // ❌ 无约束
  // ...
});
```

**变更后**：
```typescript
export const TransactionSchema = z.object({
  // ...
  category: CategoryNameSchema,  // ✅ 有类型约束
  subCategory: SubCategoryNameSchema.optional().nullable(),  // ✅ 有类型约束
  // ...
});
```

### 3. Budget

**变更前**：
```typescript
export const BudgetSchema = z.object({
  // ...
  categoryScope: z.array(z.string()),  // ❌ 无约束
  // ...
});
```

**变更后**：
```typescript
export const BudgetSchema = z.object({
  // ...
  categoryScope: z.array(CategoryNameSchema),  // ✅ 有类型约束
  // ...
});
```

### 4. BilReminder

**变更前**：
```typescript
export const BilReminderSchema = z.object({
  // ...
  category: z.string(),  // ❌ 无约束
  // ...
});
```

**变更后**：
```typescript
export const BilReminderSchema = z.object({
  // ...
  category: CategoryNameSchema,  // ✅ 有类型约束
  // ...
});
```

## 🔧 前端适配指南

### 组件层面

#### 1. 类型导入更新

**变更前**：
```typescript
import type { Transaction } from '@/schema/money';
```

**变更后**：
```typescript
import type { Transaction } from '@/schema/money';
import type { CategoryName, SubCategoryName } from '@/schema/common';
```

#### 2. 表单验证

**变更前**：
```typescript
// 无验证
const category = form.category;
```

**变更后**：
```typescript
// 自动验证（2-20字符）
const category: CategoryName = form.category;
```

#### 3. 分类选择器

现有的 `CategorySelector` 组件无需修改，因为：
- 输入输出仍然是字符串
- 类型约束在 Schema 层自动生效

### Store 层面

#### useCategoryStore

无需修改，现有实现已兼容：

```typescript
// 现有代码保持不变
const categories = await categoryStore.fetchCategories();
const category = categories.find(c => c.name === 'Food');
```

### Service 层面

#### API 调用

无需修改，现有 API 接口保持不变：

```typescript
// 创建交易（仍然传字符串）
await MoneyDb.createTransaction({
  category: 'Food',  // ✅ 自动验证为 CategoryName
  subCategory: 'Breakfast',  // ✅ 自动验证为 SubCategoryName
  // ...
});

// 响应（仍然返回字符串）
const transaction = await MoneyDb.getTransaction(id);
console.log(transaction.category);  // 'Food'
```

## ⚠️ 注意事项

### 1. 类型约束生效

```typescript
// ❌ 错误：太短
const category: CategoryName = 'A';  // 验证失败

// ❌ 错误：太长
const category: CategoryName = 'Very Long Category Name That Exceeds Limit';

// ✅ 正确
const category: CategoryName = 'Food';
```

### 2. 可选字段处理

```typescript
// SubCategory 是可选的
const transaction: Transaction = {
  category: 'Food',  // 必填
  subCategory: null,  // ✅ 可以为 null
  // ...
};
```

### 3. 数组字段

```typescript
// Budget 的 categoryScope 是数组
const budget: Budget = {
  categoryScope: ['Food', 'Transport'],  // ✅ 每个元素都验证
  // ...
};
```

## 🧪 测试建议

### 单元测试

```typescript
import { CategoryNameSchema, SubCategoryNameSchema } from '@/schema/common';

describe('CategoryNameSchema', () => {
  it('should accept valid category names', () => {
    expect(CategoryNameSchema.parse('Food')).toBe('Food');
    expect(CategoryNameSchema.parse('Transport')).toBe('Transport');
  });

  it('should reject invalid category names', () => {
    expect(() => CategoryNameSchema.parse('A')).toThrow();  // 太短
    expect(() => CategoryNameSchema.parse('Very Long Category Name')).toThrow();  // 太长
  });
});
```

### 集成测试

```typescript
describe('Transaction Creation', () => {
  it('should validate category name', async () => {
    const invalidTransaction = {
      category: 'A',  // 太短
      // ...
    };

    await expect(
      MoneyDb.createTransaction(invalidTransaction)
    ).rejects.toThrow();
  });

  it('should accept valid category name', async () => {
    const validTransaction = {
      category: 'Food',
      // ...
    };

    const result = await MoneyDb.createTransaction(validTransaction);
    expect(result.category).toBe('Food');
  });
});
```

## 📊 影响范围

### 直接影响

| 文件 | 变更类型 | 影响 |
|------|---------|------|
| `src/schema/common.ts` | 新增 | 添加类型定义 |
| `src/schema/money/category.ts` | 修改 | 使用新类型 |
| `src/schema/money/transaction.ts` | 修改 | 使用新类型 |
| `src/schema/money/budget.ts` | 修改 | 使用新类型 |
| `src/schema/money/bilReminder.ts` | 修改 | 使用新类型 |

### 间接影响

- ✅ **组件**：无需修改（类型自动推导）
- ✅ **Store**：无需修改（接口不变）
- ✅ **Service**：无需修改（API 不变）
- ⚠️ **测试**：需要更新验证逻辑

## 🚀 部署步骤

### 1. 代码审查

```bash
# 检查类型定义
git diff src/schema/common.ts

# 检查 Schema 更新
git diff src/schema/money/
```

### 2. 运行测试

```bash
# 单元测试
npm run test:unit

# 类型检查
npm run type-check

# Lint 检查
npm run lint
```

### 3. 本地验证

```bash
# 启动开发服务器
npm run dev

# 测试关键功能
# - 创建交易（验证分类输入）
# - 创建预算（验证分类范围）
# - 创建提醒（验证分类选择）
```

### 4. 部署

```bash
# 构建生产版本
npm run build

# 部署
npm run deploy
```

## 🔍 故障排查

### 问题 1：类型错误

**症状**：
```
Type 'string' is not assignable to type 'CategoryName'
```

**解决**：
```typescript
// 确保使用 CategoryNameSchema 验证
import { CategoryNameSchema } from '@/schema/common';

const category = CategoryNameSchema.parse(inputValue);
```

### 问题 2：验证失败

**症状**：
```
Validation error: Category name must be at least 2 characters long
```

**解决**：
```typescript
// 检查输入值长度
if (inputValue.length < 2 || inputValue.length > 20) {
  throw new Error('Invalid category name length');
}
```

### 问题 3：可选字段错误

**症状**：
```
Type 'null' is not assignable to type 'SubCategoryName'
```

**解决**：
```typescript
// 使用可选类型
const subCategory: SubCategoryName | null = null;  // ✅
```

## 📚 相关文档

- [实体使用一致性分析](./ENTITY_USAGE_CONSISTENCY_ANALYSIS.md)
- [Currency 迁移文档](./CURRENCY_FLAGS_MIGRATION.md)
- [Schema 设计指南](../schema/README.md)

## 🎉 总结

本次重构：

✅ **完成**：
- 创建实体引用类型系统
- 更新所有相关 Schema
- 添加类型约束和验证

✅ **优势**：
- 类型安全性提升
- 代码一致性改善
- 维护性增强

✅ **兼容性**：
- 向后兼容现有代码
- 无需大规模修改组件
- API 接口保持不变

---

**更新日期**：2025-11-21  
**版本**：1.0.0  
**作者**：Miji Development Team
