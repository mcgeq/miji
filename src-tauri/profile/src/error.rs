use common::{business_code::BusinessCode, error::MijiError};
use snafu::Snafu;

#[derive(Debug, Snafu)]
pub enum ProfileError {
    #[snafu(display("Profile not found: {message}"))]
    NotFound { code: BusinessCode, message: String },

    #[snafu(display("Failed to update profile: {message}"))]
    UpdateFailed {
        code: BusinessCode,
        message: String,
        source: std::io::Error,
    },
}

impl From<ProfileError> for MijiError {
    fn from(value: ProfileError) -> Self {
        MijiError::Profile(Box::new(value))
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::io;

    #[test]
    fn test_profile_error_display_not_found() {
        let err = ProfileError::NotFound {
            code: BusinessCode::InvalidData,
            message: 42.to_string(),
        };
        let err_msg = format!("{err}");
        assert_eq!(err_msg, "Profile not found: 42");
    }

    #[test]
    fn test_profile_error_display_update_failed() {
        // 用一个模拟的io错误构造
        let io_err = io::Error::other("disk full");
        let err = ProfileError::UpdateFailed {
            code: BusinessCode::InvalidData,
            message: "s".to_string(),
            source: io_err,
        };
        let err_msg = format!("{err}");
        // 包含 UpdateFailed 显示信息和底层io错误消息
        assert!(err_msg.contains("Failed to update profile:"));
        assert!(err_msg.contains("disk full"));
    }

    #[test]
    fn test_profile_error_display_from_miji_error() {
        let err = ProfileError::NotFound {
            code: BusinessCode::InvalidData,
            message: 42.to_string(),
        };
        let miji_err: MijiError = err.into();
        assert_eq!(miji_err.to_string(), "Profile not found: user_id = 43");
    }
}
