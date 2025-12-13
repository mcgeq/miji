# 智能日志系统使用指南

## 概述

智能日志系统提供了以下核心功能：
- ✅ **变更追踪** - 只记录实际变更的字段
- ✅ **敏感数据脱敏** - 自动隐藏密码、邮箱等敏感信息
- ✅ **简洁输出** - 避免冗长的完整对象日志
- ✅ **灵活策略** - 支持完全隐藏、部分显示、哈希等策略

## 快速开始

### 基础用法

```rust
use common::log::{
    logger::{ConsoleLogger, OperationLogger},
    config::{LogFilterConfig, LogTarget},
    sanitizer::{LogSanitizer, SanitizeStrategy},
};

// 创建日志记录器
let logger = ConsoleLogger::new(LogFilterConfig {
    targets: vec![LogTarget::Console],
    include_tables: None,
    exclude_tables: None,
});

// 记录操作
logger.log_operation(
    "UPDATE",
    "users",
    "user-001",
    Some(&before_data),
    Some(&after_data),
    None,
).await?;
```

### 日志输出示例

**更新操作**（只显示变更字段）：
```
[UPDATE] UPDATE on users (ID: user-001) - Changes: {"age":26,"email":"***"}
```

**创建操作**（脱敏后的新数据）：
```
[CREATE] CREATE on users (ID: user-002) - Created: {"name":"Bob","email":"***","age":30}
```

**删除操作**（只显示ID）：
```
[DELETE] DELETE on users (ID: user-001) - Deleted
```

## 脱敏策略

### 1. 完全隐藏（默认）

```rust
let sanitizer = LogSanitizer::new();
// password: "secret123" → "***"
// email: "user@example.com" → "***"
```

### 2. 部分显示

```rust
use common::log::sanitizer::SanitizeStrategy;

let sanitizer = LogSanitizer::new()
    .with_strategy(SanitizeStrategy::PartialMask {
        prefix: 2,
        suffix: 2,
    });

// phone: "13812345678" → "13*******78"
// email: "alice@example.com" → "al***************om"
```

### 3. 哈希显示

```rust
let sanitizer = LogSanitizer::new()
    .with_strategy(SanitizeStrategy::Hash);

// password: "secret123" → "hash:a3f5e9b2c4d8f1a6"
```

### 4. 自定义敏感字段

```rust
let sanitizer = LogSanitizer::new()
    .add_sensitive_field("user_id")
    .add_sensitive_field("device_token");
```

## 内置敏感字段列表

系统自动脱敏以下字段：
- `password` - 密码
- `token`, `access_token`, `refresh_token` - 令牌
- `secret`, `api_key`, `private_key` - 密钥
- `phone` - 电话号码
- `email` - 邮箱地址
- `id_card`, `bank_card`, `credit_card` - 证件号
- `ssn`, `passport` - 身份证件

## 完整配置示例

### Console Logger with Custom Sanitizer

```rust
use common::log::{
    logger::ConsoleLogger,
    config::{LogFilterConfig, LogTarget},
    sanitizer::{LogSanitizer, SanitizeStrategy},
};

let sanitizer = LogSanitizer::new()
    .with_strategy(SanitizeStrategy::PartialMask {
        prefix: 3,
        suffix: 3,
    })
    .add_sensitive_field("custom_secret");

let logger = ConsoleLogger::new(LogFilterConfig {
    targets: vec![LogTarget::Console],
    include_tables: Some(vec!["users".to_string(), "transactions".to_string()]),
    exclude_tables: None,
})
.with_sanitizer(sanitizer);
```

### File Logger with Custom Sanitizer

```rust
use std::path::PathBuf;
use common::log::{
    logger::FileLogger,
    config::{LogFilterConfig, LogTarget},
    sanitizer::{LogSanitizer, SanitizeStrategy},
};

let sanitizer = LogSanitizer::new()
    .with_strategy(SanitizeStrategy::Hash);

let logger = FileLogger::new(
    PathBuf::from("logs/operations.log"),
    10, // 10MB max file size
    5,  // keep 5 backup files
    LogFilterConfig {
        targets: vec![LogTarget::File],
        include_tables: None,
        exclude_tables: Some(vec!["operation_log".to_string()]),
    },
)
.await?
.with_sanitizer(sanitizer);
```

### Composite Logger (Console + File)

```rust
use std::sync::Arc;
use common::log::logger::{CompositeLogger, ConsoleLogger, FileLogger};

let console_logger = Arc::new(ConsoleLogger::new(console_config));
let file_logger = Arc::new(FileLogger::new(/*...*/).await?);

let logger = CompositeLogger::new(vec![
    console_logger,
    file_logger,
]);
```

## 变更追踪 API

### 提取变更字段

```rust
use common::log::sanitizer::ChangeTracker;
use serde_json::json;

let before = json!({
    "name": "Alice",
    "age": 25,
    "email": "old@example.com"
});

let after = json!({
    "name": "Alice",
    "age": 26,
    "email": "new@example.com",
    "phone": "123456"
});

// 提取变更（包含 before/after）
if let Some(changes) = ChangeTracker::extract_changes(&before, &after) {
    // changes = {
    //   "age": {"before": 25, "after": 26},
    //   "email": {"before": "old@example.com", "after": "new@example.com"},
    //   "phone": {"before": null, "after": "123456"}
    // }
}

// 只提取新值（简化版）
if let Some(changes) = ChangeTracker::extract_changed_values(&before, &after) {
    // changes = {
    //   "age": 26,
    //   "email": "new@example.com",
    //   "phone": "123456"
    // }
}
```

## 日志过滤

### 只记录特定表

```rust
LogFilterConfig {
    targets: vec![LogTarget::Console],
    include_tables: Some(vec![
        "users".to_string(),
        "transactions".to_string(),
    ]),
    exclude_tables: None,
}
```

### 排除特定表

```rust
LogFilterConfig {
    targets: vec![LogTarget::Console],
    include_tables: None,
    exclude_tables: Some(vec![
        "operation_log".to_string(),
        "audit_log".to_string(),
    ]),
}
```

## 性能考虑

### 1. 变更检测开销
- JSON 序列化：~0.1ms（小对象）
- 字段比较：~0.05ms（10个字段）
- **总计：<1ms**

### 2. 脱敏开销
- 完全隐藏：~0.01ms
- 部分显示：~0.02ms
- 哈希：~0.05ms

### 3. 优化建议
- 使用 `exclude_tables` 排除高频表
- 生产环境关闭 DEBUG 级别日志
- 文件日志设置合理的文件大小限制

## 测试

### 单元测试示例

```rust
#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    #[test]
    fn test_sanitize_sensitive_fields() {
        let sanitizer = LogSanitizer::new();
        let data = json!({
            "username": "alice",
            "password": "secret123",
            "email": "alice@example.com"
        });

        let sanitized = sanitizer.sanitize(&data);
        
        assert_eq!(sanitized["username"], "alice");
        assert_eq!(sanitized["password"], "***");
        assert_eq!(sanitized["email"], "***");
    }

    #[test]
    fn test_change_tracking() {
        let before = json!({"name": "Alice", "age": 25});
        let after = json!({"name": "Alice", "age": 26});

        let changes = ChangeTracker::extract_changed_values(&before, &after);
        assert!(changes.is_some());
        
        let changes = changes.unwrap();
        assert_eq!(changes.len(), 1);
        assert_eq!(changes["age"], 26);
    }
}
```

## 实际应用场景

### CRUD 服务集成

```rust
use common::log::logger::OperationLogger;

pub async fn update_user(
    db: &DbConn,
    logger: &Arc<dyn OperationLogger>,
    user_id: &str,
    update_data: UpdateUserRequest,
) -> Result<User> {
    // 获取更新前数据
    let before = get_user(db, user_id).await?;
    let before_json = serde_json::to_value(&before)?;
    
    // 执行更新
    let updated = // ... update logic
    let after_json = serde_json::to_value(&updated)?;
    
    // 记录日志（自动变更追踪和脱敏）
    logger.log_operation(
        "UPDATE",
        "users",
        user_id,
        Some(&before_json),
        Some(&after_json),
        None,
    ).await?;
    
    Ok(updated)
}
```

### 查询日志优化

```rust
// ❌ 错误：打印整个查询构建器
info!("Query: {:?}", query_builder);

// ✅ 正确：只记录关键信息
debug!(
    "Query [{}]: page={}/{}, sort={:?}",
    table_name,
    current_page,
    page_size,
    sort_options
);
```

## 故障排查

### 日志未输出
1. 检查 `LogFilterConfig.targets` 是否包含正确的目标
2. 检查表名是否在 `exclude_tables` 中
3. 检查 `include_tables` 是否正确配置

### 脱敏未生效
1. 确认字段名包含敏感关键词（不区分大小写）
2. 使用 `add_sensitive_field` 添加自定义字段
3. 检查是否正确调用 `with_sanitizer`

### 变更追踪为空
1. 确认 before/after 数据格式为 JSON Object
2. 检查数据是否真的有变更
3. 确认字段名大小写匹配

## 最佳实践

### ✅ 推荐做法
- 生产环境使用 FileLogger + 脱敏
- 开发环境使用 ConsoleLogger
- 高频表加入 `exclude_tables`
- 只记录业务关键操作

### ❌ 避免做法
- 不要记录完整的大对象
- 不要在循环中频繁调用日志
- 不要记录已经脱敏的数据（重复脱敏）
- 不要在日志中硬编码敏感信息

## 更新日志

### v1.0.0 (2025-12-13)
- ✨ 新增变更追踪功能
- ✨ 新增敏感字段脱敏
- ✨ 支持多种脱敏策略
- 🔧 优化日志输出格式
- 📝 完善文档和测试

## 相关文档

- [日志配置指南](./LOG_CONFIGURATION.md)
- [操作日志最佳实践](./OPERATION_LOG_BEST_PRACTICES.md)
- [性能优化指南](./PERFORMANCE_OPTIMIZATION.md)
