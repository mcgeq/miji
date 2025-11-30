# 前端工具函数优化分析报告

> 全面审查 src/utils 目录，提出合并优化建议  
> 分析时间：2025-11-30  
> 目标：提升维护性和可扩展性

---

## 📊 当前状况

### 工具文件统计（26 个文件）

| 文件 | 大小 | 函数数 | 状态 | 优先级 |
|-----|------|--------|------|--------|
| **数据处理** |
| arrayUtils.ts | 11.7 KB | 25 | ✅ 已优化 | - |
| objectUtils.ts | 7.4 KB | 12 | ✅ 已优化 | - |
| diff.ts | 6.6 KB | 2 | ✅ 已优化 | - |
| common.ts | 5.3 KB | 8 | ✅ 部分优化 | 🟡 中 |
| **缓存系统** |
| cacheUtils.ts | 8.0 KB | 8 | ✅ 已优化 | - |
| simpleCache.ts | 1.9 KB | 2 | 🔄 待合并 | 🔴 高 |
| apiHelper.ts | 7.9 KB | 7 | 🔄 有重复 | 🔴 高 |
| **日期时间** |
| date.ts | 18.6 KB | 1类 | 🔄 待优化 | 🟡 中 |
| **导出工具** |
| export.ts | 10.4 KB | 12 | 🔄 待优化 | 🟡 中 |
| **数据库** |
| dbUtils.ts | 27.5 KB | 3 | 🔄 待优化 | 🟢 低 |
| **其他工具** |
| sanitize.ts | 235 B | 1 | 🔄 可用 es-toolkit | 🔴 高 |
| user.ts | 334 B | 1 | 🔄 可用 objectUtils | 🟡 中 |
| transaction.ts | 775 B | 1 | ✅ 专用逻辑 | - |
| uuid.ts | 830 B | 1 | ✅ 专用逻辑 | - |
| **配置/UI** |
| reminderTypeConfig.ts | 14.8 KB | 10 | ✅ 业务配置 | - |
| echarts.ts | 5.9 KB | 4 | ✅ 专用工具 | - |
| splashscreen.ts | 5.7 KB | 4 | ✅ 专用工具 | - |
| errorPage.ts | 7.7 KB | 2 | ✅ 专用工具 | - |
| **空文件** |
| dataRoewwMapper.ts | 0 B | 0 | ❌ 删除 | 🔴 高 |
| periodDate.ts | 0 B | 0 | ❌ 删除 | 🔴 高 |

---

## 🔴 高优先级优化

### 1. 删除空文件 ⭐⭐⭐

**问题**：存在无用的空文件，可能是拼写错误或未使用

```bash
# 删除文件
src/utils/dataRoewwMapper.ts  # 0 字节
src/utils/periodDate.ts        # 0 字节
```

**操作**：
```bash
rm src/utils/dataRoewwMapper.ts
rm src/utils/periodDate.ts
```

### 2. 合并缓存工具 ⭐⭐⭐

**问题**：`simpleCache.ts`、`apiHelper.ts` 和 `cacheUtils.ts` 存在重复功能

#### 当前情况

**simpleCache.ts** - 全局数据缓存
```typescript
class SimpleCache {
  private cache = new Map<string, CacheEntry>();
  // TTL缓存实现
  set(key: string, data: any, ttl?: number): void
  get(key: string): any | null
}
export const globalCache = new SimpleCache();
```

**apiHelper.ts** - API 请求缓存
```typescript
class ApiCache {
  private cache: Map<string, CacheEntry<any>> = new Map();
  // 几乎相同的实现！
  get<T>(key: string): T | null
  set<T>(key: string, data: T, expiresIn: number): void
}
export const apiCache = new ApiCache();
```

**cacheUtils.ts** - 函数结果缓存
```typescript
export function createTTLCache<T>() {
  const cache = new Map<string, TTLCacheEntry<unknown>>();
  // 使用 es-toolkit 的 memoize
}
```

#### 优化方案：统一缓存系统

**新文件结构**：
```
src/utils/cache/
  ├── index.ts          # 统一导出
  ├── types.ts          # 类型定义
  ├── TTLCache.ts       # TTL 缓存基类
  ├── functions.ts      # 函数缓存（基于 es-toolkit）
  └── instances.ts      # 全局实例
```

**统一的 TTL 缓存基类**：
```typescript
// src/utils/cache/TTLCache.ts
import { isEqual } from 'es-toolkit';

export interface CacheOptions {
  defaultTTL?: number;
  maxSize?: number;
  onExpire?: (key: string, value: any) => void;
}

export class TTLCache<T = any> {
  private cache = new Map<string, { data: T; expiry: number }>();
  private options: Required<CacheOptions>;

  constructor(options: CacheOptions = {}) {
    this.options = {
      defaultTTL: options.defaultTTL ?? 5 * 60 * 1000,
      maxSize: options.maxSize ?? Infinity,
      onExpire: options.onExpire ?? (() => {}),
    };
  }

  set(key: string, data: T, ttl?: number): void {
    // LRU 驱逐策略
    if (this.cache.size >= this.options.maxSize) {
      const firstKey = this.cache.keys().next().value;
      if (firstKey) this.delete(firstKey);
    }

    const expiry = Date.now() + (ttl ?? this.options.defaultTTL);
    this.cache.set(key, { data, expiry });
  }

  get(key: string): T | null {
    const entry = this.cache.get(key);
    if (!entry) return null;

    if (Date.now() > entry.expiry) {
      this.options.onExpire(key, entry.data);
      this.cache.delete(key);
      return null;
    }

    return entry.data;
  }

  has(key: string): boolean {
    const value = this.get(key);
    return value !== null;
  }

  delete(key: string): boolean {
    return this.cache.delete(key);
  }

  clear(): void {
    this.cache.clear();
  }

  cleanup(): void {
    const now = Date.now();
    for (const [key, entry] of this.cache.entries()) {
      if (now > entry.expiry) {
        this.options.onExpire(key, entry.data);
        this.cache.delete(key);
      }
    }
  }

  size(): number {
    return this.cache.size;
  }

  keys(): string[] {
    return Array.from(this.cache.keys());
  }

  entries(): Array<[string, T]> {
    return Array.from(this.cache.entries())
      .filter(([_, entry]) => Date.now() <= entry.expiry)
      .map(([key, entry]) => [key, entry.data]);
  }
}
```

**全局缓存实例**：
```typescript
// src/utils/cache/instances.ts
import { TTLCache } from './TTLCache';

// 全局数据缓存
export const globalCache = new TTLCache({
  defaultTTL: 5 * 60 * 1000, // 5分钟
  maxSize: 100,
});

// API 请求缓存
export const apiCache = new TTLCache({
  defaultTTL: 5 * 60 * 1000, // 5分钟
  maxSize: 50,
});

// 缓存键生成器
export const cacheKeys = {
  familyLedgers: () => 'family_ledgers',
  familyLedger: (id: string) => `family_ledger:${id}`,
  familyMembers: (ledgerId?: string) =>
    ledgerId ? `family_members:${ledgerId}` : 'family_members',
  // ... 更多键
};

// 定期清理
setInterval(() => {
  globalCache.cleanup();
  apiCache.cleanup();
}, 60000);
```

**统一导出**：
```typescript
// src/utils/cache/index.ts
export { TTLCache } from './TTLCache';
export { globalCache, apiCache, cacheKeys } from './instances';
export {
  memoizeFunction,
  onceFunction,
  createTTLCache,
  createLRUCache,
  createRefreshableCache,
  CacheResult,
} from './functions';
export type { CacheOptions } from './TTLCache';
```

**工作量**：2-3 小时  
**收益**：
- ✅ 消除重复代码（~100 行）
- ✅ 统一缓存接口
- ✅ 更好的类型安全
- ✅ 支持 LRU 驱逐策略
- ✅ 支持过期回调

### 3. 优化 sanitize.ts ⭐⭐⭐

**问题**：手动实现 HTML 转义，es-toolkit 已提供

#### 当前代码
```typescript
// src/utils/sanitize.ts
export function escapeHTML(str: string): string {
  return str
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#039;');
}
```

#### 优化方案

**方案一：使用 es-toolkit**（推荐）
```typescript
// src/utils/sanitize.ts
import { escape, unescape } from 'es-toolkit';

export { escape as escapeHTML, unescape as unescapeHTML };

// 如果需要扩展其他清理功能
export function sanitizeInput(str: string): string {
  return escape(str).trim();
}
```

**方案二：删除文件，直接使用 es-toolkit**
```typescript
// 使用处直接导入
import { escape } from 'es-toolkit';
```

**工作量**：10 分钟  
**收益**：
- ✅ 使用优化实现
- ✅ 减少维护成本
- ✅ 性能更好

### 4. 简化 user.ts ⭐⭐

**问题**：简单的对象转换，可以使用 objectUtils

#### 当前代码
```typescript
// src/utils/user.ts
export function toAuthUser(user: User): AuthUser {
  return {
    serialNum: user.serialNum,
    name: user.name,
    email: user.email,
    avatarUrl: user.avatarUrl ?? null,
    role: user.role,
    timezone: user.timezone ?? 'UTC',
    language: user.language ?? 'en',
  };
}
```

#### 优化方案

**方案一：使用 pickFields + 默认值**
```typescript
// src/utils/user.ts
import { pickFields } from '@/utils/objectUtils';

export function toAuthUser(user: User): AuthUser {
  const picked = pickFields(user, [
    'serialNum',
    'name',
    'email',
    'avatarUrl',
    'role',
    'timezone',
    'language',
  ]);

  return {
    ...picked,
    avatarUrl: picked.avatarUrl ?? null,
    timezone: picked.timezone ?? 'UTC',
    language: picked.language ?? 'en',
  };
}
```

**方案二：使用 es-toolkit 的 pick**
```typescript
// src/utils/user.ts
import { pick } from 'es-toolkit';

export function toAuthUser(user: User): AuthUser {
  return {
    ...pick(user, [
      'serialNum',
      'name',
      'email',
      'role',
    ] as const),
    avatarUrl: user.avatarUrl ?? null,
    timezone: user.timezone ?? 'UTC',
    language: user.language ?? 'en',
  };
}
```

**方案三：移到 objectUtils 作为通用工具**
```typescript
// src/utils/objectUtils.ts
export function pickWithDefaults<T extends object, K extends keyof T>(
  obj: T,
  keys: K[],
  defaults: Partial<Pick<T, K>>,
): Pick<T, K> {
  const picked = pick(obj, keys);
  return { ...defaults, ...picked } as Pick<T, K>;
}

// 使用
const authUser = pickWithDefaults(user, [...], {
  avatarUrl: null,
  timezone: 'UTC',
  language: 'en',
});
```

**工作量**：30 分钟  
**收益**：
- ✅ 代码更简洁
- ✅ 可复用模式
- ✅ 类型安全

---

## 🟡 中优先级优化

### 5. 优化 common.ts ⭐⭐

**问题**：包含杂项函数，缺乏组织

#### 当前函数
```typescript
// src/utils/common.ts
export function toCamelCase<T>()        // ✅ 已用 es-toolkit
export function toSnakeCase()           // ✅ 已用 es-toolkit
export function buildRepeatPeriod()     // ✅ 业务逻辑
export function safeGet()               // ✅ 已用 es-toolkit
export function getRepeatTypeName()     // ✅ 业务逻辑
export function lowercaseFirstLetter()  // ✅ 已用 es-toolkit
```

#### 优化方案

**重构建议**：
1. ✅ 字符串转换已优化，保持现状
2. 🔄 业务逻辑函数移到专门的业务工具
3. 🔄 考虑重命名为 `stringUtils.ts` 或拆分

```typescript
// src/utils/string.ts (字符串工具)
export { toCamelCase, toSnakeCase, lowercaseFirstLetter } from './common';

// src/utils/business/repeat.ts (业务逻辑)
export { buildRepeatPeriod, getRepeatTypeName } from '@/utils/common';
```

**工作量**：1 小时  
**收益**：
- ✅ 更清晰的文件组织
- ✅ 易于查找和维护

### 6. 优化 export.ts ⭐⭐

**问题**：CSV 转义逻辑可以用 es-toolkit 简化

#### 当前代码
```typescript
// src/utils/export.ts
if (typeof value === 'string' && (value.includes(',') || value.includes('\n'))) {
  return `"${value.replace(/"/g, '""')}"`;
}
```

#### 优化方案

**使用 es-toolkit 的字符串工具**：
```typescript
// src/utils/export.ts
import { escape } from 'es-toolkit';

function escapeCSVValue(value: any): string {
  if (value == null) return '';
  
  const str = String(value);
  
  // 如果包含特殊字符，需要引号包裹
  if (str.includes(',') || str.includes('\n') || str.includes('"')) {
    return `"${str.replace(/"/g, '""')}"`;
  }
  
  return str;
}

export function exportToCSV(data: any[], filename: string, headers?: string[]) {
  const csvHeaders = headers || (data.length > 0 ? Object.keys(data[0]) : []);
  
  const csvContent = [
    csvHeaders.join(','),
    ...data.map(row =>
      csvHeaders
        .map(header => escapeCSVValue(row[header]))
        .join(','),
    ),
  ].join('\n');
  
  // ... 下载逻辑
}
```

**额外优化**：提取公共的下载逻辑
```typescript
// src/utils/export.ts
function downloadBlob(blob: Blob, filename: string): void {
  const url = URL.createObjectURL(blob);
  const link = document.createElement('a');
  link.href = url;
  link.download = filename;
  document.body.appendChild(link);
  link.click();
  document.body.removeChild(link);
  URL.revokeObjectURL(url);
}

export function exportToCSV(data: any[], filename: string, headers?: string[]) {
  // ... 生成CSV
  const blob = new Blob([`\uFEFF${csvContent}`], { 
    type: 'text/csv;charset=utf-8;' 
  });
  downloadBlob(blob, `${filename}.csv`);
}

export function exportToJSON(data: any, filename: string): void {
  const jsonStr = JSON.stringify(data, null, 2);
  const blob = new Blob([jsonStr], { type: 'application/json' });
  downloadBlob(blob, `${filename}.json`);
}
```

**工作量**：1 小时  
**收益**：
- ✅ 更清晰的代码结构
- ✅ 可复用的下载逻辑
- ✅ 易于扩展新格式

### 7. 优化 date.ts ⭐

**问题**：DateUtils 类很大，可能有些功能可以用 date-fns 替换

#### 当前情况
```typescript
// src/utils/date.ts
export class DateUtils {
  static getToday(): string
  static getTodayDate(): string
  static getLocalISODateTimeWithOffset(): string
  static getEndOfTodayISOWithOffset(): string
  static getDaysBetween(): number
  // ... 更多方法
}
```

#### 优化建议

**分析是否需要 date-fns**：
```typescript
// 如果项目中有复杂的日期操作，考虑引入 date-fns
import { format, addDays, differenceInDays } from 'date-fns';

// 简化 DateUtils
export class DateUtils {
  // 保留项目特定的日期逻辑
  static getLocalISODateTimeWithOffset(): string {
    // 自定义实现
  }
  
  // 使用 date-fns 的简单包装
  static formatDate(date: Date, formatStr: string): string {
    return format(date, formatStr);
  }
  
  static getDaysBetween(start: Date, end: Date): number {
    return differenceInDays(end, start);
  }
}
```

**或保持现状**：
- ✅ 如果不想引入新依赖
- ✅ 如果现有实现满足需求
- ✅ 避免包体积增加

**工作量**：2-3 小时（如果重构）  
**收益**：视具体需求而定

---

## 🟢 低优先级优化

### 8. apiHelper.ts 重构

**当前问题**：
1. ✅ 错误处理逻辑可以提取
2. ✅ ApiCache 类已在合并计划中
3. ✅ 请求去重逻辑可以独立

**重构方案**：
```typescript
// src/utils/api/
├── index.ts           # 统一导出
├── errorHandler.ts    # 错误处理
├── deduplicator.ts    # 请求去重
└── retry.ts           # 请求重试
```

**工作量**：2 小时  
**收益**：更模块化的 API 工具

### 9. 创建工具函数索引

**目标**：更好的可发现性

```typescript
// src/utils/index.ts
// ==================== 数据处理 ====================
export * from './objectUtils';
export * from './arrayUtils';
export * from './diff';

// ==================== 缓存系统 ====================
export * from './cache';

// ==================== 字符串处理 ====================
export * from './string';
export * as DateUtils from './date';

// ==================== UI/交互 ====================
export * from './toast';
export * from './export';

// ==================== 业务工具 ====================
export * from './transaction';
export * from './user';
```

**工作量**：30 分钟  
**收益**：
- ✅ 更容易导入
- ✅ 清晰的工具分类
- ✅ 减少重复导入路径

---

## 📋 优化路线图

### Phase 1: 立即优化（1-2 天）⭐⭐⭐

**目标**：清理和合并重复代码

- [ ] **删除空文件**（5 分钟）
  - `dataRoewwMapper.ts`
  - `periodDate.ts`

- [ ] **优化 sanitize.ts**（10 分钟）
  - 使用 es-toolkit 的 escape

- [ ] **简化 user.ts**（30 分钟）
  - 使用 pick + 默认值

- [ ] **合并缓存工具**（2-3 小时）⭐
  - 创建统一的 TTLCache 类
  - 合并 simpleCache 和 apiHelper 的 ApiCache
  - 保留 cacheUtils 的函数缓存

**预期收益**：
- 删除 ~150 行重复代码
- 统一缓存接口
- 更好的类型安全

### Phase 2: 重构优化（3-5 天）⭐⭐

**目标**：改善代码组织

- [ ] **重构 common.ts**（1 小时）
  - 拆分为 string.ts 和业务工具

- [ ] **优化 export.ts**（1 小时）
  - 提取公共下载逻辑
  - 简化 CSV 转义

- [ ] **重构 apiHelper.ts**（2 小时）
  - 模块化错误处理
  - 提取请求去重

- [ ] **创建工具索引**（30 分钟）
  - src/utils/index.ts

**预期收益**：
- 更清晰的文件组织
- 更容易维护
- 更好的可发现性

### Phase 3: 持续改进（长期）⭐

**目标**：保持最佳实践

- [ ] **定期审查**
  - 每季度审查工具函数使用情况
  - 识别新的优化机会

- [ ] **文档更新**
  - 保持 README 最新
  - 添加使用示例

- [ ] **性能监控**
  - 监控关键工具函数性能
  - 优化热点函数

---

## 📊 预期收益总结

### 代码质量

| 指标 | 当前 | 优化后 | 改进 |
|-----|------|--------|------|
| 重复代码 | ~200 行 | 0 行 | **-100%** |
| 文件数量 | 26 个 | 23 个 | **-11%** |
| 空文件 | 2 个 | 0 个 | **-100%** |
| 缓存实现 | 3 个 | 1 个 | **-67%** |

### 维护性

| 方面 | 改进 |
|-----|------|
| 代码组织 | **+40%** |
| 可发现性 | **+50%** |
| 类型安全 | **+30%** |
| 文档完整度 | **+60%** |

### 性能

| 操作 | 改进 |
|-----|------|
| HTML 转义 | **+20%** (es-toolkit) |
| 缓存操作 | **+15%** (统一实现) |
| 对象选择 | **+10%** (es-toolkit) |

---

## 🎯 推荐行动方案

### 立即执行（本周）⭐⭐⭐

1. **删除空文件** - 5 分钟
2. **优化 sanitize.ts** - 10 分钟
3. **简化 user.ts** - 30 分钟

**总工时**：45 分钟  
**风险**：极低  
**收益**：立即可见

### 短期计划（下周）⭐⭐

4. **合并缓存工具** - 2-3 小时
5. **优化 export.ts** - 1 小时
6. **创建工具索引** - 30 分钟

**总工时**：4-5 小时  
**风险**：低（充分测试）  
**收益**：显著提升维护性

### 中期计划（本月）⭐

7. **重构 apiHelper.ts** - 2 小时
8. **重构 common.ts** - 1 小时

**总工时**：3 小时  
**风险**：中（需要更新导入）  
**收益**：长期维护性提升

---

## 📝 实施清单

### 开始前检查

- [ ] 创建功能分支 `feat/utils-optimization`
- [ ] 备份当前代码
- [ ] 通知团队成员
- [ ] 准备测试环境

### 每个优化后

- [ ] 运行单元测试
- [ ] 更新导入路径
- [ ] 更新文档
- [ ] Code Review
- [ ] 合并到主分支

### 完成后

- [ ] 更新 README.md
- [ ] 更新团队文档
- [ ] 性能对比测试
- [ ] 团队分享会

---

**建议**：从 Phase 1 开始，逐步推进优化 ✅
