# notification_settings - 通知设置表

[← 返回索引](../README.md)

## 📋 表信息

- **表名**: `notification_settings`
- **说明**: 通知设置表，用于存储用户对不同类型通知的开启/静音/免打扰等偏好
- **主键**: `serial_num`
- **创建迁移**: `m20250803_132251_create_notification_settings.rs`

## 📊 表结构

### 字段说明

| 字段名 | 类型 | 长度/精度 | 约束 | 默认值 | 说明 |
|--------|------|-----------|------|--------|------|
| `serial_num` | VARCHAR | 38 | PK, NOT NULL | - | 设置记录唯一ID |
| `user_id` | VARCHAR | 38 | FK, NOT NULL | - | 所属用户ID（users.serial_num） |
| `notification_type` | VARCHAR | 50 | NOT NULL | - | 通知类型（如 TodoReminder/BillReminder/System 等） |
| `enabled` | BOOLEAN | - | NOT NULL | true | 是否启用该类通知 |
| `quiet_hours_start` | TIME | - | NULLABLE | NULL | 免打扰开始时间 |
| `quiet_hours_end` | TIME | - | NULLABLE | NULL | 免打扰结束时间 |
| `quiet_days` | JSON | - | NULLABLE | NULL | 免打扰的星期列表（如 ["Sat", "Sun"]） |
| `sound_enabled` | BOOLEAN | - | NOT NULL | true | 是否启用声音 |
| `vibration_enabled` | BOOLEAN | - | NOT NULL | true | 是否启用震动 |
| `created_at` | TIMESTAMP WITH TIME ZONE | - | NOT NULL | - | 创建时间 |
| `updated_at` | TIMESTAMP WITH TIME ZONE | - | NULLABLE | NULL | 最后更新时间 |

## 🔗 关系说明

### 外键关系

| 关系类型 | 目标表 | 关联字段 | 级联操作 | 说明 |
|---------|--------|---------|---------|------|
| BELONGS_TO | `users` | `user_id` → `serial_num` | ON DELETE: CASCADE | 所属用户 |

## 📑 索引建议

```sql
PRIMARY KEY (serial_num);

CREATE INDEX idx_notification_settings_user 
  ON notification_settings(user_id);

CREATE INDEX idx_notification_settings_type 
  ON notification_settings(notification_type);
```

## 💡 使用示例

### 为用户创建默认通知设置

```rust
use entity::notification_settings;
use sea_orm::*;

let settings = notification_settings::ActiveModel {
    serial_num: Set(McgUuid::new().to_string()),
    user_id: Set(user_id.clone()),
    notification_type: Set("TodoReminder".to_string()),
    enabled: Set(true),
    sound_enabled: Set(true),
    vibration_enabled: Set(true),
    created_at: Set(Utc::now().into()),
    ..Default::default()
};

let result = settings.insert(db).await?;
```

## ⚠️ 注意事项

1. **免打扰逻辑**：`quiet_hours_*` 与 `quiet_days` 需要在通知服务中统一解析和应用
2. **类型枚举**：`notification_type` 建议在服务层维护枚举常量，避免拼写不一致
3. **用户删除**：删除用户时会级联删除其通知设置

## 🔗 相关表

- [users - 用户表](../core/users.md)

---

**最后更新**: 2025-11-15  
[← 返回索引](../README.md)
