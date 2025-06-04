use std::{any::Any, error::Error, fmt};

use serde::Serialize;

use crate::response::Res;

pub type MijiResult<T> = Result<T, MijiError>;

pub trait CodeMessage: std::error::Error + Any + 'static {
    fn code(&self) -> i32;
    fn message(&self) -> &str;
}

pub enum MijiError {
    Auth(Box<dyn CodeMessage + Send + Sync + 'static>),
    Argon2(Box<dyn CodeMessage + Send + Sync + 'static>),
    CheckLists(Box<dyn CodeMessage + Send + Sync + 'static>),
    Env(Box<dyn CodeMessage + Send + Sync + 'static>),
    Health(Box<dyn CodeMessage + Send + Sync + 'static>),
    Notes(Box<dyn CodeMessage + Send + Sync + 'static>),
    Profile(Box<dyn CodeMessage + Send + Sync + 'static>),
    Permissions(Box<dyn CodeMessage + Send + Sync + 'static>),
    Services(Box<dyn CodeMessage + Send + Sync + 'static>),
    Settings(Box<dyn CodeMessage + Send + Sync + 'static>),
    Sql(Box<dyn CodeMessage + Send + Sync + 'static>),
    Todos(Box<dyn CodeMessage + Send + Sync + 'static>),
    User(Box<dyn CodeMessage + Send + Sync + 'static>),
}

impl CodeMessage for MijiError {
    fn code(&self) -> i32 {
        match self {
            MijiError::Auth(e) => e.code(),
            MijiError::Argon2(e) => e.code(),
            MijiError::CheckLists(e) => e.code(),
            MijiError::Env(e) => e.code(),
            MijiError::Health(e) => e.code(),
            MijiError::Notes(e) => e.code(),
            MijiError::Profile(e) => e.code(),
            MijiError::Permissions(e) => e.code(),
            MijiError::Services(e) => e.code(),
            MijiError::Settings(e) => e.code(),
            MijiError::Sql(e) => e.code(),
            MijiError::Todos(e) => e.code(),
            MijiError::User(e) => e.code(),
        }
    }

    fn message(&self) -> &str {
        match self {
            MijiError::Auth(e) => e.message(),
            MijiError::Argon2(e) => e.message(),
            MijiError::CheckLists(e) => e.message(),
            MijiError::Env(e) => e.message(),
            MijiError::Health(e) => e.message(),
            MijiError::Notes(e) => e.message(),
            MijiError::Profile(e) => e.message(),
            MijiError::Permissions(e) => e.message(),
            MijiError::Services(e) => e.message(),
            MijiError::Settings(e) => e.message(),
            MijiError::Sql(e) => e.message(),
            MijiError::Todos(e) => e.message(),
            MijiError::User(e) => e.message(),
        }
    }
}

impl fmt::Display for MijiError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            MijiError::Auth(err) => write!(f, "{err}"),
            MijiError::Argon2(err) => write!(f, "{err}"),
            MijiError::CheckLists(err) => write!(f, "{err}"),
            MijiError::Env(err) => write!(f, "{err}"),
            MijiError::Health(err) => write!(f, "{err}"),
            MijiError::Notes(err) => write!(f, "{err}"),
            MijiError::Profile(err) => write!(f, "{err}"),
            MijiError::Permissions(err) => write!(f, "{err}"),
            MijiError::Services(err) => write!(f, "{err}"),
            MijiError::Settings(err) => write!(f, "{err}"),
            MijiError::Sql(err) => write!(f, "{err}"),
            MijiError::Todos(err) => write!(f, "{err}"),
            MijiError::User(err) => write!(f, "{err}"),
        }
    }
}

impl fmt::Debug for MijiError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            MijiError::Auth(err) => write!(f, "{err}"),
            MijiError::Argon2(err) => write!(f, "{err}"),
            MijiError::CheckLists(err) => write!(f, "{err}"),
            MijiError::Env(err) => write!(f, "{err}"),
            MijiError::Health(err) => write!(f, "{err}"),
            MijiError::Notes(err) => write!(f, "{err}"),
            MijiError::Profile(err) => write!(f, "{err}"),
            MijiError::Permissions(err) => write!(f, "{err}"),
            MijiError::Services(err) => write!(f, "{err}"),
            MijiError::Settings(err) => write!(f, "{err}"),
            MijiError::Sql(err) => write!(f, "{err}"),
            MijiError::Todos(err) => write!(f, "{err}"),
            MijiError::User(err) => write!(f, "{err}"),
        }
    }
}

impl Error for MijiError {
    fn source(&self) -> Option<&(dyn Error + 'static)> {
        match self {
            MijiError::Auth(err) => Some(err.as_ref()),
            MijiError::Argon2(err) => Some(err.as_ref()),
            MijiError::CheckLists(err) => Some(err.as_ref()),
            MijiError::Env(err) => Some(err.as_ref()),
            MijiError::Health(err) => Some(err.as_ref()),
            MijiError::Notes(err) => Some(err.as_ref()),
            MijiError::Profile(err) => Some(err.as_ref()),
            MijiError::Permissions(err) => Some(err.as_ref()),
            MijiError::Services(err) => Some(err.as_ref()),
            MijiError::Settings(err) => Some(err.as_ref()),
            MijiError::Sql(err) => Some(err.as_ref()),
            MijiError::Todos(err) => Some(err.as_ref()),
            MijiError::User(err) => Some(err.as_ref()),
        }
    }
}

#[derive(Debug, Serialize)]
#[serde(tag = "module", content = "message")]
pub enum MijiErrorDto {
    Auth(String),
    Argon2(String),
    CheckLists(String),
    Env(String),
    Health(String),
    Notes(String),
    Profile(String),
    Permissions(String),
    Services(String),
    Settings(String),
    Sql(String),
    Todos(String),
    User(String),
    Unknown(String), // 可选：处理兜底错误
}

impl From<&MijiError> for MijiErrorDto {
    fn from(err: &MijiError) -> Self {
        match err {
            MijiError::Auth(e) => MijiErrorDto::Auth(e.to_string()),
            MijiError::Argon2(e) => MijiErrorDto::Argon2(e.to_string()),
            MijiError::CheckLists(e) => MijiErrorDto::CheckLists(e.to_string()),
            MijiError::Env(e) => MijiErrorDto::Env(e.to_string()),
            MijiError::Health(e) => MijiErrorDto::Health(e.to_string()),
            MijiError::Notes(e) => MijiErrorDto::Notes(e.to_string()),
            MijiError::Profile(e) => MijiErrorDto::Profile(e.to_string()),
            MijiError::Permissions(e) => MijiErrorDto::Permissions(e.to_string()),
            MijiError::Services(e) => MijiErrorDto::Services(e.to_string()),
            MijiError::Settings(e) => MijiErrorDto::Settings(e.to_string()),
            MijiError::Sql(e) => MijiErrorDto::Sql(e.to_string()),
            MijiError::Todos(e) => MijiErrorDto::Todos(e.to_string()),
            MijiError::User(e) => MijiErrorDto::User(e.to_string()),
        }
    }
}

pub fn to_dto<E: Into<MijiError>>(err: E) -> MijiErrorDto {
    let err = err.into();
    MijiErrorDto::from(&err)
}

impl<T> From<Result<T, MijiError>> for Res<T> {
    fn from(value: Result<T, MijiError>) -> Self {
        match value {
            Ok(data) => Res::success(data),
            Err(err) => Res::error(err),
        }
    }
}
