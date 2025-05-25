use std::error::Error;

use crate::{business_code::BusinessCode, error::MijiError};
use snafu::{Backtrace, Snafu};

#[derive(Debug, Snafu)]
pub enum SqlError {
    #[snafu(display("DataBase init failed: {message}"))]
    DataBaseError {
        code: BusinessCode,
        message: String,
        #[snafu(backtrace)]
        backtrace: Backtrace,
    },

    #[snafu(display("Database connection failed: {message}"))]
    DataBaseConnectionError {
        code: BusinessCode,
        message: String,
        #[snafu(source)]
        source: Box<dyn Error + Send + Sync>,
        #[snafu(backtrace)]
        backtrace: Backtrace,
    },

    #[snafu(display("Database query failed: {message}"))]
    DataBaseQueryError {
        code: BusinessCode,
        message: String,
        #[snafu(source)]
        source: Box<dyn Error + Send + Sync>,
        #[snafu(backtrace)]
        backtrace: Backtrace,
    },

    #[snafu(display("Database transaction failed: {message}"))]
    DataBaseTransactionError {
        code: BusinessCode,
        message: String,
        #[snafu(source)]
        source: Box<dyn Error + Send + Sync>,
        #[snafu(backtrace)]
        backtrace: Backtrace,
    },

    #[snafu(display("Database connection pool error: {message}"))]
    DataBasePoolError {
        code: BusinessCode,
        message: String,
        #[snafu(source)]
        source: Box<dyn Error + Send + Sync>,
        #[snafu(backtrace)]
        backtrace: Backtrace,
    },
}

impl From<SqlError> for MijiError {
    fn from(value: SqlError) -> Self {
        MijiError::Sql(Box::new(value))
    }
}
