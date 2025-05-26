// -----------------------------------------------------------------------------
//    Copyright (C) 2025 mcge. All rights reserved.
// Author:         mcge
// Email:          <mcgeq@outlook.com>
// File:           sql_error.rs
// Description:    About SQL Error
// Create   Date:  2025-05-26 20:36:27
// Last Modified:  2025-05-26 20:41:49
// Modified   By:  mcgeq <mcgeq@outlook.com>
// -----------------------------------------------------------------------------

use std::sync::Arc;

use sea_orm::DbErr;
use snafu::Snafu;

use crate::error::MijiError;

#[derive(Debug, Snafu)]
pub enum SQLError {
    #[snafu(display("Database error: {source}"))]
    SeaOrm { source: DbErr },

    #[snafu(display("Database connection error: {source}"))]
    Connection {
        source: Arc<dyn std::error::Error + Send + Sync>,
    },

    #[snafu(display("Failed to begin transaction: {source}"))]
    BeginTransaction { source: DbErr },

    #[snafu(display("Failed to commit transaction: {source}"))]
    CommitTransaction { source: DbErr },

    #[snafu(display("Failed to rollback transaction: {source}"))]
    RollbackTransaction { source: DbErr },

    #[snafu(display("Record not found"))]
    NotFound,

    #[snafu(display("Unique constraint violated: {details}"))]
    UniqueViolation { details: String },

    #[snafu(display("Foreign key constraint violated: {details}"))]
    ForeignKeyViolation { details: String },

    #[snafu(display("Missing required field: {field}"))]
    MissingField { field: &'static str },

    #[snafu(display("Unexpected null in non-nullable column: {column}"))]
    UnexpectedNull { column: &'static str },
}

impl From<DbErr> for SQLError {
    fn from(source: DbErr) -> Self {
        SQLError::SeaOrm { source }
    }
}

impl From<SQLError> for MijiError {
    fn from(err: SQLError) -> Self {
        MijiError::Sql(Box::new(err))
    }
}
