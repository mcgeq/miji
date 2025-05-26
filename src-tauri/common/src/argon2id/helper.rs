#![allow(dead_code)]
// -----------------------------------------------------------------------------
//    Copyright (C) 2025 mcge. All rights reserved.
// Author:         mcge
// Email:          <mcgeq@outlook.com>
// File:           helper.rs
// Description:    About Argon2 Utils with Argon2id
// Create   Date:  2025-05-26 11:11:16
// Last Modified:  2025-05-26 17:20:35
// Modified   By:  mcgeq <mcgeq@outlook.com>
// -----------------------------------------------------------------------------

use argon2::{Argon2, Params};

use crate::error::{MijiError, MijiResult};

use super::config::Argon2Config;

pub struct Argon2Helper<'a> {
    config: Argon2Config,
    argon2: Argon2<'a>,
}

impl<'a> Argon2Helper<'a> {
    pub fn new() -> MijiResult<Self> {
        Self::with_config(Argon2Config::default())
    }

    pub fn with_config(config: Argon2Config) -> MijiResult<Self> {
        let params: Params = Params::new(
            config.memory_cost,
            config.time_cost,
            config.parallelism,
            Some(config.outlen),
        )
        .unwrap();
        let argon2 = Argon2::new(config.argon_id, config.argon_version, params);
        Ok(Self { config, argon2 })
    }

    pub fn password_hash(&self, password: &str) -> MijiResult<()> {
        let mut output_key = [0u8; 32];
        if let Err(e) = self
            .argon2
            .hash_password_into(password, b"mcgeq", &mut output_key)
        {
            Err(MijiError::Argon2(Box::new("Argon2 failure")))
        };
        Ok(output_key.concat())
    }
}
