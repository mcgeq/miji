#![allow(dead_code)]
// -----------------------------------------------------------------------------
//    Copyright (C) 2025 mcge. All rights reserved.
// Author:         mcge
// Email:          <mcgeq@outlook.com>
// File:           db.rs
// Description:    About SQL
// Create   Date:  2025-05-25 17:13:04
// Last Modified:  2025-05-25 20:57:35
// Modified   By:  mcgeq <mcgeq@outlook.com>
// -----------------------------------------------------------------------------

use std::time::Duration;

use log::{error, info};
use sea_orm::{ConnectOptions, Database, DatabaseConnection};
use snafu::{Backtrace, GenerateImplicitData};
use tokio::time::sleep;

use crate::{
    business_code::BusinessCode,
    db_error::SqlError,
    env::{env_get, env_get_string},
    env_error::EnvError,
    error::MijiResult,
};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum DbType {
    Postgres,
    Mysql,
    Sqlite,
}

#[derive(Debug)]
pub struct DbConfig {
    url: String,
    db_type: DbType,
    max_connections: u32,
    min_connections: u32,
    connect_timeout: u64,
    acquire_timeout: u64,
    idle_timeout: u64,
    max_lifetime: u64,
    sqlx_logging: bool,
}

impl DbConfig {
    pub fn from_env() -> MijiResult<Self> {
        let url = env_get_string("DATABASE_URL")?;
        let db_type = if url.starts_with("postgres://") {
            DbType::Postgres
        } else if url.starts_with("mysql://") {
            DbType::Mysql
        } else if url.starts_with("sqlite://") || url.starts_with("file:") {
            DbType::Sqlite
        } else {
            return Err(EnvError::EnvVarNotPresent {
                code: BusinessCode::InvalidParameter,
                key: "DATABASE_URL".to_string(),
                backtrace: Backtrace::generate(),
            })?;
        };

        macro_rules! parse_env {
            ($key:literal, $default:expr) => {
                env_get($key).unwrap_or($default)
            };
        }

        Ok(DbConfig {
            url,
            db_type,
            max_connections: parse_env!("DB_MAX_CONNECTIONS", 10),
            min_connections: parse_env!("DB_MIN_CONNECTIONS", 2),
            connect_timeout: parse_env!("DB_CONNECT_TIMEOUT", 8),
            acquire_timeout: parse_env!("DB_ACQUIRE_TIMEOUT", 8),
            idle_timeout: parse_env!("DB_IDLE_TIMEOUT", 8),
            max_lifetime: parse_env!("DB_MAX_LIFETIME", 8),
            sqlx_logging: env_get_string("DB_SQLX_LOGGING")
                .ok()
                .and_then(|s| s.parse::<bool>().ok())
                .unwrap_or(true),
        })
    }
}

pub async fn get_db_conn() -> MijiResult<DatabaseConnection> {
    let config = DbConfig::from_env().inspect_err(|e| {
        error!("Failed to load database configuration: {e}",);
    })?;

    let mut opt = ConnectOptions::new(config.url);

    if config.db_type == DbType::Sqlite {
        // SQLite 通常不支持 max_connections 等设置，或者只支持单连接
        // SeaORM 允许调用，但是无效，或者你也可以跳过设置
        info!("Using SQLite database, skipping pool configurations");
    } else {
        opt.max_connections(config.max_connections)
            .min_connections(config.min_connections)
            .connect_timeout(Duration::from_secs(config.connect_timeout))
            .acquire_timeout(Duration::from_secs(config.acquire_timeout))
            .idle_timeout(Duration::from_secs(config.idle_timeout))
            .max_lifetime(Duration::from_secs(config.max_lifetime));
    }
    opt.sqlx_logging(config.sqlx_logging);

    let conn = connect_with_retry(opt, 3, 2).await?;
    // migration::Migrator::up(&conn, None)
    //     .await
    //     .map_err(|e| SqlError::DataBaseConnectionError {
    //         code: BusinessCode::DatabaseInitFailure,
    //         message: "Failed to apply migrations".to_string(),
    //         source: Box::new(e),
    //         backtrace: Backtrace::generate(),
    //     })?;
    info!("Database connection established and migrations applied");
    Ok(conn)
}

async fn connect_with_retry(
    opt: ConnectOptions,
    retries: u32,
    delay_secs: u64,
) -> MijiResult<DatabaseConnection> {
    let mut last_error = None;
    for attempt in 1..=retries {
        match Database::connect(opt.clone()).await {
            Ok(conn) => return Ok(conn),
            Err(e) => {
                last_error = Some(e);
                if attempt < retries {
                    sleep(Duration::from_secs(delay_secs)).await;
                }
            }
        }
    }
    Err(SqlError::DataBaseConnectionError {
        code: BusinessCode::DatabaseConnectionFailure,
        message: "Failed to connect to database after retries".to_string(),
        source: Box::new(last_error.unwrap()),
        backtrace: Backtrace::generate(),
    })?
}
