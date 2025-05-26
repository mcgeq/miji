// -----------------------------------------------------------------------------
//    Copyright (C) 2025 mcge. All rights reserved.
// Author:         mcge
// Email:          <mcgeq@outlook.com>
// File:           error.rs
// Description:    About Argon2 Error
// Create   Date:  2025-05-26 10:55:36
// Last Modified:  2025-05-26 11:06:30
// Modified   By:  mcgeq <mcgeq@outlook.com>
// -----------------------------------------------------------------------------

use snafu::Snafu;

use crate::{business_code::BusinessCode, error::MijiError};

#[derive(Debug, Snafu)]
pub enum Argon2ErrorWrapper {
    #[snafu(display("Argon2 operation failure: [{code}:{message}]"))]
    Argon2 { code: BusinessCode, message: String },
    #[snafu(display("Hash operation failure: [{code}:{message}]"))]
    Hash { code: BusinessCode, message: String },
}

impl From<Argon2ErrorWrapper> for MijiError {
    fn from(value: Argon2ErrorWrapper) -> Self {
        MijiError::Argon2(Box::new(value))
    }
}
