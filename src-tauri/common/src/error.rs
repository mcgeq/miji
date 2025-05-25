use std::{error::Error, fmt};

pub type MijiResult<T> = Result<T, MijiError>;

pub enum MijiError {
    Auth(Box<dyn Error + Send + Sync + 'static>),
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

impl fmt::Display for MijiError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            MijiError::Auth(err) => write!(f, "{err}"),
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
