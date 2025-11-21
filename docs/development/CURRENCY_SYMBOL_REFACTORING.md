# 货币符号获取优化

## 📋 问题

在 `MoneyView.vue` 中存在硬编码的 `getCurrencySymbol` 函数：

```typescript
// ❌ 旧实现：硬编码货币符号
function getCurrencySymbol(currencyCode: string): string {
  switch (currencyCode) {
    case 'CNY':
      return '¥';
    case 'USD':
      return '$';
    case 'EUR':
      return '€';
    case 'GBP':
      return '£';
    case 'JPY':
      return '¥';
    default:
      return currencyCode;
  }
}
```

### 问题分析

1. **数据重复**：货币符号已经存储在数据库和 currency-store 中
2. **维护困难**：添加新货币需要修改多处代码
3. **不一致风险**：硬编码符号可能与数据库不一致
4. **扩展性差**：无法支持用户自定义货币符号

---

## ✅ 解决方案

使用 `currency-store` 的 `getCurrencyByCode` getter 获取货币符号。

### 新实现

```typescript
// ✅ 新实现：从 currency-store 获取
import { useCurrencyStore } from '@/stores/money';

const currencyStore = useCurrencyStore();

function getCurrencySymbol(currencyCode: string): string {
  const currency = currencyStore.getCurrencyByCode(currencyCode);
  return currency?.symbol || currencyCode;
}
```

---

## 🔧 修改内容

### 文件：`src/features/money/views/MoneyView.vue`

#### 1. 导入 useCurrencyStore

```typescript
// 变更前
import { useAccountStore, useCategoryStore } from '@/stores/money';

// 变更后
import { useAccountStore, useCategoryStore, useCurrencyStore } from '@/stores/money';
```

#### 2. 初始化 currencyStore

```typescript
const accountStore = useAccountStore();
const categoryStore = useCategoryStore();
const currencyStore = useCurrencyStore();  // ✅ 新增
```

#### 3. 简化 getCurrencySymbol 函数

```typescript
// 变更前（16行）
function getCurrencySymbol(currencyCode: string): string {
  switch (currencyCode) {
    case 'CNY':
      return '¥';
    case 'USD':
      return '$';
    case 'EUR':
      return '€';
    case 'GBP':
      return '£';
    case 'JPY':
      return '¥';
    default:
      return currencyCode;
  }
}

// 变更后（3行）
function getCurrencySymbol(currencyCode: string): string {
  const currency = currencyStore.getCurrencyByCode(currencyCode);
  return currency?.symbol || currencyCode;
}
```

---

## 📊 优势对比

| 维度 | 旧实现 | 新实现 |
|------|--------|--------|
| **代码行数** | 16 行 | 3 行 |
| **数据来源** | 硬编码 | 数据库 + Store |
| **可维护性** | ❌ 差 | ✅ 好 |
| **扩展性** | ❌ 差 | ✅ 好 |
| **一致性** | ⚠️ 可能不一致 | ✅ 保证一致 |
| **支持自定义** | ❌ 不支持 | ✅ 支持 |

---

## 🎯 优势

### 1. 单一数据源

```typescript
// 货币数据统一从数据库获取
// 通过 currency-store 管理
// 无需在多处维护
```

### 2. 自动同步

```typescript
// 数据库中的货币符号更新后
// currency-store 自动同步
// 所有使用该符号的地方自动更新
```

### 3. 支持扩展

```typescript
// 用户可以添加自定义货币
await currencyStore.createCurrency({
  code: 'BTC',
  locale: 'en-US',
  symbol: '₿',  // 自定义符号
});

// getCurrencySymbol('BTC') 自动返回 '₿'
```

### 4. 类型安全

```typescript
// currency-store 提供类型安全的 getter
const currency: Currency | undefined = currencyStore.getCurrencyByCode(code);
```

---

## 🧪 测试

### 单元测试

```typescript
import { describe, it, expect, beforeEach } from 'vitest';
import { setActivePinia, createPinia } from 'pinia';
import { useCurrencyStore } from '@/stores/money';

describe('getCurrencySymbol', () => {
  beforeEach(() => {
    setActivePinia(createPinia());
  });

  it('should return currency symbol from store', () => {
    const currencyStore = useCurrencyStore();
    
    // 模拟货币数据
    currencyStore.currencies = [
      { code: 'CNY', symbol: '¥', locale: 'zh-CN', isActive: true },
      { code: 'USD', symbol: '$', locale: 'en-US', isActive: true },
    ];

    expect(getCurrencySymbol('CNY')).toBe('¥');
    expect(getCurrencySymbol('USD')).toBe('$');
  });

  it('should return code if currency not found', () => {
    const currencyStore = useCurrencyStore();
    currencyStore.currencies = [];

    expect(getCurrencySymbol('XYZ')).toBe('XYZ');
  });
});
```

### 集成测试

```typescript
describe('MoneyView - Currency Symbol', () => {
  it('should display correct currency symbol in cards', async () => {
    const wrapper = mount(MoneyView);
    await currencyStore.fetchCurrencies();

    const totalAssetsCard = wrapper.find('[data-testid="total-assets"]');
    expect(totalAssetsCard.text()).toContain('¥');
  });
});
```

---

## 📈 性能影响

### 内存

- **旧实现**：无额外内存开销（硬编码）
- **新实现**：复用 currency-store 缓存，无额外开销

### 执行速度

- **旧实现**：O(1) switch 语句
- **新实现**：O(n) 数组查找（n 为货币数量，通常 < 10）
- **结论**：性能差异可忽略（< 1ms）

### 网络请求

- **旧实现**：无网络请求
- **新实现**：复用 currency-store 的缓存机制（30分钟过期）
- **结论**：无额外网络开销

---

## 🔍 相关代码

### currency-store.ts

```typescript
getters: {
  /**
   * 根据货币代码获取货币
   */
  getCurrencyByCode: state => (code: string) => {
    return state.currencies.find(c => c.code === code);
  },
}
```

### 使用示例

```typescript
// 在任何组件中使用
import { useCurrencyStore } from '@/stores/money';

const currencyStore = useCurrencyStore();

// 获取货币符号
const symbol = currencyStore.getCurrencyByCode('CNY')?.symbol;  // '¥'

// 获取完整货币信息
const currency = currencyStore.getCurrencyByCode('USD');
console.log(currency);
// {
//   code: 'USD',
//   symbol: '$',
//   locale: 'en-US',
//   isDefault: false,
//   isActive: true,
//   createdAt: '...',
//   updatedAt: '...'
// }
```

---

## 🚀 后续优化建议

### 1. 创建通用工具函数

```typescript
// src/utils/currency.ts
import { useCurrencyStore } from '@/stores/money';

/**
 * 获取货币符号
 * @param currencyCode 货币代码
 * @returns 货币符号或代码
 */
export function getCurrencySymbol(currencyCode: string): string {
  const currencyStore = useCurrencyStore();
  const currency = currencyStore.getCurrencyByCode(currencyCode);
  return currency?.symbol || currencyCode;
}

/**
 * 格式化金额（带货币符号）
 * @param amount 金额
 * @param currencyCode 货币代码
 * @returns 格式化后的金额字符串
 */
export function formatAmountWithSymbol(amount: number, currencyCode: string): string {
  const symbol = getCurrencySymbol(currencyCode);
  return `${symbol}${amount.toFixed(2)}`;
}
```

### 2. 使用 Composable

```typescript
// src/composables/useCurrency.ts
import { useCurrencyStore } from '@/stores/money';

export function useCurrency() {
  const currencyStore = useCurrencyStore();

  const getCurrencySymbol = (code: string) => {
    return currencyStore.getCurrencyByCode(code)?.symbol || code;
  };

  const formatAmount = (amount: number, code: string) => {
    const symbol = getCurrencySymbol(code);
    return `${symbol}${amount.toFixed(2)}`;
  };

  return {
    getCurrencySymbol,
    formatAmount,
  };
}
```

### 3. 全局注册

```typescript
// src/main.ts
import { getCurrencySymbol } from '@/utils/currency';

app.config.globalProperties.$getCurrencySymbol = getCurrencySymbol;

// 在模板中使用
<template>
  <div>{{ $getCurrencySymbol('CNY') }}100.00</div>
</template>
```

---

## 📚 相关文档

- [Currency Store](../../src/stores/money/currency-store.ts)
- [实体引用系统重构](./ENTITY_REFACTORING_SUMMARY.md)
- [Currency 迁移文档](./CURRENCY_FLAGS_MIGRATION.md)

---

## 🎉 总结

通过这次优化：

✅ **减少代码**：从 16 行减少到 3 行  
✅ **提升可维护性**：单一数据源，易于维护  
✅ **增强扩展性**：支持用户自定义货币  
✅ **保证一致性**：数据库与显示保持一致  
✅ **性能无损**：复用缓存，无额外开销

这是一个典型的"不要重复自己"（DRY）原则的应用案例。

---

**优化日期**：2025-11-21  
**版本**：1.0.0  
**状态**：✅ 完成
