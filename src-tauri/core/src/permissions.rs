pub mod error;
pub mod role;

pub use error::PermissionError;
pub use role::{Role, create_default_roles};

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum Permission {
    ReadUsers,
    CreateUsers,
    UpdateUsers,
    DeleteUsers,
    ReadPosts,
    CreatePosts,
    UpdatePosts,
    DeletePosts,
    AdminPanelAccess,
}
