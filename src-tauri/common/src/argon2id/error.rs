// -----------------------------------------------------------------------------
//    Copyright (C) 2025 mcge. All rights reserved.
// Author:         mcge
// Email:          <mcgeq@outlook.com>
// File:           error.rs
// Description:    About Argon2 Error
// Create   Date:  2025-05-26 10:55:36
// Last Modified:  2025-08-06 20:24:53
// Modified   By:  mcgeq <mcgeq@outlook.com>
// -----------------------------------------------------------------------------

use snafu::{Snafu, Backtrace};
use crate::{
    error::ErrorExt,
    BusinessCode,
};

/// Argon2 密码哈希错误
#[derive(Debug, Snafu)]
#[snafu(visibility(pub))]
pub enum Argon2ErrorWrapper {
    #[snafu(display("Password hashing failed: {}", reason))]
    HashingFailed {
        reason: String,
        #[snafu(backtrace)]
        backtrace: Backtrace,
    },

    #[snafu(display("Password verification failed: {}", reason))]
    VerificationFailed {
        reason: String,
        #[snafu(backtrace)]
        backtrace: Backtrace,
    },

    #[snafu(display("Invalid password format: {}", reason))]
    InvalidFormat {
        reason: String,
        #[snafu(backtrace)]
        backtrace: Backtrace,
    },

    #[snafu(display("Argon2 configuration error: {}", reason))]
    ConfigError {
        reason: String,
        #[snafu(backtrace)]
        backtrace: Backtrace,
    },
}

impl ErrorExt for Argon2ErrorWrapper {
    fn business_code(&self) -> BusinessCode {
        match self {
            Self::HashingFailed { .. } => BusinessCode::PasswordHashError,
            Self::VerificationFailed { .. } => BusinessCode::PasswordVerifyError,
            Self::InvalidFormat { .. } => BusinessCode::PasswordFormatError,
            Self::ConfigError { .. } => BusinessCode::ConfigError,
        }
    }

    fn description(&self) -> &'static str {
        match self {
            Self::HashingFailed { .. } => "Password hashing failed",
            Self::VerificationFailed { .. } => "Password verification failed",
            Self::InvalidFormat { .. } => "Invalid password format",
            Self::ConfigError { .. } => "Argon2 configuration error",
        }
    }

    fn extra_data(&self) -> Option<serde_json::Value> {
        match self {
            Self::HashingFailed { reason, .. } => Some(serde_json::json!({ "reason": reason })),
            Self::VerificationFailed { reason, .. } => Some(serde_json::json!({ "reason": reason })),
            Self::InvalidFormat { reason, .. } => Some(serde_json::json!({ "reason": reason })),
            Self::ConfigError { reason, .. } => Some(serde_json::json!({ "reason": reason })),
        }
    }

    fn backtrace(&self) -> Option<Backtrace> {
        match self {
            Self::HashingFailed { backtrace, .. } => Some(backtrace.clone()),
            Self::VerificationFailed { backtrace, .. } => Some(backtrace.clone()),
            Self::InvalidFormat { backtrace, .. } => Some(backtrace.clone()),
            Self::ConfigError { backtrace, .. } => Some(backtrace.clone()),
        }
    }
}
