# sub_categories - 子分类表

[← 返回索引](../README.md)

## 📋 表信息

- **表名**: `sub_categories`
- **说明**: 交易子分类表，用于细分主分类下的具体类型（如 "餐饮-早餐"）
- **主键**: 复合主键 (`name`, `category_name`)
- **创建迁移**: `m20250803_132230_create_sub_categories.rs`

## 📊 表结构

### 字段说明

| 字段名 | 类型 | 长度 | 约束 | 默认值 | 说明 |
|--------|------|------|------|--------|------|
| `name` | VARCHAR | 50 | PK, NOT NULL | - | 子分类名称 |
| `category_name` | VARCHAR | 50 | PK, FK, NOT NULL | - | 所属主分类名称，外键到 `categories.name` |
| `icon` | VARCHAR | 100 | NULLABLE | NULL | 图标名称或路径 |
| `created_at` | TIMESTAMP WITH TIME ZONE | - | NOT NULL | - | 创建时间 |
| `updated_at` | TIMESTAMP WITH TIME ZONE | - | NULLABLE | NULL | 最后更新时间 |

**用途说明**:
- 使用复合主键 (`category_name`, `name`) 保证在同一主分类下子分类名称唯一
- 不同主分类可以使用相同的子分类名称（如 "其他"）

## 🔗 关系说明

### 外键关系

| 关系类型 | 目标表 | 关联字段 | 级联操作 | 说明 |
|---------|--------|---------|---------|------|
| BELONGS_TO | `categories` | `category_name` → `name` | ON DELETE: RESTRICT<br>ON UPDATE: CASCADE | 所属主分类 |

## 📑 索引建议

```sql
-- 复合主键（自动创建）
PRIMARY KEY (name, category_name)

-- 按主分类查询子分类
CREATE INDEX idx_sub_categories_category 
ON sub_categories(category_name);
```

## 💡 使用示例

### 创建子分类

```rust
use entity::sub_categories;
use sea_orm::*;

let breakfast = sub_categories::ActiveModel {
    name: Set("早餐".to_string()),
    category_name: Set("餐饮".to_string()),
    icon: Set(Some("Coffee".to_string())),
    created_at: Set(Utc::now().into()),
    ..Default::default()
};

let result = breakfast.insert(db).await?;
```

### 查询主分类下的所有子分类

```rust
let food_sub_categories = SubCategories::find()
    .filter(sub_categories::Column::CategoryName.eq("餐饮"))
    .all(db)
    .await?;
```

### 更新子分类图标

```rust
let sub = SubCategories::find()
    .filter(sub_categories::Column::CategoryName.eq("餐饮"))
    .filter(sub_categories::Column::Name.eq("早餐"))
    .one(db)
    .await?
    .unwrap();

let mut active: sub_categories::ActiveModel = sub.into();
active.icon = Set(Some("Croissant".to_string()));
active.updated_at = Set(Some(Utc::now().into()));

active.update(db).await?;
```

### 删除子分类前的检查

```rust
use entity::{sub_categories, transactions};

// 检查是否有交易引用该子分类
let tx_count = Transactions::find()
    .filter(transactions::Column::Category.eq("餐饮"))
    .filter(transactions::Column::SubCategory.eq("早餐"))
    .count(db)
    .await?;

if tx_count == 0 {
    SubCategories::delete()
        .filter(sub_categories::Column::CategoryName.eq("餐饮"))
        .filter(sub_categories::Column::Name.eq("早餐"))
        .exec(db)
        .await?;
}
```

## ⚠️ 注意事项

1. **复合主键**: 修改 `name` 或 `category_name` 都涉及主键变更，需谨慎
2. **多语言支持**: 与主分类类似，如需多语言显示，建议在应用层做映射
3. **删除限制**: 删除主分类前必须确保没有子分类；删除子分类前必须确保没有交易引用
4. **图标一致性**: 子分类图标风格应与主分类保持一致
5. **分组展示**: 前端展示时通常按 `category_name` 分组显示子分类

## 🔗 相关表

- [categories - 分类表](./categories.md)
- [transactions - 交易记录表](../core/transactions.md)

---

**最后更新**: 2025-11-15  
[← 返回索引](../README.md)
