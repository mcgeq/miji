# Utils 工具函数库

## 📚 文件说明

### objectUtils.ts - 对象工具函数
基于 `es-toolkit` 提供的通用对象操作工具。

### arrayUtils.ts - 数组工具函数
基于 `es-toolkit` 提供的数组操作、统计和分组工具。

### cacheUtils.ts - 缓存工具函数
基于 `es-toolkit` 的函数缓存和 TTL/LRU 缓存实现。

### common.ts - 通用工具函数
包含大小写转换、数组安全访问等常用工具（已使用 es-toolkit 优化）。

#### 主要功能

##### 1. 深拷贝
```typescript
import { deepClone } from '@/utils/objectUtils';

const original = { a: 1, b: { c: 2 } };
const copied = deepClone(original);
copied.b.c = 3;
console.log(original.b.c); // 2 (原对象不受影响)
```

##### 2. 对象合并
```typescript
import { deepMerge } from '@/utils/objectUtils';

const defaults = { theme: 'light', sidebar: { width: 200 } };
const userConfig = { sidebar: { collapsed: true } };
const config = deepMerge(defaults, userConfig);
// { theme: 'light', sidebar: { width: 200, collapsed: true } }
```

##### 3. 字段选择/排除
```typescript
import { pickFields, omitFields } from '@/utils/objectUtils';

const user = {
  id: 1,
  name: 'Alice',
  email: 'alice@example.com',
  password: 'secret123',
  createdAt: '2025-01-01'
};

// 只选择公开字段
const publicUser = pickFields(user, ['id', 'name', 'email']);
// { id: 1, name: 'Alice', email: 'alice@example.com' }

// 排除敏感字段
const safeUser = omitFields(user, ['password']);
// { id: 1, name: 'Alice', email: 'alice@example.com', createdAt: '2025-01-01' }
```

##### 4. 键值转换
```typescript
import { transformKeys, transformValues } from '@/utils/objectUtils';
import { camelCase, snakeCase } from 'es-toolkit';

// 转换键名
const dbData = { user_name: 'Alice', created_at: '2025-01-01' };
const frontendData = transformKeys(dbData, camelCase);
// { userName: 'Alice', createdAt: '2025-01-01' }

// 转换值
const prices = { apple: 10, banana: 5, orange: 8 };
const discounted = transformValues(prices, (price) => price * 0.9);
// { apple: 9, banana: 4.5, orange: 7.2 }
```

##### 5. 对象比较
```typescript
import { deepEqual, isEmptyValue } from '@/utils/objectUtils';

deepEqual({ a: 1, b: { c: 2 } }, { a: 1, b: { c: 2 } }); // true
deepEqual([1, 2, 3], [1, 2, 3]); // true

isEmptyValue({}); // true
isEmptyValue([]); // true
isEmptyValue(''); // true
isEmptyValue({ a: 1 }); // false
```

##### 6. 对象差异
```typescript
import { getObjectDiff } from '@/utils/objectUtils';

const oldUser = { id: 1, name: 'Alice', email: 'old@example.com' };
const newUser = { id: 1, name: 'Alice', email: 'new@example.com' };
const changes = getObjectDiff(oldUser, newUser);
// { email: 'new@example.com' }
```

##### 7. 对象扁平化
```typescript
import { flattenObject, unflattenObject } from '@/utils/objectUtils';

const nested = { 
  user: { 
    profile: { name: 'Alice' },
    settings: { theme: 'dark' }
  }
};

const flat = flattenObject(nested);
// { 'user.profile.name': 'Alice', 'user.settings.theme': 'dark' }

const recovered = unflattenObject(flat);
// { user: { profile: { name: 'Alice' }, settings: { theme: 'dark' } } }
```

##### 8. 安全更新
```typescript
import { safeUpdate } from '@/utils/objectUtils';

const user = { id: 1, name: 'Alice' };
const updated = safeUpdate(user, { name: 'Bob', invalidField: 'test' });
// { id: 1, name: 'Bob' } (invalidField 被忽略)
```

---

## 🎯 使用建议

### 在 Composables 中使用
```typescript
// composables/useFormData.ts
import { deepClone, deepEqual } from '@/utils/objectUtils';

export function useFormData<T>(initialData: T) {
  const formData = ref(deepClone(initialData));
  const originalData = ref(deepClone(initialData));
  
  const hasChanges = computed(() => {
    return !deepEqual(formData.value, originalData.value);
  });
  
  function reset() {
    formData.value = deepClone(originalData.value);
  }
  
  return { formData, hasChanges, reset };
}
```

### 在 API 层使用
```typescript
// api/userApi.ts
import { omitFields } from '@/utils/objectUtils';

export async function updateUser(user: User) {
  // 移除不应发送到后端的字段
  const payload = omitFields(user, ['createdAt', 'updatedAt', 'password']);
  return await invokeCommand('update_user', payload);
}
```

### 在配置管理中使用
```typescript
// config/appConfig.ts
import { deepMerge } from '@/utils/objectUtils';

const defaultConfig = { /* ... */ };
const userConfig = getUserPreferences();
export const appConfig = deepMerge(defaultConfig, userConfig);
```

---

## 🔢 数组工具使用

### arrayUtils.ts

```typescript
import {
  uniqueArray,
  groupArrayBy,
  sortArray,
  partitionArray,
  chunkArray,
  sumArray,
  averageArray
} from '@/utils/arrayUtils';

// 数组去重
const unique = uniqueArray([1, 2, 2, 3, 3]); // [1, 2, 3]

// 按属性去重
const users = [
  { id: 1, name: 'Alice' },
  { id: 2, name: 'Bob' },
  { id: 1, name: 'Alice Dup' }
];
const uniqueUsers = uniqueArrayBy(users, 'id'); // 按 id 去重

// 数组分组
const transactions = [
  { category: 'food', amount: 100 },
  { category: 'transport', amount: 50 },
  { category: 'food', amount: 200 }
];
const grouped = groupArrayBy(transactions, 'category');
// { food: [两条记录], transport: [一条记录] }

// 多条件排序
const sorted = sortArray(users, ['age', 'name']);

// 数组分区
const numbers = [1, 2, 3, 4, 5, 6];
const [evens, odds] = partitionArray(numbers, n => n % 2 === 0);
// evens: [2, 4, 6], odds: [1, 3, 5]

// 数组分块
const chunks = chunkArray([1, 2, 3, 4, 5], 2);
// [[1, 2], [3, 4], [5]]

// 统计计算
const total = sumArray([10, 20, 30]); // 60
const avg = averageArray([10, 20, 30]); // 20

// 按属性统计
const transTotal = sumBy(transactions, 'amount'); // 350
```

---

## 💾 缓存工具使用

### cache/ (统一缓存系统)

```typescript
import {
  // 全局缓存实例
  globalCache,
  apiCache,
  cacheKeys,
  // 函数缓存工具
  memoizeFunction,
  onceFunction,
  createTTLCache,
  createLRUCache,
  createRefreshableCache
} from '@/utils/cache';

// 1. 函数结果缓存
const expensiveCalc = memoizeFunction((n: number) => {
  console.log('Computing...');
  return n * n;
});
expensiveCalc(5); // 输出 "Computing..." 返回 25
expensiveCalc(5); // 直接返回 25（缓存）

// 2. 只执行一次
const initialize = onceFunction(() => {
  console.log('Initializing...');
  return { initialized: true };
});
initialize(); // 输出 "Initializing..."
initialize(); // 什么都不做

// 3. TTL 缓存（带过期时间）
const fetchUser = createTTLCache(
  async (id: string) => {
    const response = await fetch(`/api/users/${id}`);
    return response.json();
  },
  5 * 60 * 1000 // 5分钟缓存
);
await fetchUser('123'); // 实际请求
await fetchUser('123'); // 从缓存返回（5分钟内）

// 4. LRU 缓存（最近最少使用）
const getData = createLRUCache(
  async (id: string) => {
    return fetch(`/api/data/${id}`).then(r => r.json());
  },
  100 // 最多缓存 100 个结果
);
await getData('abc');
console.log(getData.size()); // 查看缓存大小
getData.clear(); // 清除缓存

// 5. 可刷新缓存
const { execute, refresh, clear } = createRefreshableCache(
  async () => fetch('/api/config').then(r => r.json()),
  10 * 60 * 1000, // 10分钟缓存
  5 * 60 * 1000   // 5分钟自动刷新
);

const config = await execute(); // 获取配置
await refresh(); // 手动刷新
clear(); // 清除缓存
```

---

## ⚡ 性能优化

### 1. 使用 debounce/throttle
```typescript
import { debounce, throttle } from 'es-toolkit';

// 防抖搜索
const debouncedSearch = debounce(searchFunction, 300);

// 节流滚动
const throttledScroll = throttle(handleScroll, 100);
```

### 2. 使用 memoize 缓存计算结果
```typescript
import { memoize } from 'es-toolkit';

const expensiveCalculation = memoize((input: number) => {
  // 复杂计算
  return input * 2;
});
```

---

## 📦 依赖

- **es-toolkit**: 现代化的 lodash 替代品
  - 更小的体积
  - 更好的 TypeScript 支持
  - Tree-shaking 友好
  - 移动端兼容

---

## 🔄 迁移指南

### 从自定义工具迁移

#### 替换自定义 debounce
```typescript
// ❌ 旧方式
function debounce(func, wait) {
  let timeout;
  return (...args) => {
    clearTimeout(timeout);
    timeout = setTimeout(() => func(...args), wait);
  };
}

// ✅ 新方式
import { debounce } from 'es-toolkit';
const debouncedFn = debounce(myFunction, 300);
```

#### 替换对象操作
```typescript
// ❌ 旧方式
const copied = JSON.parse(JSON.stringify(obj)); // 不安全

// ✅ 新方式
import { deepClone } from '@/utils/objectUtils';
const copied = deepClone(obj);
```

---

## 🧪 测试示例

```typescript
import { describe, it, expect } from 'vitest';
import { deepClone, deepEqual, deepMerge } from '@/utils/objectUtils';

describe('objectUtils', () => {
  it('should deep clone objects', () => {
    const original = { a: 1, b: { c: 2 } };
    const cloned = deepClone(original);
    cloned.b.c = 3;
    expect(original.b.c).toBe(2);
  });

  it('should deep merge objects', () => {
    const obj1 = { a: 1, b: { c: 2 } };
    const obj2 = { b: { d: 3 } };
    const merged = deepMerge(obj1, obj2);
    expect(merged).toEqual({ a: 1, b: { c: 2, d: 3 } });
  });

  it('should compare objects deeply', () => {
    expect(deepEqual({ a: 1 }, { a: 1 })).toBe(true);
    expect(deepEqual({ a: 1 }, { a: 2 })).toBe(false);
  });
});
```

---

## 📖 更多资源

- [es-toolkit 官方文档](https://es-toolkit.slash.page/)
- [API 参考](https://es-toolkit.slash.page/reference/introduction.html)
