# [表名] - [表说明]

[← 返回索引](../README.md)

## 📋 表信息

- **表名**: `table_name`
- **说明**: 表的用途和业务含义
- **主键**: `serial_num` 或其他主键字段
- **创建迁移**: `mYYYYMMDD_NNNNNN_create_table_name.rs`
- **扩展迁移**: `mYYYYMMDD_NNNNNN_enhance_table_name.rs` (如有)

## 📊 表结构

### 基础字段

| 字段名 | 类型 | 长度 | 约束 | 默认值 | 说明 |
|--------|------|------|------|--------|------|
| `field_name` | VARCHAR | 100 | PK/FK/NOT NULL/NULLABLE | - | 字段说明 |
| `created_at` | TIMESTAMP WITH TIME ZONE | - | NOT NULL | - | 创建时间 |
| `updated_at` | TIMESTAMP WITH TIME ZONE | - | NULLABLE | NULL | 最后更新时间 |

**枚举值** (如有):
- `field_name`: 'Value1', 'Value2', 'Value3'

**用途说明**:
- `field_name`: 详细的用途说明

### [其他字段分组] (如有)

根据业务逻辑对字段进行分组，如：
- 关联字段
- 统计字段
- 配置字段
- 财务字段

## 🔗 关系说明

### 外键关系

| 关系类型 | 目标表 | 关联字段 | 级联操作 | 说明 |
|---------|--------|---------|---------|------|
| BELONGS_TO | `target_table` | `field` → `target_field` | ON DELETE: CASCADE/RESTRICT/SET NULL<br>ON UPDATE: CASCADE | 关系说明 |

### 一对多关系

| 关系 | 目标表 | 说明 |
|------|--------|------|
| HAS_MANY | `target_table` | 关系说明 |

### 多对多关系 (如有)

| 关系 | 目标表 | 中间表 | 说明 |
|------|--------|--------|------|
| MANY_TO_MANY | `target_table` | `junction_table` | 关系说明 |

## 📑 索引建议

```sql
-- 主键索引（自动创建）
PRIMARY KEY (primary_key_field)

-- 外键索引
CREATE INDEX idx_table_name_foreign_key ON table_name(foreign_key_field);

-- 业务查询索引
CREATE INDEX idx_table_name_business_field ON table_name(business_field);

-- 复合索引
CREATE INDEX idx_table_name_composite 
ON table_name(field1, field2) 
WHERE condition;
```

## 💡 使用示例

### 创建记录

```rust
use entity::table_name;
use sea_orm::*;

let record = table_name::ActiveModel {
    serial_num: Set(McgUuid::new().to_string()),
    field_name: Set("value".to_string()),
    created_at: Set(Utc::now().into()),
    ..Default::default()
};

let result = record.insert(db).await?;
```

### 查询记录

```rust
let records = TableName::find()
    .filter(table_name::Column::FieldName.eq("value"))
    .all(db)
    .await?;
```

### 更新记录

```rust
let record = table_name::Entity::find_by_id(id)
    .one(db)
    .await?
    .unwrap();

let mut active: table_name::ActiveModel = record.into();
active.field_name = Set("new_value".to_string());
active.updated_at = Set(Some(Utc::now().into()));

active.update(db).await?;
```

### 删除记录

```rust
table_name::Entity::delete_by_id(id)
    .exec(db)
    .await?;
```

## ⚠️ 注意事项

1. **注意事项1**: 说明
2. **注意事项2**: 说明
3. **注意事项3**: 说明

## 🔄 业务流程 (如有)

### 流程名称
```
1. 步骤1
2. 步骤2
3. 步骤3
```

## 📊 数据示例 (可选)

| field1 | field2 | field3 | 说明 |
|--------|--------|--------|------|
| value1 | value2 | value3 | 示例说明 |

## 🔗 相关表

- [related_table1 - 说明](./related_table1.md)
- [related_table2 - 说明](./related_table2.md)

## 📚 相关文档 (可选)

- [相关业务文档](../business/document.md)
- [API 文档](../../api/endpoint.md)

---

**最后更新**: YYYY-MM-DD  
[← 返回索引](../README.md)
