// -----------------------------------------------------------------------------
//    Copyright (C) 2025 mcge. All rights reserved.
// Author:         mcge
// Email:          <mcgeq@outlook.com>
// File:           error.rs
// Description:    About Argon2 Error
// Create   Date:  2025-05-26 10:55:36
// Last Modified:  2025-05-29 22:00:05
// Modified   By:  mcgeq <mcgeq@outlook.com>
// -----------------------------------------------------------------------------

use miji_derive::CodeMessage;
use snafu::Snafu;

use crate::{
    business_code::BusinessCode,
    error::{CodeMessage, MijiError},
};

#[derive(Debug, Snafu, CodeMessage)]
pub enum Argon2ErrorWrapper {
    #[snafu(display("Argon2 error: [{code}:{message}]"))]
    Hash { code: BusinessCode, message: String },
}

impl From<Argon2ErrorWrapper> for MijiError {
    fn from(value: Argon2ErrorWrapper) -> Self {
        MijiError::Argon2(Box::new(value))
    }
}
