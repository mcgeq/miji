# split_rules - 分摊规则表

[← 返回索引](../README.md)

## 📋 表信息

- **表名**: `split_rules`
- **说明**: 费用分摊规则表，用于定义在家庭账本中如何在成员之间分摊一笔支出
- **主键**: `serial_num`
- **创建迁移**: `m20251112_000003_create_split_rules_table.rs`

## 📊 表结构

### 字段说明

| 字段名 | 类型 | 长度 | 约束 | 默认值 | 说明 |
|--------|------|------|------|--------|------|
| `serial_num` | VARCHAR | 38 | PK, NOT NULL | - | 分摊规则唯一标识符（UUID） |
| `family_ledger_serial_num` | VARCHAR | 38 | FK, NOT NULL | - | 所属账本ID，外键到 `family_ledger.serial_num` |
| `name` | VARCHAR | 100 | NOT NULL | - | 分摊规则名称 |
| `description` | VARCHAR | 500 | NULLABLE | NULL | 规则描述 |
| `rule_type` | VARCHAR | 20 | NOT NULL | 'Equal' | 规则类型 |
| `rule_config` | JSON | - | NOT NULL | - | 规则配置（比例、固定金额等） |
| `participant_members` | JSON | - | NOT NULL | - | 参与成员列表及其权重配置 |
| `is_template` | BOOLEAN | NOT NULL | false | 是否为模板，可在多笔交易中复用 |
| `is_default` | BOOLEAN | NOT NULL | false | 是否为账本默认规则 |
| `category` | VARCHAR | 50 | NULLABLE | NULL | 适用的主分类（可选） |
| `sub_category` | VARCHAR | 50 | NULLABLE | NULL | 适用的子分类（可选） |
| `min_amount` | DECIMAL | (16, 4) | NULLABLE | NULL | 适用的最小金额 |
| `max_amount` | DECIMAL | (16, 4) | NULLABLE | NULL | 适用的最大金额 |
| `tags` | JSON | NULLABLE | NULL | 标签，用于筛选和分组 |
| `priority` | INTEGER | - | NOT NULL | 0 | 匹配优先级，数值越大优先级越高 |
| `is_active` | BOOLEAN | - | NOT NULL | true | 是否启用该规则 |
| `created_by` | VARCHAR | 38 | NOT NULL | - | 创建人（成员ID或用户ID） |
| `created_at` | TIMESTAMP WITH TIME ZONE | - | NOT NULL | - | 创建时间 |
| `updated_at` | TIMESTAMP WITH TIME ZONE | - | NULLABLE | NULL | 最后更新时间 |

**rule_type 约定值**：
- `Equal`: 平分（每人相同金额）
- `ByRatio`: 按比例分摊
- `ByAmount`: 按固定金额分摊
- `ByWeight`: 按权重分摊（权重总和归一化）

**rule_config 示例**：
```json
// Equal
{ "type": "Equal" }

// ByRatio
{ "type": "ByRatio", "ratios": { "member1": 0.6, "member2": 0.4 } }

// ByAmount
{ "type": "ByAmount", "amounts": { "member1": 80, "member2": 20 } }
```

**participant_members 示例**：
```json
{
  "member1": { "name": "张三", "weight": 1 },
  "member2": { "name": "李四", "weight": 2 }
}
```

## 🔗 关系说明

### 外键关系

| 关系类型 | 目标表 | 关联字段 | 级联操作 | 说明 |
|---------|--------|---------|---------|------|
| BELONGS_TO | `family_ledger` | `family_ledger_serial_num` → `serial_num` | ON DELETE: CASCADE | 所属账本 |

### 一对多关系

| 关系 | 目标表 | 说明 |
|------|--------|------|
| HAS_MANY | `split_records` | 使用该规则生成的分摊记录 |

## 📑 索引建议

```sql
PRIMARY KEY (serial_num);

CREATE INDEX idx_split_rules_ledger ON split_rules(family_ledger_serial_num);
CREATE INDEX idx_split_rules_active ON split_rules(is_active, priority);
CREATE INDEX idx_split_rules_category ON split_rules(category, sub_category);
```

## 💡 使用示例

### 创建一个平分规则

```rust
use entity::split_rules;
use sea_orm::*;

let rule = split_rules::ActiveModel {
    serial_num: Set(McgUuid::new().to_string()),
    family_ledger_serial_num: Set(ledger_id.clone()),
    name: Set("平分规则".to_string()),
    description: Set(Some("所有成员平分".to_string())),
    rule_type: Set("Equal".to_string()),
    rule_config: Set(json!({ "type": "Equal" })),
    participant_members: Set(json!({
      "member1": { "weight": 1 },
      "member2": { "weight": 1 }
    })),
    is_template: Set(true),
    is_default: Set(true),
    category: Set(None),
    sub_category: Set(None),
    min_amount: Set(None),
    max_amount: Set(None),
    tags: Set(Some(json!(["默认", "平分"]))),
    priority: Set(0),
    is_active: Set(true),
    created_by: Set(creator_id.clone()),
    created_at: Set(Utc::now().into()),
    ..Default::default()
};

let result = rule.insert(db).await?;
```

### 根据交易自动匹配规则（伪代码）

```rust
let rules = SplitRules::find()
    .filter(split_rules::Column::FamilyLedgerSerialNum.eq(ledger_id.clone()))
    .filter(split_rules::Column::IsActive.eq(true))
    .order_by_desc(split_rules::Column::Priority)
    .all(db)
    .await?;

// 在代码中：
// 1. 过滤金额范围
// 2. 过滤分类
// 3. 过滤标签
// 4. 选取第一个符合条件的规则
```

## ⚠️ 注意事项

1. **规则配置验证**: `rule_config` 与 `rule_type` 必须匹配，需在应用层做校验
2. **参与成员同步**: `participant_members` 中的成员ID必须存在于 `family_member` 表
3. **默认规则唯一性**: 每个账本建议最多只有一个 `is_default = true` 的规则
4. **优先级控制**: `priority` 用于解决多规则匹配冲突，数值越大优先级越高
5. **性能考虑**: 根据分类、金额、标签自动匹配规则时，应在内存中处理 JSON 字段，避免复杂 SQL

## 🔗 相关表

- [family_ledger - 家庭账本表](../core/family_ledger.md)
- [split_records - 分摊记录表](./split_records.md)
- [family_member - 家庭成员表](../core/family_member.md)

---

**最后更新**: 2025-11-15  
[← 返回索引](../README.md)
