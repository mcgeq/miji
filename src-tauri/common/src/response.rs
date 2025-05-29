#![allow(dead_code)]
// -----------------------------------------------------------------------------
//    Copyright (C) 2025 mcge. All rights reserved.
// Author:         mcge
// Email:          <mcgeq@outlook.com>
// File:           response.rs
// Description:    About Response
// Create   Date:  2025-05-29 08:37:51
// Last Modified:  2025-05-29 11:18:26
// Modified   By:  mcgeq <mcgeq@outlook.com>
// -----------------------------------------------------------------------------

use serde::Deserialize;

use crate::{business_code::BusinessCode, error::MijiError};

#[derive(Debug, Deserialize)]
pub struct Res<T> {
    code: String,
    data: Option<T>,
    message: String,
}

impl<T> Res<T> {
    pub fn success(data: T) -> Self {
        Self {
            code: BusinessCode::Success.into(),
            data: Some(data),
            message: String::from("success"),
        }
    }

    pub fn error(_e: MijiError) {}
}
