use serde::{
    de::{Deserialize, Deserializer, Error as DeError, Visitor},
    ser::{Error as SerError, Serializer},
};
use std::fmt;

pub fn serialize_i32_as_bool<S>(value: &i32, serializer: S) -> Result<S::Ok, S::Error>
where
    S: Serializer,
{
    serializer.serialize_bool(*value == 0)
}

pub fn deserialize_bool_as_i32<'de, D>(deserializer: D) -> Result<i32, D::Error>
where
    D: Deserializer<'de>,
{
    let b: bool = Deserialize::deserialize(deserializer)
        .map_err(|e| D::Error::custom(format!("Expected boolean, got {e}")))?;
    Ok(if b { 1 } else { 0 })
}

// 序列化函数：Option<i32> -> JSON 布尔值或 null（None → null，Some(0) → false，Some(1) → true）
pub fn serialize_option_i32_as_bool<S>(
    value: &Option<i32>,
    serializer: S,
) -> Result<S::Ok, S::Error>
where
    S: Serializer,
{
    match value {
        None => serializer.serialize_none(), // None 序列化为 JSON null
        Some(0) => serializer.serialize_bool(false), // Some(0) → false
        Some(1) => serializer.serialize_bool(true), // Some(1) → true
        Some(other) => {
            // 非 0/1 的值报错（由验证规则保证不会出现）
            Err(S::Error::custom(format!(
                "Invalid value {other} for is_verified, expected 0 or 1"
            )))
        }
    }
}

// 反序列化辅助函数：先尝试反序列化为 Option<bool>，再转换为 Option<i32>
pub fn deserialize_bool_as_option_i32<'de, D>(
    deserializer: D,
) -> Result<Option<i32>, D::Error>
where
    D: Deserializer<'de>,
{
    // 尝试反序列化为 Option<bool>（处理 JSON 中的 null、true、false）
    let opt_bool: Option<bool> = Deserialize::deserialize(deserializer)?;
    Ok(opt_bool.map(|b| if b { 1 } else { 0 }))
}

// 反序列化函数：处理 JSON 布尔值、整数或 null → Option<i32>
pub fn deserialize_bool_as_option_i32_helper<'de, D>(deserializer: D) -> Result<Option<i32>, D::Error>
where
    D: Deserializer<'de>,
{
    deserializer.deserialize_any(BoolOrIntVisitor)
}

// 自定义 Visitor 处理布尔值、整数（0/1）和 null
struct BoolOrIntVisitor;

impl<'de> Visitor<'de> for BoolOrIntVisitor {
    type Value = Option<i32>;

    // 定义反序列化时期望的输入类型描述
    fn expecting(&self, formatter: &mut fmt::Formatter) -> fmt::Result {
        formatter.write_str("boolean (true/false), integer (0/1), or null")
    }

    // 处理布尔值（true → 1，false → 0）
    fn visit_bool<E>(self, value: bool) -> Result<Self::Value, E>
    where
        E: DeError,
    {
        Ok(Some(if value { 1 } else { 0 }))
    }

    // 处理有符号整数（仅允许 0 或 1）
    fn visit_i64<E>(self, value: i64) -> Result<Self::Value, E>
    where
        E: DeError,
    {
        if value == 0 || value == 1 {
            Ok(Some(value as i32))
        } else {
            Err(E::custom(format!(
                "Invalid value {value} for is_verified, expected 0 or 1"
            )))
        }
    }

    // 处理无符号整数（仅允许 0 或 1）
    fn visit_u64<E>(self, value: u64) -> Result<Self::Value, E>
    where
        E: DeError,
    {
        if value == 0 || value == 1 {
            Ok(Some(value as i32))
        } else {
            Err(E::custom(format!(
                "Invalid value {value} for is_verified, expected 0 or 1"
            )))
        }
    }
}
