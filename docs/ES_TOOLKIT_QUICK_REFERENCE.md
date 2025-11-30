# ES-Toolkit 快速参考手册

> 快速查找常用的 es-toolkit 函数和使用方法

---

## 🚀 快速导入

```typescript
// 防抖节流
import { debounce, throttle } from 'es-toolkit';

// 对象操作
import { deepClone, deepMerge, pick, omit } from '@/utils/objectUtils';

// 数组操作
import { uniq, chunk, groupBy, sortBy } from 'es-toolkit';

// 字符串
import { camelCase, snakeCase, kebabCase } from 'es-toolkit';

// 类型检查
import { isPlainObject, isEmpty, isEqual } from 'es-toolkit/compat';
```

---

## 📖 常用函数速查

### 防抖节流

```typescript
// 防抖 - 停止触发后才执行
const debouncedFn = debounce(fn, 300);

// 节流 - 固定时间间隔执行
const throttledFn = throttle(fn, 1000);

// 取消执行
debouncedFn.cancel();
```

### 对象操作

```typescript
// 深拷贝
const copy = deepClone(original);

// 深度合并
const merged = deepMerge(obj1, obj2, obj3);

// 选择字段
const subset = pick(obj, ['id', 'name']);

// 排除字段
const filtered = omit(obj, ['password']);

// 深度比较
const same = deepEqual(a, b);

// 检查空值
const empty = isEmpty(value);
```

### 数组操作

```typescript
// 去重
const unique = uniq([1, 2, 2, 3]);
const uniqueBy = uniqBy(users, u => u.id);

// 分组
const grouped = groupBy(items, item => item.category);

// 排序
const sorted = sortBy(users, [u => u.age, 'name']);

// 分块
const chunks = chunk([1,2,3,4,5], 2); // [[1,2], [3,4], [5]]

// 分区
const [evens, odds] = partition([1,2,3,4], n => n % 2 === 0);
```

### 字符串操作

```typescript
// 驼峰命名
camelCase('hello_world'); // "helloWorld"

// 蛇形命名
snakeCase('helloWorld'); // "hello_world"

// 短横线命名
kebabCase('helloWorld'); // "hello-world"

// 首字母大写
upperFirst('hello'); // "Hello"
```

### 数学操作

```typescript
// 求和
sum([1, 2, 3, 4]); // 10

// 平均值
mean([1, 2, 3, 4]); // 2.5

// 限制范围
clamp(value, 0, 100); // 保证在 0-100 之间

// 随机数
random(1, 10); // 1-10 的随机整数
```

---

## 💡 使用场景

### 1. 搜索防抖

```typescript
import { debounce } from 'es-toolkit';

const debouncedSearch = debounce(async (query: string) => {
  const results = await searchAPI(query);
  updateResults(results);
}, 300);

// 在输入框中使用
onInput(event => debouncedSearch(event.target.value));
```

### 2. 表单数据管理

```typescript
import { deepClone, deepEqual } from '@/utils/objectUtils';

const originalData = ref(deepClone(props.data));
const formData = ref(deepClone(props.data));

const hasChanges = computed(() => 
  !deepEqual(formData.value, originalData.value)
);

function reset() {
  formData.value = deepClone(originalData.value);
}
```

### 3. API 数据清理

```typescript
import { omit, pick } from '@/utils/objectUtils';

// 发送前移除不需要的字段
const payload = omit(formData, ['id', 'createdAt', 'updatedAt']);

// 只提取需要显示的字段
const displayData = pick(user, ['name', 'email', 'avatar']);
```

### 4. 配置合并

```typescript
import { deepMerge } from '@/utils/objectUtils';

const defaultConfig = { theme: 'light', fontSize: 14 };
const userConfig = { fontSize: 16 };
const envConfig = { apiUrl: process.env.API_URL };

const config = deepMerge(defaultConfig, userConfig, envConfig);
```

### 5. 数据分组展示

```typescript
import { groupBy } from 'es-toolkit';

// 按类别分组交易记录
const transactionsByCategory = groupBy(
  transactions,
  t => t.category
);

// { food: [...], transport: [...], ... }
```

### 6. 列表去重

```typescript
import { uniqBy } from 'es-toolkit';

// 按 ID 去重
const uniqueUsers = uniqBy(users, user => user.id);

// 按多个字段去重
const uniqueItems = uniqBy(items, item => 
  `${item.name}-${item.date}`
);
```

---

## 🎯 项目特定用法

### Snake Case ↔ Camel Case 转换

```typescript
import { transformKeys } from '@/utils/objectUtils';
import { camelCase, snakeCase } from 'es-toolkit';

// 后端数据 → 前端
const frontendData = transformKeys(backendData, camelCase);

// 前端数据 → 后端
const backendData = transformKeys(frontendData, snakeCase);
```

### 敏感数据过滤

```typescript
import { omitFields } from '@/utils/objectUtils';

// API 响应过滤
function sanitizeUser(user: User) {
  return omitFields(user, ['password', 'secretKey', 'token']);
}
```

### 表单差异检测

```typescript
import { getObjectDiff } from '@/utils/objectUtils';

// 只提交变更的字段
const changes = getObjectDiff(originalData, formData);
if (Object.keys(changes).length > 0) {
  await updateAPI(changes);
}
```

---

## ⚡ 性能优化技巧

### 1. Memoization

```typescript
import { memoize } from 'es-toolkit';

// 缓存昂贵的计算
const expensiveCalc = memoize((input: number) => {
  // 复杂计算
  return result;
});
```

### 2. 节流滚动事件

```typescript
import { throttle } from 'es-toolkit';

const handleScroll = throttle(() => {
  console.log('Scrolled!');
}, 100);

window.addEventListener('scroll', handleScroll);
```

### 3. 批量更新

```typescript
import { chunk } from 'es-toolkit';

// 分批处理大量数据
const batches = chunk(largeArray, 100);
for (const batch of batches) {
  await processBatch(batch);
}
```

---

## 🔍 类型检查

```typescript
import { 
  isPlainObject, 
  isArray, 
  isEmpty, 
  isNil,
  isString,
  isNumber
} from 'es-toolkit/compat';

if (isPlainObject(value)) { /* ... */ }
if (isEmpty(array)) { /* ... */ }
if (!isNil(value)) { /* ... */ }
```

---

## 🆚 对比 Lodash

| 功能 | Lodash | ES-Toolkit |
|-----|--------|-----------|
| `_.cloneDeep` | ✅ | `deepClone` |
| `_.merge` | ✅ | `deepMerge` |
| `_.debounce` | ✅ | `debounce` |
| `_.throttle` | ✅ | `throttle` |
| `_.pick` | ✅ | `pick` |
| `_.omit` | ✅ | `omit` |
| `_.isEqual` | ✅ | `isEqual` |
| `_.isEmpty` | ✅ | `isEmpty` |
| `_.camelCase` | ✅ | `camelCase` |
| `_.snakeCase` | ✅ | `snakeCase` |
| 包体积 | ~70KB | **~5KB** |
| Tree-shaking | ⚠️ 部分 | ✅ 完全 |
| TypeScript | ✅ | ✅✅ 更好 |

---

## 📚 更多资源

- **官方文档**: https://es-toolkit.slash.page/
- **API 参考**: https://es-toolkit.slash.page/reference/introduction.html
- **项目工具文档**: [src/utils/README.md](../src/utils/README.md)
- **阶段一总结**: [ES_TOOLKIT_PHASE1_SUMMARY.md](./ES_TOOLKIT_PHASE1_SUMMARY.md)

---

## 🤝 贡献

如果发现新的有用函数或使用模式，请：
1. 添加到 `objectUtils.ts`
2. 更新此文档
3. 添加使用示例

---

**最后更新**: 2025-11-30
