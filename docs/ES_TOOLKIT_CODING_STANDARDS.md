# ES-Toolkit 代码规范

> Miji 项目工具函数使用规范  
> 版本：1.0.0  
> 最后更新：2025-11-30

---

## 📋 目录

1. [总则](#总则)
2. [对象操作](#对象操作)
3. [数组操作](#数组操作)
4. [字符串操作](#字符串操作)
5. [缓存策略](#缓存策略)
6. [性能优化](#性能优化)
7. [禁止使用](#禁止使用)
8. [最佳实践](#最佳实践)

---

## 总则

### 原则

1. **优先使用工具函数** - 避免重复造轮子
2. **类型安全第一** - 充分利用 TypeScript
3. **性能优先** - 使用经过优化的实现
4. **可读性** - 代码应该易于理解和维护

### 导入规范

```typescript
// ✅ 推荐：按需导入
import { deepClone, deepMerge } from '@/utils/objectUtils';
import { uniqueArrayBy, groupArrayBy } from '@/utils/arrayUtils';
import { debounce, throttle } from 'es-toolkit';

// ❌ 避免：默认导入或全量导入
import * as utils from '@/utils/objectUtils';
import objectUtils from '@/utils/objectUtils';
```

---

## 对象操作

### 1. 深拷贝

#### ✅ 推荐

```typescript
import { deepClone } from '@/utils/objectUtils';

const copy = deepClone(original);
const formData = deepClone(defaultFormData);
```

#### ❌ 禁止

```typescript
// ❌ 不安全，无法处理 Date、RegExp 等
const copy = JSON.parse(JSON.stringify(original));

// ❌ 浅拷贝，无法处理嵌套对象
const copy = { ...original };
const copy = Object.assign({}, original);
```

### 2. 对象合并

#### ✅ 推荐

```typescript
import { deepMerge } from '@/utils/objectUtils';

// 深度合并多个对象
const config = deepMerge(defaultConfig, userConfig, envConfig);

// 合并配置
const finalConfig = deepMerge(
  { theme: 'light', fontSize: 14 },
  { theme: 'dark' },
  { sidebar: { collapsed: true } }
);
// 结果: { theme: 'dark', fontSize: 14, sidebar: { collapsed: true } }
```

#### ⚠️ 注意

```typescript
// ⚠️ 浅合并，嵌套对象会被覆盖
const config = { ...defaults, ...user };

// ⚠️ 只适用于浅层合并
const config = Object.assign({}, defaults, user);
```

### 3. 字段选择/排除

#### ✅ 推荐

```typescript
import { pickFields, omitFields } from '@/utils/objectUtils';

// 只选择需要的字段
const publicUser = pickFields(user, ['id', 'name', 'email']);

// 排除敏感字段
const safeData = omitFields(data, ['password', 'secretKey', 'token']);

// API 发送前清理
const payload = omitFields(formData, ['createdAt', 'updatedAt']);
```

#### ❌ 避免

```typescript
// ❌ 手动构建，容易遗漏字段
const publicUser = {
  id: user.id,
  name: user.name,
  email: user.email
};

// ❌ delete 会修改原对象
delete user.password;
```

### 4. 对象比较

#### ✅ 推荐

```typescript
import { deepEqual, isEmptyValue } from '@/utils/objectUtils';

// 深度比较
if (deepEqual(formData, originalData)) {
  console.log('数据未改变');
}

// 检查是否为空
if (isEmptyValue(obj)) {
  console.log('对象为空');
}
```

#### ❌ 避免

```typescript
// ❌ 只能比较基本类型
if (obj1 === obj2) { }

// ❌ 不可靠
if (JSON.stringify(obj1) === JSON.stringify(obj2)) { }
```

---

## 数组操作

### 1. 数组去重

#### ✅ 推荐

```typescript
import { uniqueArray, uniqueArrayBy } from '@/utils/arrayUtils';

// 基本类型去重
const unique = uniqueArray([1, 2, 2, 3, 3]);

// 按属性去重
const uniqueUsers = uniqueArrayBy(users, 'id');
const uniqueUsers = uniqueArrayBy(users, u => u.id);

// 按多个字段去重
const uniqueItems = uniqueArrayBy(items, i => `${i.name}-${i.date}`);
```

#### ⚠️ 注意

```typescript
// ⚠️ 简单但不适用于对象
const unique = [...new Set(arr)];

// ⚠️ 性能较差
const unique = arr.filter((item, index) => arr.indexOf(item) === index);
```

### 2. 数组分组

#### ✅ 推荐

```typescript
import { groupArrayBy } from '@/utils/arrayUtils';

// 按字段分组
const grouped = groupArrayBy(transactions, 'category');

// 按条件分组
const grouped = groupArrayBy(transactions, t => 
  t.amount > 1000 ? 'large' : 'small'
);

// 按日期分组
const grouped = groupArrayBy(records, r => 
  r.date.substring(0, 7) // "2025-11"
);
```

#### ❌ 避免

```typescript
// ❌ 手写 reduce，容易出错
const grouped = transactions.reduce((acc, t) => {
  if (!acc[t.category]) acc[t.category] = [];
  acc[t.category].push(t);
  return acc;
}, {});
```

### 3. 数组排序

#### ✅ 推荐

```typescript
import { sortArray } from '@/utils/arrayUtils';

// 单字段排序
const sorted = sortArray(users, ['age']);

// 多字段排序
const sorted = sortArray(users, ['age', 'name']);

// 自定义排序
const sorted = sortArray(users, [
  u => u.age,
  u => u.name.toLowerCase()
]);
```

#### ⚠️ 注意

```typescript
// ⚠️ 会修改原数组
arr.sort((a, b) => a - b);

// ✅ 不修改原数组
const sorted = [...arr].sort((a, b) => a - b);
```

### 4. 数组统计

#### ✅ 推荐

```typescript
import { sumArray, averageArray, sumBy, averageBy } from '@/utils/arrayUtils';

// 数字数组统计
const total = sumArray([10, 20, 30]); // 60
const avg = averageArray([10, 20, 30]); // 20

// 对象数组统计
const totalAmount = sumBy(transactions, 'amount');
const avgAge = averageBy(users, 'age');

// 查找最大/最小
import { maxBy, minBy } from '@/utils/arrayUtils';
const oldest = maxBy(users, 'age');
const youngest = minBy(users, 'age');
```

#### ❌ 避免

```typescript
// ❌ 手写 reduce
const total = transactions.reduce((sum, t) => sum + t.amount, 0);
```

### 5. 数组分区

#### ✅ 推荐

```typescript
import { partitionArray } from '@/utils/arrayUtils';

// 分离有效/无效数据
const [valid, invalid] = partitionArray(items, i => i.isValid);

// 分离活跃/非活跃用户
const [activeUsers, inactiveUsers] = partitionArray(
  users,
  u => u.lastActiveAt > Date.now() - 30 * 24 * 60 * 60 * 1000
);
```

#### ❌ 避免

```typescript
// ❌ 遍历两次
const valid = items.filter(i => i.isValid);
const invalid = items.filter(i => !i.isValid);
```

### 6. 数组分块

#### ✅ 推荐

```typescript
import { chunkArray } from '@/utils/arrayUtils';

// 批量处理
const batches = chunkArray(largeArray, 100);
for (const batch of batches) {
  await processBatch(batch);
}

// 分页显示
const pages = chunkArray(items, 20);
```

---

## 字符串操作

### 1. 大小写转换

#### ✅ 推荐

```typescript
import { toCamelCase, toSnakeCase } from '@/utils/common';
import { camelCase, snakeCase, kebabCase, upperFirst } from 'es-toolkit';

// 对象键转换
const frontendData = toCamelCase(backendData);

// 字符串转换
const camel = camelCase('user_name');       // 'userName'
const snake = snakeCase('userName');         // 'user_name'
const kebab = kebabCase('userName');         // 'user-name'
const capitalized = upperFirst('hello');     // 'Hello'
```

#### ❌ 避免

```typescript
// ❌ 正则不全面
const snake = str.replace(/[A-Z]/g, l => `_${l.toLowerCase()}`);
```

---

## 缓存策略

### 1. API 请求缓存

#### ✅ 推荐

```typescript
import { createTTLCache } from '@/utils/cacheUtils';

// 用户数据缓存（5分钟）
const getUser = createTTLCache(
  async (id: string) => {
    return await MoneyDb.getUser(id);
  },
  5 * 60 * 1000
);

// 使用
const user = await getUser('123'); // 缓存 5 分钟
```

#### 使用场景

- ✅ 用户信息查询
- ✅ 配置数据获取
- ✅ 静态列表数据
- ❌ 实时数据
- ❌ 经常变化的数据

### 2. 计算结果缓存

#### ✅ 推荐

```typescript
import { memoizeFunction } from '@/utils/cacheUtils';

// 缓存昂贵的计算
const calculateScore = memoizeFunction((data: TransactionData[]) => {
  // 复杂计算
  return score;
});

// 多次调用，只计算一次
const score1 = calculateScore(data); // 计算
const score2 = calculateScore(data); // 从缓存返回
```

#### 使用场景

- ✅ 纯函数计算
- ✅ 数据转换
- ✅ 格式化操作
- ❌ 有副作用的函数
- ❌ 依赖外部状态

### 3. 只执行一次

#### ✅ 推荐

```typescript
import { onceFunction } from '@/utils/cacheUtils';

// 初始化函数只执行一次
const initialize = onceFunction(() => {
  console.log('Initializing...');
  // 初始化逻辑
});

initialize(); // 执行
initialize(); // 不执行
initialize(); // 不执行
```

---

## 性能优化

### 1. 防抖和节流

#### ✅ 推荐

```typescript
import { debounce, throttle } from 'es-toolkit';

// 防抖：停止触发后才执行
const debouncedSearch = debounce((query: string) => {
  searchAPI(query);
}, 300);

// 节流：固定时间间隔执行
const throttledScroll = throttle(() => {
  handleScroll();
}, 100);
```

#### 使用场景

**Debounce（防抖）:**
- ✅ 搜索输入
- ✅ 窗口 resize
- ✅ 表单验证
- ✅ 自动保存

**Throttle（节流）:**
- ✅ 滚动事件
- ✅ 鼠标移动
- ✅ 动画更新
- ✅ API 请求限流

### 2. 批量操作

#### ✅ 推荐

```typescript
import { chunkArray } from '@/utils/arrayUtils';

// 分批处理大量数据
const batches = chunkArray(largeDataset, 100);

for (const batch of batches) {
  await processBatch(batch);
  await new Promise(resolve => setTimeout(resolve, 100)); // 避免阻塞
}
```

---

## 禁止使用

### ❌ 绝对禁止

```typescript
// 1. JSON 深拷贝（不安全）
const copy = JSON.parse(JSON.stringify(obj));
// ✅ 使用 deepClone(obj)

// 2. eval（安全风险）
eval(code);
// ✅ 使用合适的替代方案

// 3. with（性能和可读性差）
with (obj) { }
// ✅ 直接访问对象属性
```

### ⚠️ 谨慎使用

```typescript
// 1. delete 操作符（性能差）
delete obj.prop;
// ✅ 使用 omitFields(obj, ['prop'])

// 2. for...in（性能差，需要 hasOwnProperty 检查）
for (const key in obj) {
  if (obj.hasOwnProperty(key)) { }
}
// ✅ 使用 Object.keys(obj).forEach() 或 for...of

// 3. 原型链修改（危险）
Array.prototype.myMethod = function() { };
// ✅ 使用工具函数包装
```

---

## 最佳实践

### 1. 类型安全

```typescript
// ✅ 充分利用 TypeScript
import { deepClone, deepMerge } from '@/utils/objectUtils';

interface User {
  id: string;
  name: string;
  email: string;
}

const user: User = { id: '1', name: 'Alice', email: 'alice@example.com' };
const copy: User = deepClone(user); // 类型安全
```

### 2. 错误处理

```typescript
// ✅ 添加错误处理
import { memoizeFunction } from '@/utils/cacheUtils';

const fetchData = memoizeFunction(async (id: string) => {
  try {
    return await api.getData(id);
  } catch (error) {
    console.error('Failed to fetch data:', error);
    throw error; // 或返回默认值
  }
});
```

### 3. 性能监控

```typescript
// ✅ 添加性能监控
const startTime = performance.now();
const result = expensiveOperation(data);
const endTime = performance.now();
console.log(`Operation took ${endTime - startTime}ms`);
```

### 4. 代码注释

```typescript
// ✅ 添加必要的注释
import { groupArrayBy, sumBy } from '@/utils/arrayUtils';

// 按月份分组交易记录并统计总金额
const monthlyStats = Object.entries(
  groupArrayBy(transactions, t => t.date.substring(0, 7))
).map(([month, items]) => ({
  month,
  total: sumBy(items, 'amount'),
  count: items.length,
}));
```

### 5. 单元测试

```typescript
import { describe, it, expect } from 'vitest';
import { deepClone, deepEqual } from '@/utils/objectUtils';

describe('objectUtils', () => {
  it('should deep clone objects', () => {
    const original = { a: 1, b: { c: 2 } };
    const cloned = deepClone(original);
    
    cloned.b.c = 3;
    expect(original.b.c).toBe(2);
    expect(cloned.b.c).toBe(3);
  });

  it('should compare objects deeply', () => {
    expect(deepEqual({ a: 1 }, { a: 1 })).toBe(true);
    expect(deepEqual({ a: 1 }, { a: 2 })).toBe(false);
  });
});
```

---

## 🔍 代码审查检查清单

### 对象操作

- [ ] 是否使用了 `JSON.parse(JSON.stringify())`？
- [ ] 深拷贝是否使用 `deepClone()`？
- [ ] 对象合并是否使用 `deepMerge()`？
- [ ] 字段过滤是否使用 `omitFields()` 或 `pickFields()`？

### 数组操作

- [ ] 数组去重是否使用 `uniqueArrayBy()`？
- [ ] 数组分组是否使用 `groupArrayBy()`？
- [ ] 数组统计是否使用 `sumBy()` / `averageBy()`？
- [ ] 是否有两次 `filter()` 可以合并为 `partitionArray()`？

### 缓存

- [ ] API 请求是否需要缓存？
- [ ] 昂贵的计算是否已缓存？
- [ ] 初始化函数是否使用 `onceFunction()`？

### 性能

- [ ] 是否使用了 `debounce` / `throttle`？
- [ ] 大量数据是否分批处理？
- [ ] 是否有性能瓶颈？

---

## 📚 参考资料

- [ES-Toolkit 官方文档](https://es-toolkit.slash.page/)
- [项目工具文档](../src/utils/README.md)
- [快速参考手册](./ES_TOOLKIT_QUICK_REFERENCE.md)
- [优化建议清单](./ES_TOOLKIT_OPTIMIZATION_SUGGESTIONS.md)

---

## 📝 变更日志

| 版本 | 日期 | 变更内容 |
|-----|------|---------|
| 1.0.0 | 2025-11-30 | 初始版本 |

---

**维护者**: 开发团队  
**审核者**: 技术负责人  
**生效日期**: 2025-12-01
