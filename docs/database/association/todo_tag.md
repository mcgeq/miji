# todo_tag - 任务标签关联表

[← 返回索引](../README.md)

## 📋 表信息

- **表名**: `todo_tag`
- **说明**: 待办事项与标签的多对多关联表
- **主键**: 复合主键 (`todo_serial_num`, `tag_serial_num`)
- **创建迁移**: `m20250803_132244_create_todo_tag.rs`

## 📊 表结构

### 字段说明

| 字段名 | 类型 | 长度 | 约束 | 默认值 | 说明 |
|--------|------|------|------|--------|------|
| `todo_serial_num` | VARCHAR | 38 | PK, FK, NOT NULL | - | 待办ID，外键到 `todo.serial_num` |
| `tag_serial_num` | VARCHAR | 38 | PK, FK, NOT NULL | - | 标签ID，外键到 `tag.serial_num` |
| `orders` | INTEGER | - | NULLABLE | NULL | 在任务标签列表中的排序序号 |
| `created_at` | TIMESTAMP WITH TIME ZONE | - | NOT NULL | - | 创建时间 |
| `updated_at` | TIMESTAMP WITH TIME ZONE | - | NULLABLE | NULL | 最后更新时间 |

## 🔗 关系说明

### 外键关系

| 关系类型 | 目标表 | 关联字段 | 级联操作 | 说明 |
|---------|--------|---------|---------|------|
| BELONGS_TO | `tag` | `tag_serial_num` → `serial_num` | ON DELETE: CASCADE | 关联标签 |
| BELONGS_TO | `todo` | `todo_serial_num` → `serial_num` | ON DELETE: CASCADE | 关联任务 |

### 多对多关系

| 关系 | 目标表 | 中间表 | 说明 |
|------|--------|--------|------|
| MANY_TO_MANY | `todo` ↔ `tag` | `todo_tag` | 任务与标签多对多关联 |

## 📑 索引建议

```sql
PRIMARY KEY (todo_serial_num, tag_serial_num);

CREATE INDEX idx_todo_tag_todo ON todo_tag(todo_serial_num);
CREATE INDEX idx_todo_tag_tag ON todo_tag(tag_serial_num);
```

## 💡 使用示例

### 给任务添加标签

```rust
use entity::todo_tag;
use sea_orm::*;

let link = todo_tag::ActiveModel {
    todo_serial_num: Set(todo_id.clone()),
    tag_serial_num: Set(tag_id.clone()),
    orders: Set(Some(0)),
    created_at: Set(Utc::now().into()),
    ..Default::default()
};

let result = link.insert(db).await?;
```

### 查询任务的所有标签

```rust
use entity::{todo_tag, tag};

let tags = Tag::find()
    .inner_join(TodoTag)
    .filter(todo_tag::Column::TodoSerialNum.eq(todo_id.clone()))
    .all(db)
    .await?;
```

### 查询使用某个标签的所有任务

```rust
use entity::{todo_tag, todo};

let tasks = Todo::find()
    .inner_join(TodoTag)
    .filter(todo_tag::Column::TagSerialNum.eq(tag_id.clone()))
    .all(db)
    .await?;
```

### 从任务上移除标签

```rust
TodoTag::delete_many()
    .filter(todo_tag::Column::TodoSerialNum.eq(todo_id.clone()))
    .filter(todo_tag::Column::TagSerialNum.eq(tag_id.clone()))
    .exec(db)
    .await?;
```

## ⚠️ 注意事项

1. **复合主键**: 同一任务与同一标签之间只能存在一条记录
2. **排序字段**: `orders` 可用于按照自定义顺序展示标签
3. **级联删除**: 删除任务或标签会自动删除关联记录
4. **统计标签使用频率**: 可基于本表统计标签的使用次数

## 🔗 相关表

- [todo - 待办事项表](../business/todo.md)
- [tag - 标签表](../business/tag.md)

---

**最后更新**: 2025-11-15  
[← 返回索引](../README.md)
