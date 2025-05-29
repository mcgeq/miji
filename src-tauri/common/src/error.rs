use std::{any::Any, error::Error, fmt};

use serde::Serialize;

pub type MijiResult<T> = Result<T, MijiError>;

pub trait CodeMessage: std::error::Error + Any + 'static {
    fn code(&self) -> i32;
    fn message(&self) -> &str;
}

macro_rules! generate_code_message_impl {
    (message, $self:ident, $($variant:ident),*) => {{
        match $self {
            $(
                MijiError::$variant(e) => {
                    // 通过 Any 进行类型转换
                    if let Some(code_msg) = e.as_ref().downcast_ref::<dyn CodeMessage>() {
                        code_msg.message()
                    } else {
                        e.to_string().as_str()
                    }
                }
            )*
        }
    }};

    (code, $self:ident, $($variant:ident),*) => {{
        match $self {
            $(
                MijiError::$variant(e) => {
                    if let Some(code_msg) = e.as_ref().downcast_ref::<dyn CodeMessage>() {
                        code_msg.code()
                    } else {
                        0
                    }
                }
            )*
        }
    }};
}

impl CodeMessage for MijiError {
    fn code(&self) -> i32 {
        generate_code_message_impl!(
            code,
            self,
            Auth,
            Argon2,
            CheckLists,
            Env,
            Health,
            Notes,
            Profile,
            Permissions,
            Services,
            Settings,
            Sql,
            Todos,
            User
        )
    }

    fn message(&self) -> &str {
        generate_code_message_impl!(
            message,
            self,
            Auth,
            Argon2,
            CheckLists,
            Env,
            Health,
            Notes,
            Profile,
            Permissions,
            Services,
            Settings,
            Sql,
            Todos,
            User
        )
    }
}

pub enum MijiError {
    Auth(Box<dyn Error + Send + Sync + 'static>),
    Argon2(Box<dyn Error + Send + Sync + 'static>),
    CheckLists(Box<dyn Error + Send + Sync + 'static>),
    Env(Box<dyn Error + Send + Sync + 'static>),
    Health(Box<dyn Error + Send + Sync + 'static>),
    Notes(Box<dyn Error + Send + Sync + 'static>),
    Profile(Box<dyn Error + Send + Sync + 'static>),
    Permissions(Box<dyn Error + Send + Sync + 'static>),
    Services(Box<dyn Error + Send + Sync + 'static>),
    Settings(Box<dyn Error + Send + Sync + 'static>),
    Sql(Box<dyn Error + Send + Sync + 'static>),
    Todos(Box<dyn Error + Send + Sync + 'static>),
    User(Box<dyn Error + Send + Sync + 'static>),
}

impl CodeMessage for MijiError {
    fn code(&self) -> i32 {
        generate_code_message_impl!(
            code,
            self,
            Auth,
            Argon2,
            CheckLists,
            Env,
            Health,
            Notes,
            Profile,
            Permissions,
            Services,
            Settings,
            Sql,
            Todos,
            User
        )
    }

    fn message(&self) -> &str {
        generate_code_message_impl!(
            message,
            self,
            Auth,
            Argon2,
            CheckLists,
            Env,
            Health,
            Notes,
            Profile,
            Permissions,
            Services,
            Settings,
            Sql,
            Todos,
            User
        )
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
