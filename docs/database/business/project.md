# project - 项目表

[← 返回索引](../README.md)

## 📋 表信息

- **表名**: `project`
- **说明**: 项目表，用于将多个待办事项归类到同一项目中（如「搬家计划」「版本发布」）
- **主键**: `serial_num`
- **创建迁移**: `m20250803_132241_create_project.rs`

## 📊 表结构

### 字段说明

| 字段名 | 类型 | 长度 | 约束 | 默认值 | 说明 |
|--------|------|------|------|--------|------|
| `serial_num` | VARCHAR | 38 | PK, NOT NULL | - | 项目唯一ID |
| `name` | VARCHAR | 100 | NOT NULL | - | 项目名称 |
| `description` | VARCHAR | 500 | NULLABLE | NULL | 项目描述 |
| `owner_id` | VARCHAR | 38 | NULLABLE | NULL | 项目所有者（用户ID） |
| `color` | VARCHAR | 7 | NULLABLE | NULL | 项目颜色（十六进制，如 #3B82F6） |
| `is_archived` | BOOLEAN | - | NOT NULL | false | 是否已归档 |
| `created_at` | TIMESTAMP WITH TIME ZONE | - | NOT NULL | - | 创建时间 |
| `updated_at` | TIMESTAMP WITH TIME ZONE | - | NULLABLE | NULL | 最后更新时间 |

## 🔗 关系说明

### 一对多关系

| 关系 | 目标表 | 说明 |
|------|--------|------|
| HAS_MANY | `todo_project` | 项目与待办的关联记录 |

### 多对多关系

| 关系 | 目标表 | 中间表 | 说明 |
|------|--------|--------|------|
| MANY_TO_MANY | `todo` | `todo_project` | 一个项目包含多个任务，一个任务可属于多个项目 |

## 📑 索引建议

```sql
PRIMARY KEY (serial_num);

CREATE INDEX idx_project_owner ON project(owner_id);
CREATE INDEX idx_project_archived ON project(is_archived);
```

## 💡 使用示例

### 创建项目

```rust
use entity::project;
use sea_orm::*;

let proj = project::ActiveModel {
    serial_num: Set(McgUuid::new().to_string()),
    name: Set("搬家计划".to_string()),
    description: Set(Some("整理物品、联系搬家公司、打扫新房".to_string())),
    owner_id: Set(Some(user_id.clone())),
    color: Set(Some("#3B82F6".to_string())),
    is_archived: Set(false),
    created_at: Set(Utc::now().into()),
    ..Default::default()
};

let result = proj.insert(db).await?;
```

### 查询用户的非归档项目

```rust
let projects = Project::find()
    .filter(project::Column::OwnerId.eq(user_id.clone()))
    .filter(project::Column::IsArchived.eq(false))
    .all(db)
    .await?;
```

### 归档项目

```rust
let proj = Project::find_by_id(project_id)
    .one(db)
    .await?
    .unwrap();

let mut active: project::ActiveModel = proj.into();
active.is_archived = Set(true);
active.updated_at = Set(Some(Utc::now().into()));

active.update(db).await?;
```

## ⚠️ 注意事项

1. **归档逻辑**: 建议通过 `is_archived` 控制是否在列表中显示，而不是物理删除
2. **颜色一致性**: `color` 用于 UI 标签、看板列等，需要统一配色方案
3. **项目成员**: 当前表只存 owner，如需多成员项目，可在业务层基于 todo 的 assignee/owner 推导
4. **统计信息**: 项目层面的任务数量、完成率等应在服务层聚合计算

## 🔗 相关表

- [todo - 待办事项表](./todo.md)
- [todo_project - 任务项目关联表](../association/todo_project.md)
- [users - 用户表](../core/users.md)

---

**最后更新**: 2025-11-15  
[← 返回索引](../README.md)
