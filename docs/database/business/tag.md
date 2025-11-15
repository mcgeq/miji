# tag - 标签表

[← 返回索引](../README.md)

## 📋 表信息

- **表名**: `tag`
- **说明**: 标签表，用于为待办事项等资源添加自定义标签（如「重要」「家」「工作」）
- **主键**: `serial_num`
- **创建迁移**: `m20250803_132242_create_tag.rs`

## 📊 表结构

### 字段说明

| 字段名 | 类型 | 长度 | 约束 | 默认值 | 说明 |
|--------|------|------|------|--------|------|
| `serial_num` | VARCHAR | 38 | PK, NOT NULL | - | 标签唯一ID |
| `name` | VARCHAR | 50 | UNIQUE, NOT NULL | - | 标签名称（全局唯一） |
| `description` | VARCHAR | 200 | NULLABLE | NULL | 标签描述 |
| `created_at` | TIMESTAMP WITH TIME ZONE | - | NOT NULL | - | 创建时间 |
| `updated_at` | TIMESTAMP WITH TIME ZONE | - | NULLABLE | NULL | 最后更新时间 |

## 🔗 关系说明

### 一对多关系

| 关系 | 目标表 | 说明 |
|------|--------|------|
| HAS_MANY | `todo_tag` | 标签与待办关联记录 |

### 多对多关系

| 关系 | 目标表 | 中间表 | 说明 |
|------|--------|--------|------|
| MANY_TO_MANY | `todo` | `todo_tag` | 一个标签可关联多个任务，一个任务可有多个标签 |

## 📑 索引建议

```sql
PRIMARY KEY (serial_num);

UNIQUE INDEX idx_tag_name ON tag(name);
```

## 💡 使用示例

### 创建标签

```rust
use entity::tag;
use sea_orm::*;

let important = tag::ActiveModel {
    serial_num: Set(McgUuid::new().to_string()),
    name: Set("重要".to_string()),
    description: Set(Some("高优先级任务".to_string())),
    created_at: Set(Utc::now().into()),
    ..Default::default()
};

let result = important.insert(db).await?;
```

### 查询所有标签

```rust
let tags = Tag::find().all(db).await?;
```

### 更新标签名称

```rust
let tag = Tag::find()
    .filter(tag::Column::Name.eq("重要"))
    .one(db)
    .await?
    .unwrap();

let mut active: tag::ActiveModel = tag.into();
active.name = Set("高优先级".to_string());
active.updated_at = Set(Some(Utc::now().into()));

active.update(db).await?;
```

### 删除标签前的检查

```rust
use entity::{tag, todo_tag};

let usage_count = TodoTag::find()
    .filter(todo_tag::Column::TagSerialNum.eq(tag_id.clone()))
    .count(db)
    .await?;

if usage_count == 0 {
    Tag::delete_by_id(tag_id).exec(db).await?;
}
```

## ⚠️ 注意事项

1. **名称唯一**: `name` 为全局唯一，创建前应检查重名
2. **多语言策略**: 如需多语言标签，建议业务层做映射，而不是修改 `name`
3. **删除标签**: 删除前需确认没有任务仍在使用该标签
4. **标签数量控制**: 标签过多会影响管理，可在业务层限制每个用户/项目的标签数量

## 🔗 相关表

- [todo - 待办事项表](./todo.md)
- [todo_tag - 任务标签关联表](../association/todo_tag.md)

---

**最后更新**: 2025-11-15  
[← 返回索引](../README.md)
