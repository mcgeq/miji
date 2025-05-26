use std::error::Error;

use crate::{business_code::BusinessCode, error::MijiError};
use snafu::{Backtrace, Snafu};

#[derive(Debug, Snafu)]
pub enum DataBaseError {
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

impl From<DataBaseError> for MijiError {
    fn from(value: DataBaseError) -> Self {
        MijiError::Sql(Box::new(value))
    }
}
