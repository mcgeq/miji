// -----------------------------------------------------------------------------
//    Copyright (C) 2025 mcge. All rights reserved.
// Author:         mcge
// Email:          <mcgeq@outlook.com>
// File:           config.rs
// Description:    About Argon2 config
// Create   Date:  2025-05-26 11:06:49
// Last Modified:  2025-05-26 16:58:39
// Modified   By:  mcgeq <mcgeq@outlook.com>
// -----------------------------------------------------------------------------

use argon2::{Algorithm, Version};

#[derive(Debug, Clone)]
pub struct Argon2Config {
    pub argon_id: Algorithm,
    pub argon_version: Version,
    // 迭代次数
    pub time_cost: u32,
    // 内存占用(kb)
    pub memory_cost: u32,
    // 并行度
    pub parallelism: u32,
    // 哈希长度
    pub hash_length: u32,
    pub outlen: usize,
}

impl Default for Argon2Config {
    fn default() -> Self {
        Self {
            argon_id: Algorithm::Argon2id,
            argon_version: Version::default(),
            time_cost: 2,
            memory_cost: 65536, // 64Mb
            parallelism: 1,
            hash_length: 32,
            outlen: 32,
        }
    }
}
