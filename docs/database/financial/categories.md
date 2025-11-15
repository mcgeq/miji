# categories - 分类表

[← 返回索引](../README.md)

## 📋 表信息

- **表名**: `categories`
- **说明**: 交易主分类表，用于定义支出/收入的一级分类
- **主键**: `name`
- **创建迁移**: `m20250803_132229_create_categories.rs`

## 📊 表结构

### 字段说明

| 字段名 | 类型 | 长度 | 约束 | 默认值 | 说明 |
|--------|------|------|------|--------|------|
| `name` | VARCHAR | 50 | PK, NOT NULL | - | 分类名称（唯一） |
| `icon` | VARCHAR | 100 | NULLABLE | NULL | 图标名称或路径，用于UI展示 |
| `created_at` | TIMESTAMP WITH TIME ZONE | - | NOT NULL | - | 创建时间 |
| `updated_at` | TIMESTAMP WITH TIME ZONE | - | NULLABLE | NULL | 最后更新时间 |

**用途说明**:
- `name` 作为主键，直接用分类名称标识（如 "餐饮", "交通", "工资"）
- `icon` 通常存储一个图标 key（如 lucide 图标名）或自定义图标路径

## 🔗 关系说明

### 一对多关系

| 关系 | 目标表 | 说明 |
|------|--------|------|
| HAS_MANY | `sub_categories` | 一个主分类下可以有多个子分类 |

## 📑 索引建议

```sql
-- 主键索引（自动创建）
PRIMARY KEY (name)
```

## 💡 使用示例

### 创建分类

```rust
use entity::categories;
use sea_orm::*;

let food = categories::ActiveModel {
    name: Set("餐饮".to_string()),
    icon: Set(Some("UtensilsCrossed".to_string())),
    created_at: Set(Utc::now().into()),
    ..Default::default()
};

let result = food.insert(db).await?;
```

### 查询所有分类

```rust
let all_categories = Categories::find()
    .all(db)
    .await?;
```

### 更新分类图标

```rust
let category = Categories::find_by_id("餐饮")
    .one(db)
    .await?
    .unwrap();

let mut active: categories::ActiveModel = category.into();
active.icon = Set(Some("Pizza".to_string()));
active.updated_at = Set(Some(Utc::now().into()));

active.update(db).await?;
```

### 删除分类前的检查

```rust
use entity::{categories, sub_categories, transactions};

// 检查是否有子分类
let sub_count = SubCategories::find()
    .filter(sub_categories::Column::Category.eq("餐饮"))
    .count(db)
    .await?;

// 检查是否有交易引用该分类
let tx_count = Transactions::find()
    .filter(transactions::Column::Category.eq("餐饮"))
    .count(db)
    .await?;

if sub_count == 0 && tx_count == 0 {
    Categories::delete_by_id("餐饮").exec(db).await?;
}
```

## ⚠️ 注意事项

1. **名称即主键**: `name` 作为主键，修改名称相当于主键变更，建议避免频繁修改
2. **多语言支持**: 如需多语言分类名，建议在应用层做本地化映射，而不是直接改 `name`
3. **删除分类**: 删除前必须检查是否有子分类和交易引用
4. **图标规范**: `icon` 建议使用统一图标库的 key，便于前端渲染
5. **扩展字段**: 若未来需要增加排序、类型（收入/支出）等字段，可通过迁移扩展

## 🔗 相关表

- [sub_categories - 子分类表](./sub_categories.md)
- [transactions - 交易记录表](../core/transactions.md)
- [budget - 预算表](./budget.md)

---

**最后更新**: 2025-11-15  
[← 返回索引](../README.md)
