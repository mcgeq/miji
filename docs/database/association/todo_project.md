# todo_project - 任务项目关联表

[← 返回索引](../README.md)

## 📋 表信息

- **表名**: `todo_project`
- **说明**: 待办事项与项目的多对多关联表
- **主键**: 复合主键 (`todo_serial_num`, `project_serial_num`)
- **创建迁移**: `m20250803_132243_create_todo_project.rs`

## 📊 表结构

### 字段说明

| 字段名 | 类型 | 长度 | 约束 | 默认值 | 说明 |
|--------|------|------|------|--------|------|
| `todo_serial_num` | VARCHAR | 38 | PK, FK, NOT NULL | - | 待办ID，外键到 `todo.serial_num` |
| `project_serial_num` | VARCHAR | 38 | PK, FK, NOT NULL | - | 项目ID，外键到 `project.serial_num` |
| `order_index` | INTEGER | - | NULLABLE | NULL | 在项目中的排序（看板/列表顺序） |
| `created_at` | TIMESTAMP WITH TIME ZONE | - | NOT NULL | - | 创建时间 |
| `updated_at` | TIMESTAMP WITH TIME ZONE | - | NULLABLE | NULL | 最后更新时间 |

## 🔗 关系说明

### 外键关系

| 关系类型 | 目标表 | 关联字段 | 级联操作 | 说明 |
|---------|--------|---------|---------|------|
| BELONGS_TO | `project` | `project_serial_num` → `serial_num` | ON DELETE: CASCADE | 所属项目 |
| BELONGS_TO | `todo` | `todo_serial_num` → `serial_num` | ON DELETE: CASCADE | 所属任务 |

### 多对多关系

| 关系 | 目标表 | 中间表 | 说明 |
|------|--------|--------|------|
| MANY_TO_MANY | `todo` ↔ `project` | `todo_project` | 任务与项目多对多关联 |

## 📑 索引建议

```sql
PRIMARY KEY (todo_serial_num, project_serial_num);

CREATE INDEX idx_todo_project_project ON todo_project(project_serial_num);
CREATE INDEX idx_todo_project_todo ON todo_project(todo_serial_num);
```

## 💡 使用示例

### 将任务加入项目

```rust
use entity::todo_project;
use sea_orm::*;

let link = todo_project::ActiveModel {
    todo_serial_num: Set(todo_id.clone()),
    project_serial_num: Set(project_id.clone()),
    order_index: Set(Some(0)),
    created_at: Set(Utc::now().into()),
    ..Default::default()
};

let result = link.insert(db).await?;
```

### 查询项目下所有任务

```rust
use entity::{todo_project, todo};

let tasks = Todo::find()
    .inner_join(TodoProject)
    .filter(todo_project::Column::ProjectSerialNum.eq(project_id.clone()))
    .all(db)
    .await?;
```

### 查询任务所属的所有项目

```rust
use entity::{todo_project, project};

let projects = Project::find()
    .inner_join(TodoProject)
    .filter(todo_project::Column::TodoSerialNum.eq(todo_id.clone()))
    .all(db)
    .await?;
```

### 从项目中移除任务

```rust
TodoProject::delete_many()
    .filter(todo_project::Column::TodoSerialNum.eq(todo_id.clone()))
    .filter(todo_project::Column::ProjectSerialNum.eq(project_id.clone()))
    .exec(db)
    .await?;
```

## ⚠️ 注意事项

1. **复合主键**: 同一任务在同一项目中只能出现一次
2. **排序字段**: `order_index` 可用于看板列或列表排序，更新时注意并发
3. **级联删除**: 删除项目或任务会自动删除关联记录
4. **统计信息**: 项目下任务数量、完成率等依赖于此表进行聚合

## 🔗 相关表

- [todo - 待办事项表](../business/todo.md)
- [project - 项目表](../business/project.md)

---

**最后更新**: 2025-11-15  
[← 返回索引](../README.md)
