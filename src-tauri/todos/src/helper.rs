// -----------------------------------------------------------------------------
//    Copyright (C) 2025 mcge. All rights reserved.
// Author:         mcge
// Email:          <mcgeq@outlook.com>
// File:           helper.rs
// Description:    About Helper
// Create   Date:  2025-06-05 10:21:05
// Last Modified:  2025-06-05 13:05:28
// Modified   By:  mcgeq <mcgeq@outlook.com>
// -----------------------------------------------------------------------------
use chrono::{DateTime, FixedOffset};
use common::{business_code::BusinessCode, error::MijiResult, sql_error::SQLError};

use crate::dto::IntoResponse;

// Helper function to format DateTime to String (or use a standard like ISO 8601)
// fn format_datetime<Tz: TimeZone>(dt: DateTime<Tz>) -> String
// where
//     Tz::Offset: std::fmt::Display,
// {
//     dt.to_rfc3339() // Or any other desired format
// }
//
// fn format_opt_datetime<Tz: TimeZone>(opt_dt: Option<DateTime<Tz>>) -> Option<String>
// where
//     Tz::Offset: std::fmt::Display,
// {
//     // map applies the format_datetime function, inferring the Tz type
//     opt_dt.map(format_datetime)
// }

// Format NaiveDateTime assuming it represents a UTC time, output as RFC 3339
pub fn format_naive_datetime(ndt: DateTime<FixedOffset>) -> String {
    ndt.naive_local().to_string()
}

// Format Option<NaiveDateTime> assuming it represents a UTC time
pub fn format_opt_naive_datetime(opt_ndt: Option<DateTime<FixedOffset>>) -> Option<String> {
    // Map the naive formatter over the option
    opt_ndt.map(format_naive_datetime)
}

pub fn not_found_error(serial_num: &str) -> SQLError {
    SQLError::NotFound {
        code: BusinessCode::DatabaseQueryFailure,
        message: format!("Todo with {serial_num} not found"),
    }
}

pub async fn load_response<M, R>(models: Vec<M>) -> MijiResult<Vec<R>>
where
    M: IntoResponse<R>,
{
    if models.is_empty() {
        return Ok(Vec::new());
    }
    Ok(models.into_iter().map(|m| m.into_response()).collect())
}
