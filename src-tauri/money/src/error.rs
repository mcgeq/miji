// -----------------------------------------------------------------------------
//    Copyright (C) 2025 mcge. All rights reserved.
// Author:         mcge
// Email:          <mcgeq@outlook.com>
// File:           error.rs
// Description:    About Money Error
// Create   Date:  2025-06-06 13:16:07
// Last Modified:  2025-06-06 13:26:47
// Modified   By:  mcgeq <mcgeq@outlook.com>
// -----------------------------------------------------------------------------

use common::{
    business_code::BusinessCode,
    error::{CodeMessage, MijiError},
};
use miji_derive::CodeMessage;
use snafu::Snafu;

#[derive(Debug, Snafu, CodeMessage)]
pub enum MoneyError {
    #[snafu(display("Role not found"))]
    RoleNotFound { code: BusinessCode, message: String },

    #[snafu(display("Permission denied"))]
    PermissionDenied { code: BusinessCode, message: String },

    #[snafu(display("Other error: {message}"))]
    Other { code: BusinessCode, message: String },
}

impl From<MoneyError> for MijiError {
    fn from(value: MoneyError) -> Self {
        MijiError::Money(Box::new(value))
    }
}
