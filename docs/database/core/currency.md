# currency - 货币表

[← 返回索引](../README.md)

## 📋 表信息

- **表名**: `currency`
- **说明**: 货币配置表，存储系统支持的货币类型及其显示信息
- **主键**: `code`
- **创建迁移**: `m20250803_132224_create_currency.rs`

## 📊 表结构

### 字段说明

| 字段名 | 类型 | 长度 | 约束 | 默认值 | 说明 |
|--------|------|------|------|--------|------|
| `code` | VARCHAR | 3 | PK, NOT NULL | - | 货币代码（ISO 4217标准） |
| `locale` | VARCHAR | 10 | NOT NULL | - | 区域代码（如 zh-CN, en-US） |
| `symbol` | VARCHAR | 10 | NOT NULL | - | 货币符号（如 ¥, $, €） |
| `created_at` | TIMESTAMP WITH TIME ZONE | - | NOT NULL | - | 创建时间 |
| `updated_at` | TIMESTAMP WITH TIME ZONE | - | NULLABLE | NULL | 最后更新时间 |

**用途说明**:
- `code`: 使用 ISO 4217 标准的三字母货币代码
  - CNY: 人民币
  - USD: 美元
  - EUR: 欧元
  - JPY: 日元
  - GBP: 英镑
  - HKD: 港币
  - 等等...
- `locale`: 区域代码，用于本地化显示
- `symbol`: 货币符号，用于UI展示

## 🔗 关系说明

### 一对多关系

| 关系 | 目标表 | 说明 |
|------|--------|------|
| HAS_MANY | `family_ledger` | 使用该货币的账本 |
| HAS_MANY | `account` | 使用该货币的账户 |
| HAS_MANY | `transactions` | 使用该货币的交易 |

**级联说明**:
- 删除货币时会被限制（RESTRICT），必须先处理所有使用该货币的记录
- 更新货币代码时会级联更新（CASCADE）所有关联记录

## 📑 索引建议

```sql
-- 主键索引（自动创建）
PRIMARY KEY (code)

-- 区域查询索引
CREATE INDEX idx_currency_locale ON currency(locale);
```

## 💡 使用示例

### 创建货币

```rust
use entity::currency;
use sea_orm::*;

let cny = currency::ActiveModel {
    code: Set("CNY".to_string()),
    locale: Set("zh-CN".to_string()),
    symbol: Set("¥".to_string()),
    created_at: Set(Utc::now().into()),
    ..Default::default()
};

let result = cny.insert(db).await?;
```

### 批量创建常用货币

```rust
let currencies = vec![
    ("CNY", "zh-CN", "¥"),
    ("USD", "en-US", "$"),
    ("EUR", "en-EU", "€"),
    ("JPY", "ja-JP", "¥"),
    ("GBP", "en-GB", "£"),
    ("HKD", "zh-HK", "HK$"),
];

for (code, locale, symbol) in currencies {
    let currency = currency::ActiveModel {
        code: Set(code.to_string()),
        locale: Set(locale.to_string()),
        symbol: Set(symbol.to_string()),
        created_at: Set(Utc::now().into()),
        ..Default::default()
    };
    
    currency.insert(db).await?;
}
```

### 查询所有货币

```rust
let all_currencies = Currency::find()
    .all(db)
    .await?;
```

### 按区域查询货币

```rust
let chinese_currencies = Currency::find()
    .filter(currency::Column::Locale.contains("zh"))
    .all(db)
    .await?;
```

### 获取货币信息

```rust
let cny = Currency::find_by_id("CNY")
    .one(db)
    .await?
    .ok_or("Currency not found")?;

println!("货币: {} ({})", cny.code, cny.symbol);
```

### 更新货币信息

```rust
let currency = Currency::find_by_id("CNY")
    .one(db)
    .await?
    .unwrap();

let mut active: currency::ActiveModel = currency.into();
active.symbol = Set("￥".to_string()); // 更新符号
active.updated_at = Set(Some(Utc::now().into()));

active.update(db).await?;
```

### 检查货币是否被使用

```rust
use entity::{account, family_ledger, transactions};

// 检查是否有账本使用该货币
let ledger_count = FamilyLedger::find()
    .filter(family_ledger::Column::BaseCurrency.eq("CNY"))
    .count(db)
    .await?;

// 检查是否有账户使用该货币
let account_count = Account::find()
    .filter(account::Column::Currency.eq("CNY"))
    .count(db)
    .await?;

// 检查是否有交易使用该货币
let transaction_count = Transactions::find()
    .filter(transactions::Column::Currency.eq("CNY"))
    .count(db)
    .await?;

let is_in_use = ledger_count > 0 || account_count > 0 || transaction_count > 0;
```

## ⚠️ 注意事项

1. **ISO 4217 标准**: `code` 必须使用标准的三字母货币代码
2. **删除限制**: 删除货币前必须确保没有账本、账户或交易使用该货币
3. **代码唯一性**: 货币代码全局唯一，不能重复
4. **符号显示**: `symbol` 用于UI展示，应使用正确的Unicode字符
5. **区域代码**: `locale` 应遵循 BCP 47 标准（如 zh-CN, en-US）
6. **初始数据**: 系统应预置常用货币，避免用户手动创建
7. **汇率处理**: 本表不存储汇率，汇率应由专门的汇率表管理

## 📊 常用货币列表

| 代码 | 名称 | 符号 | 区域 |
|------|------|------|------|
| CNY | 人民币 | ¥ | zh-CN |
| USD | 美元 | $ | en-US |
| EUR | 欧元 | € | en-EU |
| JPY | 日元 | ¥ | ja-JP |
| GBP | 英镑 | £ | en-GB |
| HKD | 港币 | HK$ | zh-HK |
| TWD | 新台币 | NT$ | zh-TW |
| KRW | 韩元 | ₩ | ko-KR |
| AUD | 澳元 | A$ | en-AU |
| CAD | 加元 | C$ | en-CA |
| SGD | 新加坡元 | S$ | en-SG |
| CHF | 瑞士法郎 | CHF | de-CH |

## 🌍 区域代码说明

区域代码格式：`语言代码-国家代码`

常用区域代码：
- `zh-CN`: 中文（中国）
- `zh-HK`: 中文（香港）
- `zh-TW`: 中文（台湾）
- `en-US`: 英语（美国）
- `en-GB`: 英语（英国）
- `ja-JP`: 日语（日本）
- `ko-KR`: 韩语（韩国）

## 💱 汇率处理建议

虽然本表不存储汇率，但在多货币场景下需要考虑：

1. **创建汇率表**
   ```sql
   CREATE TABLE exchange_rates (
       from_currency VARCHAR(3),
       to_currency VARCHAR(3),
       rate DECIMAL(16, 8),
       date DATE,
       PRIMARY KEY (from_currency, to_currency, date)
   );
   ```

2. **汇率转换**
   ```rust
   // 将 USD 转换为 CNY
   let rate = get_exchange_rate("USD", "CNY", date).await?;
   let cny_amount = usd_amount * rate;
   ```

3. **基准货币**
   - 建议设置一个基准货币（如 CNY）
   - 所有汇率以基准货币为参照
   - 简化汇率管理和计算

## 🔗 相关表

- [family_ledger - 家庭账本表](./family_ledger.md)
- [account - 账户表](./account.md)
- [transactions - 交易记录表](./transactions.md)

## 📚 参考资源

- [ISO 4217 货币代码标准](https://www.iso.org/iso-4217-currency-codes.html)
- [BCP 47 语言标签](https://www.rfc-editor.org/rfc/bcp/bcp47.txt)
- [Unicode 货币符号](https://www.unicode.org/charts/PDF/U20A0.pdf)

---

**最后更新**: 2025-11-15  
[← 返回索引](../README.md)
