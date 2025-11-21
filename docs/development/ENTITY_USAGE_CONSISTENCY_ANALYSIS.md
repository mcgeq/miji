# 前端实体使用一致性分析

## 📊 概述

分析 Currency、Category、SubCategory、Account 四个核心实体在预算、提醒、交易等功能中的使用一致性。

## ✅ 一致性总结

### 整体评估：**基本统一，但存在部分不一致**

| 实体 | 一致性 | 问题 |
|------|--------|------|
| **Currency** | ⚠️ 部分统一 | 响应/创建格式不一致 |
| **Category** | ❌ 不统一 | 使用字符串，无类型约束 |
| **SubCategory** | ❌ 不统一 | 使用字符串，无类型约束 |
| **Account** | ✅ 统一 | 响应/创建格式一致 |

---

## 🔍 详细分析

### 1️⃣ Currency（货币）

#### Schema 定义

**响应格式**（从后端获取）：
```typescript
// Transaction/Budget/BilReminder 响应
currency: CurrencySchema  // 完整对象
{
  locale: string,
  code: string,
  symbol: string,
  isDefault: boolean,
  isActive: boolean,
  createdAt: DateTime,
  updatedAt?: DateTime
}
```

**创建格式**（发送到后端）：
```typescript
// Transaction/Budget/BilReminder 创建
currency: z.string().length(3)  // 仅 code
```

#### 使用位置

| 功能 | 响应格式 | 创建格式 | 一致性 |
|------|----------|----------|--------|
| **Transaction** | `CurrencySchema` | `string(3)` | ⚠️ 不一致 |
| **Budget** | `CurrencySchema` | `string(3)` | ⚠️ 不一致 |
| **BilReminder** | `CurrencySchema?` | `string(3)` | ⚠️ 不一致 |
| **Account** | `CurrencySchema` | `string(3)` | ⚠️ 不一致 |

#### 问题

1. **响应和创建格式不一致**
   - 响应：完整 `CurrencySchema` 对象
   - 创建：仅 `string` 类型的 code

2. **可选性不统一**
   - Transaction/Budget/Account：必填
   - BilReminder：可选（`optional().nullable()`）

#### 建议

✅ **当前设计合理**，因为：
- 响应需要完整信息（符号、区域等）用于显示
- 创建只需 code 即可关联
- 前端组件（`CurrencySelector`）统一处理

---

### 2️⃣ Category（分类）

#### Schema 定义

```typescript
// Transaction
category: z.string()  // ❌ 无类型约束

// Budget
categoryScope: z.array(z.string())  // ❌ 无类型约束

// BilReminder
category: z.string()  // ❌ 无类型约束
```

#### 使用位置

| 功能 | 字段名 | 类型 | 约束 |
|------|--------|------|------|
| **Transaction** | `category` | `string` | ❌ 无 |
| **Budget** | `categoryScope` | `string[]` | ❌ 无 |
| **BilReminder** | `category` | `string` | ❌ 无 |

#### 问题

1. **无类型约束**
   - 使用普通 `string`，没有引用 `CategorySchema`
   - 无法保证数据有效性

2. **字段名不统一**
   - Transaction/BilReminder：`category`
   - Budget：`categoryScope`（数组形式）

3. **缺少关联验证**
   - 无法在 Schema 层面验证分类是否存在
   - 依赖运行时验证

#### 建议

❌ **需要改进**：

```typescript
// 方案1：使用 CategoryName 类型
export const CategoryNameSchema = z.string().min(2).max(20);

// Transaction
category: CategoryNameSchema

// Budget
categoryScope: z.array(CategoryNameSchema)

// BilReminder
category: CategoryNameSchema
```

或

```typescript
// 方案2：使用枚举（如果分类固定）
export const CategoryEnum = z.enum(['Food', 'Transport', ...]);
```

---

### 3️⃣ SubCategory（子分类）

#### Schema 定义

```typescript
// Transaction
subCategory: z.string().optional().nullable()  // ❌ 无类型约束
```

#### 使用位置

| 功能 | 字段名 | 类型 | 约束 |
|------|--------|------|------|
| **Transaction** | `subCategory` | `string?` | ❌ 无 |
| **Budget** | - | - | ❌ 不支持 |
| **BilReminder** | - | - | ❌ 不支持 |

#### 问题

1. **无类型约束**
   - 使用普通 `string`，没有引用 `SubCategorySchema`

2. **功能覆盖不完整**
   - 仅 Transaction 支持子分类
   - Budget/BilReminder 不支持（可能是设计决策）

3. **缺少关联验证**
   - 无法验证子分类是否属于指定分类

#### 建议

❌ **需要改进**：

```typescript
// 定义子分类名称类型
export const SubCategoryNameSchema = z.string().min(2).max(20);

// Transaction
subCategory: SubCategoryNameSchema.optional().nullable()

// 如果需要，扩展到 Budget/BilReminder
```

---

### 4️⃣ Account（账户）

#### Schema 定义

**响应格式**：
```typescript
// Transaction 响应
account: AccountSchema  // 完整对象
{
  serialNum: string,
  name: string,
  type: AccountType,
  balance: string,
  currency: CurrencySchema,
  ...
}
```

**创建格式**：
```typescript
// Transaction 创建
accountSerialNum: SerialNumSchema  // 仅 serialNum

// Budget 创建
accountSerialNum: SerialNumSchema.optional().nullable()
```

#### 使用位置

| 功能 | 响应字段 | 创建字段 | 一致性 |
|------|----------|----------|--------|
| **Transaction** | `account: AccountSchema` | `accountSerialNum` | ✅ 统一 |
| **Budget** | `account: AccountSchema?` | `accountSerialNum?` | ✅ 统一 |
| **BilReminder** | - | - | ✅ 不需要 |

#### 评估

✅ **设计合理且统一**：
- 响应包含完整账户信息
- 创建只需 serialNum 关联
- 字段命名清晰（`account` vs `accountSerialNum`）

---

## 📋 问题汇总

### 🔴 高优先级问题

1. **Category/SubCategory 无类型约束**
   - 影响：数据验证不完整，容易出错
   - 建议：引入 `CategoryNameSchema` 和 `SubCategoryNameSchema`

2. **Category 字段名不统一**
   - Transaction/BilReminder：`category`
   - Budget：`categoryScope`
   - 建议：统一命名规范

### 🟡 中优先级问题

3. **Currency 可选性不统一**
   - BilReminder 的 currency 是可选的
   - 其他功能是必填的
   - 建议：明确业务规则，统一处理

4. **SubCategory 功能覆盖不完整**
   - 仅 Transaction 支持
   - 建议：评估是否需要扩展到其他功能

---

## 🎯 改进建议

### 短期改进（立即可做）

#### 1. 统一 Category/SubCategory 类型

```typescript
// src/schema/common.ts
export const CategoryNameSchema = z.string().min(2).max(20);
export const SubCategoryNameSchema = z.string().min(2).max(20);

export type CategoryName = z.infer<typeof CategoryNameSchema>;
export type SubCategoryName = z.infer<typeof SubCategoryNameSchema>;
```

#### 2. 更新各功能 Schema

```typescript
// src/schema/money/transaction.ts
export const TransactionSchema = z.object({
  // ...
  category: CategoryNameSchema,
  subCategory: SubCategoryNameSchema.optional().nullable(),
  // ...
});

// src/schema/money/budget.ts
export const BudgetSchema = z.object({
  // ...
  categoryScope: z.array(CategoryNameSchema),
  // ...
});

// src/schema/money/bilReminder.ts
export const BilReminderSchema = z.object({
  // ...
  category: CategoryNameSchema,
  // ...
});
```

### 中期改进（需要评估）

#### 3. 考虑引入关联验证

```typescript
// 验证分类是否存在
export const ValidCategorySchema = CategoryNameSchema.refine(
  async (name) => {
    const categories = await categoryStore.fetchCategories();
    return categories.some(c => c.name === name);
  },
  { message: '分类不存在' }
);
```

#### 4. 统一字段命名

- 考虑将 Budget 的 `categoryScope` 改为 `categories`
- 或者统一使用 `categoryNames` / `categoryScope`

### 长期改进（架构优化）

#### 5. 引入实体引用系统

```typescript
// 定义实体引用类型
export type EntityRef<T> = {
  id: string;
  type: string;
  data?: T;
};

// 使用示例
export const TransactionSchema = z.object({
  // ...
  categoryRef: z.object({
    name: CategoryNameSchema,
    verified: z.boolean().optional(),
  }),
  // ...
});
```

---

## 📊 一致性评分

| 维度 | 评分 | 说明 |
|------|------|------|
| **Currency** | 7/10 | 响应/创建格式不一致，但设计合理 |
| **Category** | 4/10 | 无类型约束，字段名不统一 |
| **SubCategory** | 3/10 | 无类型约束，功能覆盖不完整 |
| **Account** | 9/10 | 设计统一且合理 |
| **整体** | 6/10 | 基本可用，但有改进空间 |

---

## 🚀 实施计划

### Phase 1: 类型约束（1-2天）
- [ ] 创建 `CategoryNameSchema` 和 `SubCategoryNameSchema`
- [ ] 更新 Transaction/Budget/BilReminder Schema
- [ ] 更新相关组件的类型定义

### Phase 2: 字段统一（2-3天）
- [ ] 评估 Budget 的 `categoryScope` 命名
- [ ] 统一 Category 字段命名规范
- [ ] 更新文档

### Phase 3: 验证增强（3-5天）
- [ ] 添加分类存在性验证
- [ ] 添加子分类与分类的关联验证
- [ ] 完善错误提示

### Phase 4: 测试与部署（2-3天）
- [ ] 单元测试
- [ ] 集成测试
- [ ] 文档更新
- [ ] 部署上线

---

## 📚 相关文档

- [Currency Schema](../schema/common.ts#L96-L114)
- [Category Schema](../schema/money/category.ts)
- [Transaction Schema](../schema/money/transaction.ts)
- [Budget Schema](../schema/money/budget.ts)
- [BilReminder Schema](../schema/money/bilReminder.ts)
- [Account Schema](../schema/money/account.ts)

---

## 🔗 参考

- [Zod 文档](https://zod.dev/)
- [TypeScript 类型系统最佳实践](https://www.typescriptlang.org/docs/handbook/2/types-from-types.html)
- [前端数据验证策略](https://martinfowler.com/articles/data-validation.html)
