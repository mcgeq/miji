# useMoneyStats Composable 使用指南

## 📋 概述

`useMoneyStats` 是一个用于生成资金统计卡片数据的 composable，封装了统计卡片的创建逻辑，使代码更加简洁和可维护。

---

## 🎯 为什么需要这个 Composable？

### 重构前的问题

在 `MoneyView.vue` 中，统计卡片的创建逻辑直接写在组件中：

```typescript
// ❌ 问题：50+ 行代码混在组件中
const statCards = computed<CardData[]>(() => [
  {
    id: 'total-assets',
    title: '总资产',
    value: formatCurrency(totalAssets.value),
    currency: getCurrencySymbol(baseCurrency.value),
    icon: 'wallet',
    color: 'primary' as const,
  },
  createComparisonCard(
    'monthly-income-comparison',
    '月度收入',
    formatCurrency(monthlyIncome.value),
    formatCurrency(prevMonthlyIncome.value),
    '上月',
    getCurrencySymbol(baseCurrency.value),
    'trending-up',
    'success',
  ),
  // ... 更多卡片
]);
```

**问题**：
1. **代码冗长**：50+ 行重复逻辑
2. **难以复用**：其他页面无法复用
3. **维护困难**：修改卡片结构需要改动多处
4. **职责不清**：组件既管理数据又管理展示逻辑

---

## ✅ 解决方案

### 重构后

```typescript
// ✅ 简洁：13 行代码
const { statCards } = useMoneyStats({
  totalAssets: totalAssets.value,
  monthlyIncome: monthlyIncome.value,
  prevMonthlyIncome: prevMonthlyIncome.value,
  yearlyIncome: yearlyIncome.value,
  prevYearlyIncome: prevYearlyIncome.value,
  monthlyExpense: monthlyExpense.value,
  prevMonthlyExpense: prevMonthlyExpense.value,
  yearlyExpense: yearlyExpense.value,
  prevYearlyExpense: prevYearlyExpense.value,
  baseCurrency: baseCurrency.value,
});
```

---

## 📦 API 文档

### 类型定义

```typescript
interface MoneyStatsData {
  totalAssets: number;           // 总资产
  monthlyIncome: number;          // 月度收入
  prevMonthlyIncome: number;      // 上月收入
  yearlyIncome: number;           // 年度收入
  prevYearlyIncome: number;       // 去年收入
  monthlyExpense: number;         // 月度支出
  prevMonthlyExpense: number;     // 上月支出
  yearlyExpense: number;          // 年度支出
  prevYearlyExpense: number;      // 去年支出
  baseCurrency: string;           // 基础货币代码（如 'CNY'）
}
```

### 参数

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `statsData` | `MoneyStatsData` | ✅ | 统计数据对象 |

### 返回值

```typescript
{
  statCards: ComputedRef<CardData[]>,  // 统计卡片数据（响应式）
  getCurrencySymbol: (code: string) => string  // 获取货币符号的工具函数
}
```

---

## 🚀 使用示例

### ⚠️ 重要：必须使用 computed 包裹数据

**错误用法**（数据不会响应式更新）：
```typescript
// ❌ 错误：传入 .value 只会获取初始值
const { statCards } = useMoneyStats({
  totalAssets: totalAssets.value,  // ❌ 只获取初始值 0
  monthlyIncome: monthlyIncome.value,
  // ...
});
// 当 totalAssets.value 更新时，statCards 不会更新！
```

**正确用法**（使用 computed 确保响应式）：
```typescript
import { computed } from 'vue';
import { useMoneyStats } from '@/composables/useMoneyStats';

// ✅ 正确：使用 computed 包裹
const { statCards } = useMoneyStats(computed(() => ({
  totalAssets: totalAssets.value,
  monthlyIncome: monthlyIncome.value,
  prevMonthlyIncome: prevMonthlyIncome.value,
  yearlyIncome: yearlyIncome.value,
  prevYearlyIncome: prevYearlyIncome.value,
  monthlyExpense: monthlyExpense.value,
  prevMonthlyExpense: prevMonthlyExpense.value,
  yearlyExpense: yearlyExpense.value,
  prevYearlyExpense: prevYearlyExpense.value,
  baseCurrency: baseCurrency.value,
})));

// 在模板中使用
<StackedStatCards :cards="statCards" />
```

### 为什么必须使用 computed？

```typescript
// 原理说明
const totalAssets = ref(0);

// ❌ 错误方式
const data1 = { value: totalAssets.value };  // 获取的是 0
totalAssets.value = 10000;  // data1.value 仍然是 0

// ✅ 正确方式
const data2 = computed(() => ({ value: totalAssets.value }));
totalAssets.value = 10000;  // data2.value.value 自动更新为 10000
```

### 获取货币符号

```typescript
const { getCurrencySymbol } = useMoneyStats(statsData);

const symbol = getCurrencySymbol('USD');  // '$'
const symbol2 = getCurrencySymbol('CNY'); // '¥'
```

---

## 🎨 生成的卡片结构

### 1. 总资产卡片

```typescript
{
  id: 'total-assets',
  title: '总资产',
  value: '¥10,000.00',
  currency: '¥',
  icon: 'wallet',
  color: 'primary',
}
```

### 2. 对比卡片（月度/年度收入/支出）

```typescript
{
  id: 'monthly-income-comparison',
  title: '月度收入',
  value: '¥5,000.00',
  previousValue: '¥4,500.00',
  comparisonLabel: '上月',
  currency: '¥',
  icon: 'trending-up',
  color: 'success',
  // 自动计算的字段
  change: 500,
  changePercent: 11.11,
  trend: 'up',
}
```

---

## 📊 优势对比

| 维度 | 重构前 | 重构后 |
|------|--------|--------|
| **代码行数** | 50+ 行 | 13 行 |
| **可复用性** | ❌ 不可复用 | ✅ 可复用 |
| **可维护性** | ⚠️ 难维护 | ✅ 易维护 |
| **职责分离** | ❌ 混杂 | ✅ 清晰 |
| **测试性** | ⚠️ 难测试 | ✅ 易测试 |

---

## 🧪 测试

### 单元测试

```typescript
import { describe, it, expect } from 'vitest';
import { useMoneyStats } from '@/composables/useMoneyStats';

describe('useMoneyStats', () => {
  it('should generate stat cards correctly', () => {
    const { statCards } = useMoneyStats({
      totalAssets: 10000,
      monthlyIncome: 5000,
      prevMonthlyIncome: 4500,
      yearlyIncome: 60000,
      prevYearlyIncome: 55000,
      monthlyExpense: 3000,
      prevMonthlyExpense: 2800,
      yearlyExpense: 36000,
      prevYearlyExpense: 33000,
      baseCurrency: 'CNY',
    });

    expect(statCards.value).toHaveLength(5);
    expect(statCards.value[0].id).toBe('total-assets');
    expect(statCards.value[0].title).toBe('总资产');
  });

  it('should get currency symbol correctly', () => {
    const { getCurrencySymbol } = useMoneyStats({
      totalAssets: 0,
      monthlyIncome: 0,
      prevMonthlyIncome: 0,
      yearlyIncome: 0,
      prevYearlyIncome: 0,
      monthlyExpense: 0,
      prevMonthlyExpense: 0,
      yearlyExpense: 0,
      prevYearlyExpense: 0,
      baseCurrency: 'CNY',
    });

    expect(getCurrencySymbol('CNY')).toBe('¥');
    expect(getCurrencySymbol('USD')).toBe('$');
  });
});
```

---

## 🔧 扩展建议

### 1. 支持自定义卡片

```typescript
interface UseMoneyStatsOptions {
  statsData: MoneyStatsData;
  customCards?: CardData[];  // 自定义卡片
  excludeCards?: string[];   // 排除的卡片 ID
}

export function useMoneyStats(options: UseMoneyStatsOptions) {
  // ...
}
```

### 2. 支持国际化

```typescript
import { useI18n } from 'vue-i18n';

export function useMoneyStats(statsData: MoneyStatsData) {
  const { t } = useI18n();

  const statCards = computed(() => [
    {
      id: 'total-assets',
      title: t('money.totalAssets'),  // 国际化
      // ...
    },
  ]);
}
```

### 3. 支持主题配置

```typescript
interface ThemeConfig {
  primaryColor?: string;
  successColor?: string;
  warningColor?: string;
}

export function useMoneyStats(
  statsData: MoneyStatsData,
  theme?: ThemeConfig
) {
  // 使用主题配置
}
```

---

## 📚 相关文档

- [货币符号获取优化](./CURRENCY_SYMBOL_REFACTORING.md)
- [实体引用系统重构](./ENTITY_REFACTORING_SUMMARY.md)
- [Composables 最佳实践](../frontend/COMPOSABLES_GUIDE.md)

---

## 🎉 总结

通过 `useMoneyStats` composable：

✅ **代码减少**：从 50+ 行减少到 13 行  
✅ **职责分离**：统计逻辑独立于组件  
✅ **可复用性**：其他页面可以直接使用  
✅ **易维护**：修改卡片结构只需改一处  
✅ **易测试**：可以独立测试统计逻辑

这是 Vue 3 Composition API 的最佳实践案例！

---

**创建日期**：2025-11-21  
**版本**：1.0.0  
**状态**：✅ 完成
