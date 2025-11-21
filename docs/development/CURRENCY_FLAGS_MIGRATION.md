# Currency 表字段扩展 - 迁移文档

## 📋 概述

为 `currency` 表添加 `is_default` 和 `is_active` 字段，支持默认货币设置和货币启用/禁用功能。

## 🎯 目标

1. 支持设置默认货币（用于新建账户、交易等场景）
2. 支持禁用某些货币而不删除历史数据
3. 多设备同步货币设置
4. 自动将 CNY（人民币）设置为默认货币

## 📊 数据库变更

### 新增字段

| 字段名 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| `is_default` | BOOLEAN | false | 是否为默认货币 |
| `is_active` | BOOLEAN | true | 是否激活 |

### 迁移策略

**历史数据处理**：
- 所有已存在的货币 `is_default` 自动设置为 `false`
- 所有已存在的货币 `is_active` 自动设置为 `true`
- **CNY（人民币）自动设置为默认货币** (`is_default = true`)

## 📁 修改文件清单

### 1. 数据库迁移层
- ✅ `src-tauri/migration/src/m20251121_000001_add_currency_flags.rs` - 新建迁移文件
- ✅ `src-tauri/migration/src/schema.rs` - 添加字段定义
- ✅ `src-tauri/migration/src/lib.rs` - 注册迁移

### 2. Entity 层
- ✅ `src-tauri/entity/src/currency.rs` - 添加字段到 Model

### 3. DTO 层
- ✅ `src-tauri/crates/money/src/dto/currency.rs`
  - `CurrencyResponse` - 添加响应字段
  - `CreateCurrencyRequest` - 添加创建字段（可选）
  - `UpdateCurrencyRequest` - 添加更新字段（可选）

### 4. 前端 Schema 层
- ✅ `src/schema/common.ts`
  - `CurrencySchema` - 添加字段定义
  - `CurrencyCreateSchema` - 使用 `omit` 排除时间戳字段
  - `CurrencyUpdateSchema` - 添加可更新字段

### 5. 前端 Service 层
- ✅ `src/services/money/money.ts` - 修复 `createCurrency` 参数类型

### 6. 前端 Store 层
- ✅ `src/stores/money/currency-store.ts` - 已使用新字段（无需修改）

## 🔄 迁移执行

### 自动执行
迁移会在应用启动时自动执行，无需手动干预。

### 迁移内容
```sql
-- 1. 添加 is_default 字段
ALTER TABLE currency ADD COLUMN is_default BOOLEAN NOT NULL DEFAULT false;

-- 2. 添加 is_active 字段  
ALTER TABLE currency ADD COLUMN is_active BOOLEAN NOT NULL DEFAULT true;

-- 3. 将 CNY 设置为默认货币
UPDATE currency SET is_default = true WHERE code = 'CNY';
```

### 回滚方案
```sql
-- 删除添加的字段
ALTER TABLE currency DROP COLUMN is_default;
ALTER TABLE currency DROP COLUMN is_active;
```

## 💡 使用示例

### 前端使用

```typescript
// 1. 获取默认货币
const currencyStore = useCurrencyStore();
await currencyStore.fetchCurrencies();
const defaultCurrency = currencyStore.defaultCurrency; // CNY

// 2. 获取激活的货币列表
const activeCurrencies = currencyStore.activeCurrencies;

// 3. 设置默认货币
await currencyStore.setDefaultCurrency('USD');

// 4. 创建新货币
await currencyStore.createCurrency({
  code: 'HKD',
  locale: 'zh-HK',
  symbol: 'HK$',
  isDefault: false,
  isActive: true,
});

// 5. 禁用货币
await currencyStore.updateCurrency('EUR', { isActive: false });
```

### 后端使用

```rust
// 1. 查询默认货币
let default_currency = Currency::find()
    .filter(currency::Column::IsDefault.eq(true))
    .one(&db)
    .await?;

// 2. 查询激活的货币
let active_currencies = Currency::find()
    .filter(currency::Column::IsActive.eq(true))
    .all(&db)
    .await?;

// 3. 创建货币
let currency = CreateCurrencyRequest {
    code: "HKD".to_string(),
    locale: "zh-HK".to_string(),
    symbol: "HK$".to_string(),
    is_default: false,
    is_active: true,
};
```

## ⚠️ 注意事项

1. **唯一默认货币**：系统应确保同一时间只有一个货币被标记为默认
   - 前端 `setDefaultCurrency` 方法会自动处理
   - 后端可考虑添加唯一约束或触发器

2. **历史数据兼容**：
   - 已存在的货币会自动获得默认值
   - CNY 自动成为默认货币
   - 不影响现有交易和账户数据

3. **前端缓存**：
   - Store 会缓存货币列表 30 分钟
   - 修改后需要调用 `fetchCurrencies(true)` 强制刷新

4. **禁用货币影响**：
   - 禁用货币不会删除历史数据
   - 已使用该货币的账户和交易仍然有效
   - 新建账户/交易时不应显示已禁用的货币

## 🧪 测试建议

### 单元测试
- [ ] 测试迁移的 up 和 down 方法
- [ ] 测试 CNY 是否正确设置为默认
- [ ] 测试字段默认值

### 集成测试
- [ ] 测试创建货币时的默认值
- [ ] 测试更新默认货币的逻辑
- [ ] 测试禁用货币后的查询

### E2E 测试
- [ ] 测试前端货币选择器只显示激活的货币
- [ ] 测试默认货币在新建账户时自动选中
- [ ] 测试设置默认货币的完整流程

## 📅 时间线

- **2025-11-21**: 创建迁移文件和更新相关代码
- **待定**: 运行迁移并验证
- **待定**: 部署到生产环境

## 🔗 相关文档

- [数据库迁移指南](../database/MIGRATION_GUIDE.md)
- [Currency 表文档](../database/core/currency.md)
- [全局 Store 使用指南](../frontend/GLOBAL_STORE_USAGE.md)
