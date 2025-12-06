use std::{env, num::ParseIntError};

use snafu::{Backtrace, GenerateImplicitData};

use crate::error::{EnvError, MijiResult};

pub fn env_get<T>(key: &str) -> MijiResult<T>
where
    T: std::str::FromStr<Err = ParseIntError>,
{
    if key.is_empty() {
        Err(EnvError::EnvVarEmptyKey {
            backtrace: Backtrace::generate(),
        })?
    }
    let value = match env::var(key) {
        Ok(v) => v,
        Err(env::VarError::NotPresent) => {
            return Err(EnvError::EnvVarNotPresent {
                var_name: key.to_string(),
                backtrace: Backtrace::generate(),
            })?;
        }
        Err(env::VarError::NotUnicode(_)) => Err(EnvError::EnvVarNotUnicode {
            var_name: key.to_string(),
            backtrace: Backtrace::generate(),
        })?,
    };
    match value.parse::<T>() {
        Ok(parsed) => Ok(parsed),
        Err(parse_error) => Err(EnvError::EnvVarParseError {
            var_name: key.to_string(),
            source: parse_error,
            backtrace: Backtrace::generate(),
        })?,
    }
}

pub fn env_get_string(key: &str) -> MijiResult<String> {
    // Validate the key
    if key.is_empty() {
        Err(EnvError::EnvVarEmptyKey {
            backtrace: Backtrace::generate(),
        })?
    }

    // Attempt to retrieve the environment variable
    env::var(key).map_err(|e| match e {
        env::VarError::NotPresent => EnvError::EnvVarNotPresent {
            var_name: key.to_string(),
            backtrace: Backtrace::generate(),
        }
        .into(),
        env::VarError::NotUnicode(_) => EnvError::EnvVarNotUnicode {
            var_name: key.to_string(),
            backtrace: Backtrace::generate(),
        }
        .into(),
    })
}
