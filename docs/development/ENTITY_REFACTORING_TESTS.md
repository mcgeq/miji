# 实体引用系统测试指南

## 📋 测试覆盖范围

### 1. Schema 验证测试
### 2. 组件集成测试
### 3. API 端到端测试

---

## 🧪 1. Schema 验证测试

### CategoryNameSchema 测试

```typescript
// tests/unit/schema/categoryName.spec.ts
import { describe, it, expect } from 'vitest';
import { CategoryNameSchema } from '@/schema/common';

describe('CategoryNameSchema', () => {
  describe('valid inputs', () => {
    it('should accept 2-character names', () => {
      expect(CategoryNameSchema.parse('AB')).toBe('AB');
    });

    it('should accept 20-character names', () => {
      const name = 'A'.repeat(20);
      expect(CategoryNameSchema.parse(name)).toBe(name);
    });

    it('should accept common category names', () => {
      const validNames = ['Food', 'Transport', 'Entertainment', 'Shopping'];
      validNames.forEach(name => {
        expect(CategoryNameSchema.parse(name)).toBe(name);
      });
    });

    it('should accept names with spaces', () => {
      expect(CategoryNameSchema.parse('Food & Drink')).toBe('Food & Drink');
    });

    it('should accept names with special characters', () => {
      expect(CategoryNameSchema.parse('Bills & Utilities')).toBe('Bills & Utilities');
    });
  });

  describe('invalid inputs', () => {
    it('should reject 1-character names', () => {
      expect(() => CategoryNameSchema.parse('A')).toThrow();
    });

    it('should reject names longer than 20 characters', () => {
      const name = 'A'.repeat(21);
      expect(() => CategoryNameSchema.parse(name)).toThrow();
    });

    it('should reject empty strings', () => {
      expect(() => CategoryNameSchema.parse('')).toThrow();
    });

    it('should reject null', () => {
      expect(() => CategoryNameSchema.parse(null)).toThrow();
    });

    it('should reject undefined', () => {
      expect(() => CategoryNameSchema.parse(undefined)).toThrow();
    });

    it('should reject numbers', () => {
      expect(() => CategoryNameSchema.parse(123)).toThrow();
    });

    it('should reject objects', () => {
      expect(() => CategoryNameSchema.parse({ name: 'Food' })).toThrow();
    });
  });
});
```

### SubCategoryNameSchema 测试

```typescript
// tests/unit/schema/subCategoryName.spec.ts
import { describe, it, expect } from 'vitest';
import { SubCategoryNameSchema } from '@/schema/common';

describe('SubCategoryNameSchema', () => {
  describe('valid inputs', () => {
    it('should accept valid subcategory names', () => {
      const validNames = ['Breakfast', 'Lunch', 'Dinner', 'Snacks'];
      validNames.forEach(name => {
        expect(SubCategoryNameSchema.parse(name)).toBe(name);
      });
    });

    it('should accept 2-20 character names', () => {
      expect(SubCategoryNameSchema.parse('AB')).toBe('AB');
      expect(SubCategoryNameSchema.parse('A'.repeat(20))).toBe('A'.repeat(20));
    });
  });

  describe('invalid inputs', () => {
    it('should reject too short names', () => {
      expect(() => SubCategoryNameSchema.parse('A')).toThrow();
    });

    it('should reject too long names', () => {
      expect(() => SubCategoryNameSchema.parse('A'.repeat(21))).toThrow();
    });
  });
});
```

---

## 🔧 2. 组件集成测试

### Transaction Modal 测试

```typescript
// tests/integration/components/TransactionModal.spec.ts
import { describe, it, expect, beforeEach } from 'vitest';
import { mount } from '@vue/test-utils';
import TransactionModal from '@/features/money/components/TransactionModal.vue';

describe('TransactionModal - Category Validation', () => {
  let wrapper;

  beforeEach(() => {
    wrapper = mount(TransactionModal, {
      props: {
        type: 'Expense',
        accounts: [],
      },
    });
  });

  it('should validate category name length', async () => {
    const categoryInput = wrapper.find('[data-testid="category-input"]');
    
    // 测试太短的名称
    await categoryInput.setValue('A');
    await wrapper.find('form').trigger('submit');
    
    expect(wrapper.find('.error-message').text()).toContain('at least 2 characters');
  });

  it('should accept valid category name', async () => {
    const categoryInput = wrapper.find('[data-testid="category-input"]');
    
    await categoryInput.setValue('Food');
    await wrapper.find('form').trigger('submit');
    
    expect(wrapper.find('.error-message').exists()).toBe(false);
  });

  it('should validate subcategory name when provided', async () => {
    const subCategoryInput = wrapper.find('[data-testid="subcategory-input"]');
    
    // 测试太短的名称
    await subCategoryInput.setValue('A');
    await wrapper.find('form').trigger('submit');
    
    expect(wrapper.find('.error-message').text()).toContain('at least 2 characters');
  });

  it('should allow null subcategory', async () => {
    const categoryInput = wrapper.find('[data-testid="category-input"]');
    
    await categoryInput.setValue('Food');
    // 不设置 subcategory
    await wrapper.find('form').trigger('submit');
    
    expect(wrapper.emitted('save')).toBeTruthy();
    expect(wrapper.emitted('save')[0][0].subCategory).toBeNull();
  });
});
```

### Budget Modal 测试

```typescript
// tests/integration/components/BudgetModal.spec.ts
import { describe, it, expect } from 'vitest';
import { mount } from '@vue/test-utils';
import BudgetModal from '@/features/money/components/BudgetModal.vue';

describe('BudgetModal - Category Scope Validation', () => {
  it('should validate category scope array', async () => {
    const wrapper = mount(BudgetModal, {
      props: {
        budget: null,
      },
    });

    const categoryScopeInput = wrapper.find('[data-testid="category-scope-input"]');
    
    // 测试包含无效分类名称的数组
    await categoryScopeInput.setValue(['Food', 'A', 'Transport']);
    await wrapper.find('form').trigger('submit');
    
    expect(wrapper.find('.error-message').text()).toContain('Invalid category');
  });

  it('should accept valid category scope array', async () => {
    const wrapper = mount(BudgetModal, {
      props: {
        budget: null,
      },
    });

    const categoryScopeInput = wrapper.find('[data-testid="category-scope-input"]');
    
    await categoryScopeInput.setValue(['Food', 'Transport', 'Entertainment']);
    await wrapper.find('form').trigger('submit');
    
    expect(wrapper.emitted('save')).toBeTruthy();
  });
});
```

---

## 🌐 3. API 端到端测试

### Transaction API 测试

```typescript
// tests/e2e/api/transaction.spec.ts
import { describe, it, expect } from 'vitest';
import { MoneyDb } from '@/services/money/money';

describe('Transaction API - Category Validation', () => {
  it('should reject transaction with invalid category', async () => {
    const invalidTransaction = {
      transactionType: 'Expense',
      amount: 100,
      accountSerialNum: 'test-account-id',
      category: 'A',  // 太短
      currency: 'CNY',
      date: new Date().toISOString(),
      transactionStatus: 'Completed',
      paymentMethod: 'Cash',
      actualPayerAccount: 'Cash',
    };

    await expect(
      MoneyDb.createTransaction(invalidTransaction)
    ).rejects.toThrow(/Category name must be at least 2 characters/);
  });

  it('should accept transaction with valid category', async () => {
    const validTransaction = {
      transactionType: 'Expense',
      amount: 100,
      accountSerialNum: 'test-account-id',
      category: 'Food',
      currency: 'CNY',
      date: new Date().toISOString(),
      transactionStatus: 'Completed',
      paymentMethod: 'Cash',
      actualPayerAccount: 'Cash',
    };

    const result = await MoneyDb.createTransaction(validTransaction);
    
    expect(result.category).toBe('Food');
    expect(result.serialNum).toBeDefined();
  });

  it('should accept transaction with valid subcategory', async () => {
    const transaction = {
      transactionType: 'Expense',
      amount: 100,
      accountSerialNum: 'test-account-id',
      category: 'Food',
      subCategory: 'Breakfast',
      currency: 'CNY',
      date: new Date().toISOString(),
      transactionStatus: 'Completed',
      paymentMethod: 'Cash',
      actualPayerAccount: 'Cash',
    };

    const result = await MoneyDb.createTransaction(transaction);
    
    expect(result.category).toBe('Food');
    expect(result.subCategory).toBe('Breakfast');
  });

  it('should accept transaction with null subcategory', async () => {
    const transaction = {
      transactionType: 'Expense',
      amount: 100,
      accountSerialNum: 'test-account-id',
      category: 'Food',
      subCategory: null,
      currency: 'CNY',
      date: new Date().toISOString(),
      transactionStatus: 'Completed',
      paymentMethod: 'Cash',
      actualPayerAccount: 'Cash',
    };

    const result = await MoneyDb.createTransaction(transaction);
    
    expect(result.category).toBe('Food');
    expect(result.subCategory).toBeNull();
  });
});
```

### Budget API 测试

```typescript
// tests/e2e/api/budget.spec.ts
import { describe, it, expect } from 'vitest';
import { MoneyDb } from '@/services/money/money';

describe('Budget API - Category Scope Validation', () => {
  it('should reject budget with invalid category scope', async () => {
    const invalidBudget = {
      name: 'Monthly Budget',
      description: 'Test budget',
      amount: 1000,
      currency: 'CNY',
      budgetScopeType: 'Category',
      categoryScope: ['Food', 'A', 'Transport'],  // 'A' 太短
      repeatPeriodType: 'Monthly',
      repeatPeriod: { type: 'Monthly', interval: 1, day: 1 },
      startDate: new Date().toISOString(),
      endDate: new Date().toISOString(),
      isActive: true,
      alertEnabled: false,
      color: '#FF0000',
    };

    await expect(
      MoneyDb.createBudget(invalidBudget)
    ).rejects.toThrow(/Category name must be at least 2 characters/);
  });

  it('should accept budget with valid category scope', async () => {
    const validBudget = {
      name: 'Monthly Budget',
      description: 'Test budget',
      amount: 1000,
      currency: 'CNY',
      budgetScopeType: 'Category',
      categoryScope: ['Food', 'Transport', 'Entertainment'],
      repeatPeriodType: 'Monthly',
      repeatPeriod: { type: 'Monthly', interval: 1, day: 1 },
      startDate: new Date().toISOString(),
      endDate: new Date().toISOString(),
      isActive: true,
      alertEnabled: false,
      color: '#FF0000',
    };

    const result = await MoneyDb.createBudget(validBudget);
    
    expect(result.categoryScope).toEqual(['Food', 'Transport', 'Entertainment']);
    expect(result.serialNum).toBeDefined();
  });
});
```

---

## 🎯 测试执行

### 运行所有测试

```bash
# 单元测试
npm run test:unit

# 集成测试
npm run test:integration

# E2E 测试
npm run test:e2e

# 所有测试
npm run test
```

### 运行特定测试

```bash
# 只测试 Schema
npm run test:unit -- schema

# 只测试 Transaction
npm run test -- transaction

# 只测试 Budget
npm run test -- budget
```

### 测试覆盖率

```bash
# 生成覆盖率报告
npm run test:coverage

# 查看覆盖率
open coverage/index.html
```

---

## 📊 测试清单

### Schema 层

- [x] CategoryNameSchema 验证
- [x] SubCategoryNameSchema 验证
- [x] Transaction Schema 集成
- [x] Budget Schema 集成
- [x] BilReminder Schema 集成

### 组件层

- [x] TransactionModal 分类验证
- [x] TransactionModal 子分类验证
- [x] BudgetModal 分类范围验证
- [x] ReminderModal 分类验证

### API 层

- [x] Transaction 创建验证
- [x] Transaction 更新验证
- [x] Budget 创建验证
- [x] Budget 更新验证
- [x] BilReminder 创建验证

---

## 🐛 已知问题

### 1. 中文分类名称

**问题**：中文字符计数可能不准确

**解决方案**：
```typescript
// 使用 grapheme 库正确计数
import { length } from 'grapheme-splitter';

const isValidLength = (name: string) => {
  const len = length(name);
  return len >= 2 && len <= 20;
};
```

### 2. 特殊字符

**问题**：某些特殊字符可能导致验证失败

**解决方案**：
```typescript
// 添加特殊字符白名单
const allowedSpecialChars = /^[\w\s&-]+$/;
```

---

## 📚 参考资料

- [Vitest 文档](https://vitest.dev/)
- [Vue Test Utils](https://test-utils.vuejs.org/)
- [Zod 验证](https://zod.dev/)

---

**更新日期**：2025-11-21  
**版本**：1.0.0
