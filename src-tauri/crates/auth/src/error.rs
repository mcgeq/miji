use common::{business_code::BusinessCode, error::common::ErrorExt};
use snafu::{Backtrace, Snafu};

/// 认证相关错误
#[derive(Debug, Snafu)]
#[snafu(visibility(pub))]
pub enum AuthError {
    #[snafu(display("Invalid parameter: {}", param))]
    InvalidParameter {
        param: String,
        #[snafu(backtrace)]
        backtrace: Backtrace,
    },

    #[snafu(display("Authentication failed: {}", reason))]
    AuthenticationFailed {
        reason: String,
        #[snafu(backtrace)]
        backtrace: Backtrace,
    },

    #[snafu(display("Session expired"))]
    SessionExpired {
        #[snafu(backtrace)]
        backtrace: Backtrace,
    },

    #[snafu(display("Invalid token: {}", token))]
    TokenInvalid {
        token: String,
        #[snafu(backtrace)]
        backtrace: Backtrace,
    },

    #[snafu(display("Insufficient permissions for {}", resource))]
    InsufficientPermissions {
        resource: String,
        #[snafu(backtrace)]
        backtrace: Backtrace,
    },

    #[snafu(display("Refresh token expired"))]
    RefreshTokenExpired {
        #[snafu(backtrace)]
        backtrace: Backtrace,
    },

    #[snafu(display("Invalid credentials"))]
    InvalidCredentials {
        #[snafu(backtrace)]
        backtrace: Backtrace,
    },

    #[snafu(display("Account locked"))]
    AccountLocked {
        #[snafu(backtrace)]
        backtrace: Backtrace,
    },

    #[snafu(display("Account not verified"))]
    AccountNotVerified {
        #[snafu(backtrace)]
        backtrace: Backtrace,
    },

    #[snafu(display("Two-factor authentication required"))]
    TwoFactorRequired {
        #[snafu(backtrace)]
        backtrace: Backtrace,
    },

    #[snafu(display("Two-factor authentication failed"))]
    TwoFactorFailed {
        #[snafu(backtrace)]
        backtrace: Backtrace,
    },
}

impl ErrorExt for AuthError {
    fn business_code(&self) -> BusinessCode {
        match self {
            Self::InvalidParameter { .. } => BusinessCode::InvalidParameter,
            Self::AuthenticationFailed { .. } => BusinessCode::AuthenticationFailed,
            Self::SessionExpired { .. } => BusinessCode::SessionExpired,
            Self::TokenInvalid { .. } => BusinessCode::TokenInvalid,
            Self::InsufficientPermissions { .. } => BusinessCode::InsufficientPermissions,
            Self::RefreshTokenExpired { .. } => BusinessCode::RefreshTokenExpired,
            Self::InvalidCredentials { .. } => BusinessCode::InvalidCredentials,
            Self::AccountLocked { .. } => BusinessCode::AccountLocked,
            Self::AccountNotVerified { .. } => BusinessCode::AccountNotVerified,
            Self::TwoFactorRequired { .. } => BusinessCode::TwoFactorRequired,
            Self::TwoFactorFailed { .. } => BusinessCode::TwoFactorFailed,
        }
    }

    fn description(&self) -> &'static str {
        self.business_code().description()
    }

    fn extra_data(&self) -> Option<serde_json::Value> {
        match self {
            Self::InvalidParameter { param, .. } => Some(serde_json::json!({ "param": param })),
            Self::AuthenticationFailed { reason, .. } => {
                Some(serde_json::json!({ "reason": reason }))
            }
            Self::SessionExpired { .. } => None,
            Self::TokenInvalid { token, .. } => Some(serde_json::json!({ "token": token })),
            Self::InsufficientPermissions { resource, .. } => {
                Some(serde_json::json!({ "resource": resource }))
            }
            Self::RefreshTokenExpired { .. } => None,
            Self::InvalidCredentials { .. } => None,
            Self::AccountLocked { .. } => None,
            Self::AccountNotVerified { .. } => None,
            Self::TwoFactorRequired { .. } => None,
            Self::TwoFactorFailed { .. } => None,
        }
    }

    fn backtrace(&self) -> Option<Backtrace> {
        match self {
            Self::InvalidParameter { backtrace, .. } => Some(backtrace.clone()),
            Self::AuthenticationFailed { backtrace, .. } => Some(backtrace.clone()),
            Self::SessionExpired { backtrace, .. } => Some(backtrace.clone()),
            Self::TokenInvalid { backtrace, .. } => Some(backtrace.clone()),
            Self::InsufficientPermissions { backtrace, .. } => Some(backtrace.clone()),
            Self::RefreshTokenExpired { backtrace, .. } => Some(backtrace.clone()),
            Self::InvalidCredentials { backtrace, .. } => Some(backtrace.clone()),
            Self::AccountLocked { backtrace, .. } => Some(backtrace.clone()),
            Self::AccountNotVerified { backtrace, .. } => Some(backtrace.clone()),
            Self::TwoFactorRequired { backtrace, .. } => Some(backtrace.clone()),
            Self::TwoFactorFailed { backtrace, .. } => Some(backtrace.clone()),
        }
    }
}
