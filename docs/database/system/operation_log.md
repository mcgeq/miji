# operation_log - 操作日志表

[← 返回索引](../README.md)

## 📋 表信息

- **表名**: `operation_log`
- **说明**: 操作日志表，用于记录关键数据变更操作（如创建/更新/删除账本、交易、设置等）
- **主键**: `serial_num`
- **创建迁移**: `m20250803_132253_create_operation_log.rs`

## 📊 表结构

### 字段说明

| 字段名 | 类型 | 长度/精度 | 约束 | 默认值 | 说明 |
|--------|------|-----------|------|--------|------|
| `serial_num` | VARCHAR | 38 | PK, NOT NULL | - | 操作日志唯一ID |
| `recorded_at` | TIMESTAMP WITH TIME ZONE | - | NOT NULL | - | 记录时间 |
| `operation` | VARCHAR | 50 | NOT NULL | - | 操作类型（如 Create/Update/Delete/Login 等） |
| `target_table` | VARCHAR | 50 | NOT NULL | - | 目标表名（如 family_ledger, transactions） |
| `record_id` | VARCHAR | 38 | NOT NULL | - | 目标记录ID（如账本 serial_num） |
| `actor_id` | VARCHAR | 50 | NOT NULL | - | 操作者ID（用户/系统身份标识） |
| `changes_json` | JSON | - | NULLABLE | NULL | 变更内容（如字段前后值对比） |
| `snapshot_json` | JSON | - | NULLABLE | NULL | 操作后记录的快照数据 |
| `device_id` | VARCHAR | 100 | NULLABLE | NULL | 设备ID（如客户端设备标识） |

## 📑 索引建议

```sql
PRIMARY KEY (serial_num);

CREATE INDEX idx_operation_log_table_record 
  ON operation_log(target_table, record_id);

CREATE INDEX idx_operation_log_actor 
  ON operation_log(actor_id);

CREATE INDEX idx_operation_log_time 
  ON operation_log(recorded_at DESC);
```

## 💡 使用示例

### 记录一次账本更新操作

```rust
use entity::operation_log;
use sea_orm::*;

let log = operation_log::ActiveModel {
    serial_num: Set(McgUuid::new().to_string()),
    recorded_at: Set(Utc::now().into()),
    operation: Set("Update".to_string()),
    target_table: Set("family_ledger".to_string()),
    record_id: Set(ledger_id.clone()),
    actor_id: Set(user_id.clone()),
    changes_json: Set(Some(json!({
      "name": { "old": "旧名字", "new": "新名字" },
      "members": { "old": 2, "new": 3 }
    }))),
    snapshot_json: Set(None),
    device_id: Set(Some("desktop-win11".to_string())),
    ..Default::default()
};

let result = log.insert(db).await?;
```

## ⚠️ 注意事项

1. **敏感信息**：不要在 `changes_json` 和 `snapshot_json` 中记录密码、token 等敏感信息
2. **日志量控制**：可按日期或条数定期归档/清理，避免无限增长
3. **审计用途**：该表对排查问题、审计操作非常关键，建议只追加不修改

---

**最后更新**: 2025-11-15  
[← 返回索引](../README.md)
