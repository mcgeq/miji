use snafu::Snafu;

#[derive(Debug, Snafu)]
pub enum ProfileError {
    #[snafu(display("Profile not found: user_id = {}", user_id))]
    NotFound { user_id: u64 },

    #[snafu(display("Failed to update profile: {}", source))]
    UpdateFailed { source: std::io::Error },
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::io;

    #[test]
    fn test_profile_error_display_not_found() {
        let err = ProfileError::NotFound { user_id: 42 };
        let err_msg = format!("{err}");
        assert_eq!(err_msg, "Profile not found: user_id = 42");
    }

    #[test]
    fn test_profile_error_display_update_failed() {
        // 用一个模拟的io错误构造
        let io_err = io::Error::other("disk full");
        let err = ProfileError::UpdateFailed { source: io_err };
        let err_msg = format!("{err}");
        // 包含 UpdateFailed 显示信息和底层io错误消息
        assert!(err_msg.contains("Failed to update profile:"));
        assert!(err_msg.contains("disk full"));
    }
}
