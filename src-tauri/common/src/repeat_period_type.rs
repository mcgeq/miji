use serde::{Deserialize, Serialize};
use std::str::FromStr;

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "PascalCase")]
pub enum RepeatPeriodType {
    None,
    Daily,
    Weekly,
    Monthly,
    Yearly,
    Custom,
}

impl RepeatPeriodType {
    /// 从字符串解析 RepeatPeriodType
    /// 支持大小写不敏感的匹配
    pub fn from_string(s: &str) -> Option<Self> {
        match s.to_lowercase().as_str() {
            "none" => Some(RepeatPeriodType::None),
            "daily" => Some(RepeatPeriodType::Daily),
            "weekly" => Some(RepeatPeriodType::Weekly),
            "monthly" => Some(RepeatPeriodType::Monthly),
            "yearly" => Some(RepeatPeriodType::Yearly),
            "custom" => Some(RepeatPeriodType::Custom),
            _ => None,
        }
    }

    /// 转换为字符串表示
    pub fn to_string(&self) -> String {
        match self {
            RepeatPeriodType::None => "None".to_string(),
            RepeatPeriodType::Daily => "Daily".to_string(),
            RepeatPeriodType::Weekly => "Weekly".to_string(),
            RepeatPeriodType::Monthly => "Monthly".to_string(),
            RepeatPeriodType::Yearly => "Yearly".to_string(),
            RepeatPeriodType::Custom => "Custom".to_string(),
        }
    }

    /// 检查是否为 None 类型
    pub fn is_none(&self) -> bool {
        matches!(self, RepeatPeriodType::None)
    }

    /// 检查是否需要重复处理
    pub fn needs_repeat_processing(&self) -> bool {
        !self.is_none()
    }
}

impl FromStr for RepeatPeriodType {
    type Err = String;

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        Self::from_string(s).ok_or_else(|| format!("Invalid repeat period type: {}", s))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_from_string() {
        assert_eq!(
            RepeatPeriodType::from_string("none"),
            Some(RepeatPeriodType::None)
        );
        assert_eq!(
            RepeatPeriodType::from_string("None"),
            Some(RepeatPeriodType::None)
        );
        assert_eq!(
            RepeatPeriodType::from_string("NONE"),
            Some(RepeatPeriodType::None)
        );
        assert_eq!(
            RepeatPeriodType::from_string("daily"),
            Some(RepeatPeriodType::Daily)
        );
        assert_eq!(
            RepeatPeriodType::from_string("Daily"),
            Some(RepeatPeriodType::Daily)
        );
        assert_eq!(
            RepeatPeriodType::from_string("weekly"),
            Some(RepeatPeriodType::Weekly)
        );
        assert_eq!(
            RepeatPeriodType::from_string("monthly"),
            Some(RepeatPeriodType::Monthly)
        );
        assert_eq!(
            RepeatPeriodType::from_string("yearly"),
            Some(RepeatPeriodType::Yearly)
        );
        assert_eq!(
            RepeatPeriodType::from_string("custom"),
            Some(RepeatPeriodType::Custom)
        );
        assert_eq!(RepeatPeriodType::from_string("invalid"), None);
    }

    #[test]
    fn test_to_string() {
        assert_eq!(RepeatPeriodType::None.to_string(), "None");
        assert_eq!(RepeatPeriodType::Daily.to_string(), "Daily");
        assert_eq!(RepeatPeriodType::Weekly.to_string(), "Weekly");
        assert_eq!(RepeatPeriodType::Monthly.to_string(), "Monthly");
        assert_eq!(RepeatPeriodType::Yearly.to_string(), "Yearly");
        assert_eq!(RepeatPeriodType::Custom.to_string(), "Custom");
    }

    #[test]
    fn test_is_none() {
        assert!(RepeatPeriodType::None.is_none());
        assert!(!RepeatPeriodType::Daily.is_none());
        assert!(!RepeatPeriodType::Weekly.is_none());
        assert!(!RepeatPeriodType::Monthly.is_none());
        assert!(!RepeatPeriodType::Yearly.is_none());
        assert!(!RepeatPeriodType::Custom.is_none());
    }

    #[test]
    fn test_needs_repeat_processing() {
        assert!(!RepeatPeriodType::None.needs_repeat_processing());
        assert!(RepeatPeriodType::Daily.needs_repeat_processing());
        assert!(RepeatPeriodType::Weekly.needs_repeat_processing());
        assert!(RepeatPeriodType::Monthly.needs_repeat_processing());
        assert!(RepeatPeriodType::Yearly.needs_repeat_processing());
        assert!(RepeatPeriodType::Custom.needs_repeat_processing());
    }

    #[test]
    fn test_from_str() {
        assert_eq!(
            "none".parse::<RepeatPeriodType>().unwrap(),
            RepeatPeriodType::None
        );
        assert_eq!(
            "Daily".parse::<RepeatPeriodType>().unwrap(),
            RepeatPeriodType::Daily
        );
        assert!("invalid".parse::<RepeatPeriodType>().is_err());
    }
}
