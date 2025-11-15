# attachment - 附件表

[← 返回索引](../README.md)

## 📋 表信息

- **表名**: `attachment`
- **说明**: 附件表，用于为 `todo` 等实体保存图片、文件等附件信息
- **主键**: `serial_num`
- **创建迁移**: `m20250803_132250_create_attachment.rs`

## 📊 表结构

### 字段说明

| 字段名 | 类型 | 长度 | 约束 | 默认值 | 说明 |
|--------|------|------|------|--------|------|
| `serial_num` | VARCHAR | 38 | PK, NOT NULL | - | 附件唯一ID |
| `todo_serial_num` | VARCHAR | 38 | FK, NOT NULL | - | 所属待办ID（todo.serial_num） |
| `file_path` | VARCHAR | 500 | NULLABLE | NULL | 本地文件路径（相对/绝对路径，视实现而定） |
| `url` | VARCHAR | 500 | NULLABLE | NULL | 远程 URL（如云存储地址） |
| `file_name` | VARCHAR | 255 | NULLABLE | NULL | 原始文件名 |
| `mime_type` | VARCHAR | 100 | NULLABLE | NULL | MIME 类型（如 image/png） |
| `size` | INTEGER | - | NULLABLE | NULL | 文件大小（字节） |
| `created_at` | TIMESTAMP WITH TIME ZONE | - | NOT NULL | - | 创建时间 |
| `updated_at` | TIMESTAMP WITH TIME ZONE | - | NULLABLE | NULL | 最后更新时间 |

## 🔗 关系说明

### 外键关系

| 关系类型 | 目标表 | 关联字段 | 级联操作 | 说明 |
|---------|--------|---------|---------|------|
| BELONGS_TO | `todo` | `todo_serial_num` → `serial_num` | ON DELETE: CASCADE | 所属待办任务 |

## 📑 索引建议

```sql
PRIMARY KEY (serial_num);

CREATE INDEX idx_attachment_todo ON attachment(todo_serial_num);
```

## 💡 使用示例

### 为待办添加附件

```rust
use entity::attachment;
use sea_orm::*;

let att = attachment::ActiveModel {
    serial_num: Set(McgUuid::new().to_string()),
    todo_serial_num: Set(todo_id.clone()),
    file_path: Set(Some("/attachments/2025/receipt.png".to_string())),
    file_name: Set(Some("receipt.png".to_string())),
    mime_type: Set(Some("image/png".to_string())),
    size: Set(Some(1024 * 200)),
    created_at: Set(Utc::now().into()),
    ..Default::default()
};

let result = att.insert(db).await?;
```

## ⚠️ 注意事项

1. **存储策略**：`file_path`/`url` 的含义取决于具体实现，应统一约定（本地 vs 云存储）
2. **隐私与安全**：附件可能包含敏感信息，下载和访问必须做权限校验
3. **清理策略**：删除待办时，需考虑是否删除本地文件/远程文件

## 🔗 相关表

- [todo - 待办事项表](../business/todo.md)

---

**最后更新**: 2025-11-15  
[← 返回索引](../README.md)
