// -----------------------------------------------------------------------------
//    Copyright (C) 2025 mcge. All rights reserved.
// Author:         mcge
// Email:          <mcgeq@outlook.com>
// File:           helper.rs
// Description:    About User
// Create   Date:  2025-05-25 22:46:37
// Last Modified:  2025-05-25 22:47:00
// Modified   By:  mcgeq <mcgeq@outlook.com>
// -----------------------------------------------------------------------------

use argon2::{self, Config};

// Helper function to hash a password using Argon2
fn hash_password(password: &str) -> String {
    let config = Config::default();
    let salt = Uuid::new_v4().to_string(); // Generate a random salt
    argon2::hash_encoded(password.as_bytes(), salt.as_bytes(), &config).unwrap()
}

// Helper function to verify a password against a stored hash
fn verify_password(stored_hash: &str, password: &str) -> bool {
    argon2::verify_encoded(stored_hash, password.as_bytes()).unwrap_or(false)
}
