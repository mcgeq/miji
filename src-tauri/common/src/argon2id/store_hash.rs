// -----------------------------------------------------------------------------
//    Copyright (C) 2025 mcge. All rights reserved.
// Author:         mcge
// Email:          <mcgeq@outlook.com>
// File:           store_hash.rs
// Description:    About Argon Store Hash
// Create   Date:  2025-05-26 18:57:28
// Last Modified:  2025-05-26 18:57:49
// Modified   By:  mcgeq <mcgeq@outlook.com>
// -----------------------------------------------------------------------------

use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct StoredHash {
    pub salt_b64: String,
    pub hash_b64: String,
    pub output_len: usize,
}
