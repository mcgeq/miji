#![allow(dead_code)]
use std::collections::{HashMap, HashSet};

use super::Permission;

#[derive(Debug, Clone)]
pub struct Role {
    pub name: String,
    pub permissions: HashSet<Permission>,
}

impl Role {
    pub fn new(name: impl Into<String>) -> Self {
        Self {
            name: name.into(),
            permissions: HashSet::new(),
        }
    }

    pub fn add_permission(&mut self, permission: Permission) {
        self.permissions.insert(permission);
    }

    pub fn has_permission(&self, permission: Permission) -> bool {
        self.permissions.contains(&permission)
    }
}

pub fn create_default_roles() -> HashMap<String, Role> {
    let mut roles = HashMap::new();

    let mut guest = Role::new("guest");
    guest.add_permission(Permission::ReadUsers);
    guest.add_permission(Permission::ReadPosts);
    roles.insert("guest".to_string(), guest);

    let mut user = Role::new("user");
    user.add_permission(Permission::ReadUsers);
    user.add_permission(Permission::ReadPosts);
    user.add_permission(Permission::CreatePosts);
    user.add_permission(Permission::UpdatePosts);
    roles.insert("user".to_string(), user);

    let mut admin = Role::new("admin");
    admin.add_permission(Permission::ReadUsers);
    admin.add_permission(Permission::CreateUsers);
    admin.add_permission(Permission::UpdateUsers);
    admin.add_permission(Permission::DeleteUsers);
    admin.add_permission(Permission::ReadPosts);
    admin.add_permission(Permission::CreatePosts);
    admin.add_permission(Permission::UpdatePosts);
    admin.add_permission(Permission::DeletePosts);
    admin.add_permission(Permission::AdminPanelAccess);
    roles.insert("admin".to_string(), admin);

    roles
}
