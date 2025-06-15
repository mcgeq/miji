// -----------------------------------------------------------------------------
//    Copyright (C) 2025 mcge. All rights reserved.
// Author:         mcge
// Email:          <mcgeq@outlook.com>
// File:           config.rs
// Description:    About Argon2 config
// Create   Date:  2025-05-26 11:06:49
// Last Modified:  2025-05-26 19:01:08
// Modified   By:  mcgeq <mcgeq@outlook.com>
// -----------------------------------------------------------------------------

use argon2::{Algorithm, Version};

#[derive(Debug, Clone)]
pub struct Argon2Config {
    pub algorithm: Algorithm,
    pub version: Version,
    // 迭代次数
    pub time_cost: u32,
    // 内存占用(kb)
    pub memory_cost: u32,
    // 并行度
    pub parallelism: u32,
    // 哈希长度
    pub hash_length: u32,
}

impl Default for Argon2Config {
    fn default() -> Self {
        Self {
            algorithm: Algorithm::default(),
            version: Version::default(),
            time_cost: 2,
            memory_cost: 65536, // 64Mb
            parallelism: 1,
            hash_length: 32,
        }
    }
}
