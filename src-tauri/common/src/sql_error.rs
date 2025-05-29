// -----------------------------------------------------------------------------
//    Copyright (C) 2025 mcge. All rights reserved.
// Author:         mcge
// Email:          <mcgeq@outlook.com>
// File:           sql_error.rs
// Description:    About SQL Error
// Create   Date:  2025-05-26 20:36:27
// Last Modified:  2025-05-29 22:09:56
// Modified   By:  mcgeq <mcgeq@outlook.com>
// -----------------------------------------------------------------------------

use std::sync::Arc;

use miji_derive::CodeMessage;
use sea_orm::DbErr;
use snafu::Snafu;

use crate::{
    business_code::BusinessCode,
    error::{CodeMessage, MijiError},
};

#[derive(Debug, Snafu, CodeMessage)]
pub enum SQLError {
    #[snafu(display("Database error: {source}"))]
    SeaOrm {
        code: BusinessCode,
        message: String,
        source: DbErr,
    },

    #[snafu(display("Database connection error: {source}"))]
    Connection {
        code: BusinessCode,
        message: String,
        source: Arc<dyn std::error::Error + Send + Sync>,
    },

    #[snafu(display("Failed to begin transaction: {source}"))]
    BeginTransaction {
        code: BusinessCode,
        message: String,
        source: DbErr,
    },

    #[snafu(display("Failed to commit transaction: {source}"))]
    CommitTransaction {
        code: BusinessCode,
        message: String,
        source: DbErr,
    },

    #[snafu(display("Failed to rollback transaction: {source}"))]
    RollbackTransaction {
        code: BusinessCode,
        message: String,
        source: DbErr,
    },

    #[snafu(display("Record not found"))]
    NotFound { code: BusinessCode, message: String },

    #[snafu(display("Unique constraint violated: {details}"))]
    UniqueViolation {
        code: BusinessCode,
        message: String,
        details: String,
    },

    #[snafu(display("Foreign key constraint violated: {details}"))]
    ForeignKeyViolation {
        code: BusinessCode,
        message: String,
        details: String,
    },

    #[snafu(display("Missing required field: {field}"))]
    MissingField {
        code: BusinessCode,
        message: String,
        field: &'static str,
    },

    #[snafu(display("Unexpected null in non-nullable column: {column}"))]
    UnexpectedNull {
        code: BusinessCode,
        message: String,
        column: &'static str,
    },
}

impl From<DbErr> for SQLError {
    fn from(source: DbErr) -> Self {
        SQLError::SeaOrm {
            code: BusinessCode::DatabaseQueryFailure,
            message: "".to_string(),
            source,
        }
    }
}

impl From<SQLError> for MijiError {
    fn from(err: SQLError) -> Self {
        MijiError::Sql(Box::new(err))
    }
}
