use serde_json::{Map, Value};

/// 敏感字段列表
const SENSITIVE_FIELDS: &[&str] = &[
    "password",
    "token",
    "access_token",
    "refresh_token",
    "secret",
    "api_key",
    "private_key",
    "phone",
    "email",
    "id_card",
    "bank_card",
    "credit_card",
    "ssn",
    "passport",
];

/// 脱敏策略
#[derive(Debug, Clone, Copy)]
pub enum SanitizeStrategy {
    /// 完全隐藏 - 显示为 "***"
    FullMask,
    /// 部分显示 - 显示前后几位，中间用 * 替代
    PartialMask { prefix: usize, suffix: usize },
    /// 哈希 - 显示值的哈希
    Hash,
}

impl Default for SanitizeStrategy {
    fn default() -> Self {
        Self::FullMask
    }
}

/// 日志脱敏器
pub struct LogSanitizer {
    sensitive_fields: Vec<String>,
    strategy: SanitizeStrategy,
}

impl Default for LogSanitizer {
    fn default() -> Self {
        Self::new()
    }
}

impl LogSanitizer {
    pub fn new() -> Self {
        Self {
            sensitive_fields: SENSITIVE_FIELDS.iter().map(|s| s.to_string()).collect(),
            strategy: SanitizeStrategy::FullMask,
        }
    }

    pub fn with_strategy(mut self, strategy: SanitizeStrategy) -> Self {
        self.strategy = strategy;
        self
    }

    pub fn add_sensitive_field(mut self, field: impl Into<String>) -> Self {
        self.sensitive_fields.push(field.into());
        self
    }

    /// 脱敏 JSON 值
    pub fn sanitize(&self, value: &Value) -> Value {
        match value {
            Value::Object(map) => {
                let mut sanitized = Map::new();
                for (key, val) in map {
                    let sanitized_val = if self.is_sensitive_field(key) {
                        self.mask_value(val)
                    } else {
                        self.sanitize(val)
                    };
                    sanitized.insert(key.clone(), sanitized_val);
                }
                Value::Object(sanitized)
            }
            Value::Array(arr) => Value::Array(arr.iter().map(|v| self.sanitize(v)).collect()),
            _ => value.clone(),
        }
    }

    /// 检查是否为敏感字段
    fn is_sensitive_field(&self, field: &str) -> bool {
        self.sensitive_fields
            .iter()
            .any(|f| field.to_lowercase().contains(&f.to_lowercase()))
    }

    /// 脱敏值
    fn mask_value(&self, value: &Value) -> Value {
        match self.strategy {
            SanitizeStrategy::FullMask => Value::String("***".to_string()),
            SanitizeStrategy::PartialMask { prefix, suffix } => {
                if let Value::String(s) = value {
                    Value::String(self.partial_mask(s, prefix, suffix))
                } else {
                    Value::String("***".to_string())
                }
            }
            SanitizeStrategy::Hash => {
                if let Value::String(s) = value {
                    let hash = self.simple_hash(s);
                    Value::String(format!("hash:{:x}", hash))
                } else {
                    Value::String("***".to_string())
                }
            }
        }
    }

    /// 部分脱敏
    fn partial_mask(&self, value: &str, prefix: usize, suffix: usize) -> String {
        let len = value.len();
        if len <= prefix + suffix {
            return "*".repeat(len);
        }

        let prefix_str = &value[..prefix];
        let suffix_str = &value[len - suffix..];
        let mask_len = len - prefix - suffix;

        format!("{}{}{}", prefix_str, "*".repeat(mask_len), suffix_str)
    }

    /// 简单哈希
    fn simple_hash(&self, value: &str) -> u64 {
        use std::collections::hash_map::DefaultHasher;
        use std::hash::{Hash, Hasher};

        let mut hasher = DefaultHasher::new();
        value.hash(&mut hasher);
        hasher.finish()
    }
}

/// 变更追踪器
pub struct ChangeTracker;

impl ChangeTracker {
    /// 提取变更字段
    pub fn extract_changes(before: &Value, after: &Value) -> Option<Map<String, Value>> {
        match (before, after) {
            (Value::Object(before_map), Value::Object(after_map)) => {
                let mut changes = Map::new();

                // 检查修改和新增的字段
                for (key, after_val) in after_map {
                    match before_map.get(key) {
                        Some(before_val) if before_val != after_val => {
                            changes.insert(
                                key.clone(),
                                serde_json::json!({
                                    "before": before_val,
                                    "after": after_val
                                }),
                            );
                        }
                        None => {
                            changes.insert(
                                key.clone(),
                                serde_json::json!({
                                    "before": null,
                                    "after": after_val
                                }),
                            );
                        }
                        _ => {}
                    }
                }

                // 检查删除的字段
                for (key, before_val) in before_map {
                    if !after_map.contains_key(key) {
                        changes.insert(
                            key.clone(),
                            serde_json::json!({
                                "before": before_val,
                                "after": null
                            }),
                        );
                    }
                }

                if changes.is_empty() {
                    None
                } else {
                    Some(changes)
                }
            }
            _ => None,
        }
    }

    /// 提取仅有值的变更字段（简化版）
    pub fn extract_changed_values(before: &Value, after: &Value) -> Option<Map<String, Value>> {
        match (before, after) {
            (Value::Object(before_map), Value::Object(after_map)) => {
                let mut changes = Map::new();

                for (key, after_val) in after_map {
                    if let Some(before_val) = before_map.get(key) {
                        if before_val != after_val {
                            changes.insert(key.clone(), after_val.clone());
                        }
                    } else {
                        changes.insert(key.clone(), after_val.clone());
                    }
                }

                if changes.is_empty() {
                    None
                } else {
                    Some(changes)
                }
            }
            _ => None,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    #[test]
    fn test_sanitize_full_mask() {
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
    fn test_sanitize_partial_mask() {
        let sanitizer = LogSanitizer::new().with_strategy(SanitizeStrategy::PartialMask {
            prefix: 2,
            suffix: 2,
        });
        let data = json!({
            "phone": "13812345678"
        });

        let sanitized = sanitizer.sanitize(&data);
        assert_eq!(sanitized["phone"], "13*******78");
    }

    #[test]
    fn test_extract_changes() {
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

        let changes = ChangeTracker::extract_changed_values(&before, &after).unwrap();
        assert_eq!(changes.len(), 3);
        assert_eq!(changes["age"], 26);
        assert_eq!(changes["email"], "new@example.com");
        assert_eq!(changes["phone"], "123456");
    }
}
