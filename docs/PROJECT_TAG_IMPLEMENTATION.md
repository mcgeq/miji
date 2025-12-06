# Project-Tag 关联表实现文档

## 📋 概述

`project_tag` 表用于实现项目和标签之间的多对多关系，允许为项目直接打标签，提供更灵活的项目分类和筛选功能。

## 🗂️ 表结构

### 字段定义

| 字段名 | 类型 | 约束 | 说明 |
|--------|------|------|------|
| `project_serial_num` | TEXT(38) | PRIMARY KEY, NOT NULL | 项目序列号（外键） |
| `tag_serial_num` | TEXT(38) | PRIMARY KEY, NOT NULL | 标签序列号（外键） |
| `orders` | INTEGER | NULL | 排序字段，用于标签显示顺序 |
| `created_at` | TIMESTAMP | NOT NULL | 创建时间 |
| `updated_at` | TIMESTAMP | NULL | 更新时间 |

### 索引

- **主键索引**：`(project_serial_num, tag_serial_num)`
- **查询索引**：
  - `idx_project_tag_project` - 加速通过项目查询标签
  - `idx_project_tag_tag` - 加速通过标签查询项目

### 外键约束

- `project_serial_num` → `project(serial_num)` - CASCADE DELETE/UPDATE
- `tag_serial_num` → `tag(serial_num)` - CASCADE DELETE/UPDATE

## 🏗️ 数据模型关系

```
┌──────────┐       ┌─────────────┐       ┌─────┐
│ Project  │◄─────►│ project_tag │◄─────►│ Tag │
└──────────┘       └─────────────┘       └─────┘
     ▲                                      ▲
     │                                      │
     │            ┌─────────────┐           │
     └───────────►│ todo_project│           │
                  └─────────────┘           │
                        ▲                   │
                        │                   │
                  ┌──────────┐              │
                  │   Todo   │◄─────────────┘
                  └──────────┘   todo_tag
```

## 💡 业务场景

### 1. 项目分类
- 给项目打上"客户"、"内部"、"技术"等分类标签
- 支持多维度的项目分类

### 2. 项目筛选
```sql
-- 查询所有"技术"类项目
SELECT p.* FROM project p
JOIN project_tag pt ON p.serial_num = pt.project_serial_num
JOIN tag t ON pt.tag_serial_num = t.serial_num
WHERE t.name = '技术';
```

### 3. 标签统计
```sql
-- 统计每个标签被多少项目使用
SELECT t.name, COUNT(*) as project_count
FROM tag t
JOIN project_tag pt ON t.serial_num = pt.tag_serial_num
GROUP BY t.serial_num;
```

### 4. 项目标签管理
- 为项目添加标签
- 删除项目标签
- 调整标签显示顺序（通过 orders 字段）

## 📦 迁移文件

**文件位置**：`src-tauri/migration/src/m20251206_046_create_project_tag.rs`

**执行时机**：应用启动时自动执行

**回滚支持**：通过 `down()` 方法删除表

## 🔧 Entity 模型

**文件位置**：`src-tauri/entity/src/project_tag.rs`

**关系定义**：
- `Project` - belongs_to
- `Tag` - belongs_to

**特性**：
- 自动序列化/反序列化（Serde）
- 国际化支持（LocalizeModel）
- 级联删除（CASCADE）

## 📊 DTO 结构

### TagUsage
```rust
pub struct TagUsage {
    pub todos: UsageDetail,
    pub projects: UsageDetail,  // ← 现在会统计真实数据
}
```

### TagWithUsage
```rust
pub struct TagWithUsage {
    #[serde(flatten)]
    pub tag: Tag,
    pub usage: TagUsage,
}
```

### JSON 示例
```json
{
  "serialNum": "tag_123",
  "name": "技术",
  "description": "技术相关",
  "createdAt": "...",
  "updatedAt": "...",
  "usage": {
    "todos": {
      "count": 5,
      "serialNums": ["todo1", "todo2", ...]
    },
    "projects": {
      "count": 3,
      "serialNums": ["proj1", "proj2", "proj3"]
    }
  }
}
```

## 🔄 服务层实现

### Tags Service
```rust
pub async fn tag_list_with_usage(
    &self,
    db: &DbConn,
) -> MijiResult<Vec<TagWithUsage>> {
    // 1. 获取所有标签
    let tags = self.tag_list(db).await?;
    
    for tag in tags {
        // 2. 统计 todo 引用
        let todo_refs = todo_tag::Entity::find()
            .filter(todo_tag::Column::TagSerialNum.eq(&tag.serial_num))
            .all(db).await?;
        
        // 3. 统计 project 引用 ← 新增
        let project_refs = project_tag::Entity::find()
            .filter(project_tag::Column::TagSerialNum.eq(&tag.serial_num))
            .all(db).await?;
        
        // 4. 组装返回数据
        // ...
    }
}
```

## 🎯 前端展示

### 标签卡片
```vue
<!-- 引用计数显示 -->
<span v-if="'usage' in tag">
  <FileCheck :size="14" />
  {{ tag.usage.todos.count + tag.usage.projects.count }}
</span>
```

### 提示信息
```
被 5 个待办事项引用
被 3 个项目引用
共 8 个引用
```

## 📈 性能优化

### 1. 索引优化
- 通过项目查标签：使用 `idx_project_tag_project`
- 通过标签查项目：使用 `idx_project_tag_tag`

### 2. 批量查询
```rust
// 避免 N+1 查询
let all_project_tags = project_tag::Entity::find()
    .filter(project_tag::Column::TagSerialNum.is_in(tag_ids))
    .all(db).await?;
```

### 3. 缓存策略
- 可以缓存项目-标签关系
- TTL: 5-10 分钟

## 🚀 使用示例

### 1. 为项目添加标签
```rust
use entity::project_tag;

let new_relation = project_tag::ActiveModel {
    project_serial_num: Set("proj_123".to_string()),
    tag_serial_num: Set("tag_456".to_string()),
    orders: Set(Some(1)),
    created_at: Set(now),
    updated_at: Set(Some(now)),
};

project_tag::Entity::insert(new_relation)
    .exec(db).await?;
```

### 2. 删除项目标签
```rust
project_tag::Entity::delete_many()
    .filter(project_tag::Column::ProjectSerialNum.eq("proj_123"))
    .filter(project_tag::Column::TagSerialNum.eq("tag_456"))
    .exec(db).await?;
```

### 3. 获取项目的所有标签
```rust
let tags = tag::Entity::find()
    .inner_join(project_tag::Entity)
    .filter(project_tag::Column::ProjectSerialNum.eq("proj_123"))
    .order_by_asc(project_tag::Column::Orders)
    .all(db).await?;
```

### 4. 获取使用某标签的所有项目
```rust
let projects = project::Entity::find()
    .inner_join(project_tag::Entity)
    .filter(project_tag::Column::TagSerialNum.eq("tag_123"))
    .all(db).await?;
```

## ✅ 测试要点

### 1. 基本功能
- [ ] 创建项目-标签关联
- [ ] 删除项目-标签关联
- [ ] 更新标签顺序

### 2. 级联删除
- [ ] 删除项目时，自动删除相关 project_tag 记录
- [ ] 删除标签时，自动删除相关 project_tag 记录

### 3. 统计准确性
- [ ] tag_list_with_usage 返回正确的项目引用计数
- [ ] 前端显示正确的引用数量

### 4. 性能测试
- [ ] 大量标签时的查询性能
- [ ] 大量项目时的统计性能

## 🔮 未来扩展

### 1. 标签权重
- 添加 `weight` 字段，表示标签对项目的重要程度

### 2. 标签时间范围
- 添加 `start_date` 和 `end_date`，支持临时标签

### 3. 标签元数据
- 添加 `metadata` JSON 字段，存储额外信息

### 4. 自动标签建议
- 基于项目内容自动推荐标签

## 📚 相关文档

- [数据库设计文档](../database/README.md)
- [标签系统文档](./TAG_SYSTEM.md)
- [项目管理文档](./PROJECT_MANAGEMENT.md)

## 🎉 总结

`project_tag` 表的添加完善了标签系统的功能：

- ✅ 支持项目级别的标签管理
- ✅ 统一的标签体系（Todo + Project）
- ✅ 更强大的分类和筛选能力
- ✅ 完整的引用统计功能
- ✅ 对称的数据模型设计

现在整个系统的标签功能更加完善和强大了！🎯
