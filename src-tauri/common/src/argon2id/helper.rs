#![allow(dead_code)]
// -----------------------------------------------------------------------------
//    Copyright (C) 2025 mcge. All rights reserved.
// Author:         mcge
// Email:          <mcgeq@outlook.com>
// File:           helper.rs
// Description:    About Argon2 Utils with Argon2id
// Create   Date:  2025-05-26 11:11:16
// Last Modified:  2025-05-26 19:35:22
// Modified   By:  mcgeq <mcgeq@outlook.com>
// -----------------------------------------------------------------------------

use argon2::{
    Argon2, Params,
    password_hash::rand_core::{OsRng, RngCore},
};
use base64::{Engine, engine::general_purpose};

use crate::{business_code::BusinessCode, error::MijiResult};

use super::{config::Argon2Config, error::Argon2ErrorWrapper, store_hash::StoredHash};

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
            Some(config.hash_length as usize),
        )
        .map_err(|e| Argon2ErrorWrapper::Hash {
            code: BusinessCode::AuthenticationFailed,
            message: format!("Invalid params: {e}"),
        })?;
        let argon2 = Argon2::new(config.algorithm, config.version, params);
        Ok(Self { config, argon2 })
    }

    /// 自动生成随机 salt + hash 并封装为 StoredHash
    pub fn create_hashed_password(&self, password: &str) -> MijiResult<StoredHash> {
        let mut salt_bytes = vec![0u8; 16];
        OsRng.fill_bytes(&mut salt_bytes);

        let hash_bytes = self.hash_with_custom_salt_and_output(password, &salt_bytes)?;
        Ok(StoredHash {
            salt_b64: general_purpose::STANDARD.encode(&salt_bytes),
            hash_b64: general_purpose::STANDARD.encode(&hash_bytes),
            output_len: self.config.hash_length as usize,
        })
    }

    /// 验证用户密码是否匹配已存储的 hash
    pub fn verify_hashed_password(&self, password: &str, stored: &StoredHash) -> MijiResult<bool> {
        let salt = general_purpose::STANDARD
            .decode(&stored.salt_b64)
            .map_err(|e| Argon2ErrorWrapper::Hash {
                code: BusinessCode::AuthenticationFailed,
                message: format!("Salt decode error: {e}"),
            })?;
        let expected = general_purpose::STANDARD
            .decode(&stored.hash_b64)
            .map_err(|e| Argon2ErrorWrapper::Hash {
                code: BusinessCode::AuthenticationFailed,
                message: format!("Hash decode error: {e}"),
            })?;
        self.verify_custom_raw_hash(password, &salt, &expected)
    }

    /// 使用自定义 salt，返回原始 hash 字节
    pub fn hash_with_custom_salt_and_output(
        &self,
        password: &str,
        salt_bytes: &[u8],
    ) -> MijiResult<Vec<u8>> {
        let mut output = vec![0u8; self.config.hash_length as usize];
        self.argon2
            .hash_password_into(password.as_bytes(), salt_bytes, &mut output)
            .map_err(|e| Argon2ErrorWrapper::Hash {
                code: BusinessCode::AuthenticationFailed,
                message: format!("Raw hash error: {e}"),
            })?;
        Ok(output)
    }

    /// 验证自定义 salt + hash（非标准格式）
    pub fn verify_custom_raw_hash(
        &self,
        password: &str,
        salt_bytes: &[u8],
        expected_hash: &[u8],
    ) -> MijiResult<bool> {
        let mut actual = vec![0u8; expected_hash.len()];
        self.argon2
            .hash_password_into(password.as_bytes(), salt_bytes, &mut actual)
            .map_err(|e| Argon2ErrorWrapper::Hash {
                code: BusinessCode::AuthenticationFailed,
                message: format!("Verify raw error: {e}"),
            })?;
        Ok(actual == expected_hash)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_hash_and_verify_success() {
        let helper = Argon2Helper::new().unwrap();
        let password = "my_secret_password";

        let stored = helper.create_hashed_password(password).unwrap();
        let verified = helper.verify_hashed_password(password, &stored).unwrap();
        assert!(verified, "Password should be verified successfully");
    }

    #[test]
    fn test_verify_failure_with_wrong_password() {
        let helper = Argon2Helper::new().unwrap();
        let password = "correct_password";
        let wrong_password = "wrong_password";

        let stored = helper.create_hashed_password(password).unwrap();
        let verified = helper
            .verify_hashed_password(wrong_password, &stored)
            .unwrap();
        assert!(!verified, "Wrong password should not verify");
    }

    #[test]
    fn test_custom_hash_length_output() {
        let config = Argon2Config {
            hash_length: 64,
            ..Default::default()
        };

        let helper = Argon2Helper::with_config(config).unwrap();
        let stored = helper.create_hashed_password("some_password").unwrap();

        let decoded_hash = base64::engine::general_purpose::STANDARD
            .decode(&stored.hash_b64)
            .unwrap();
        assert_eq!(
            decoded_hash.len(),
            64,
            "Hash output length should match config"
        );
        assert_eq!(stored.output_len, 64);
    }

    #[test]
    fn test_verify_with_manual_raw_hash() {
        let helper = Argon2Helper::new().unwrap();
        let password = "manual_test";
        let salt = vec![1u8; 16]; // 固定 salt

        let hash = helper
            .hash_with_custom_salt_and_output(password, &salt)
            .unwrap();

        let valid = helper
            .verify_custom_raw_hash(password, &salt, &hash)
            .unwrap();
        assert!(valid, "Manual raw hash verification should pass");

        let invalid = helper
            .verify_custom_raw_hash("wrong", &salt, &hash)
            .unwrap();
        assert!(
            !invalid,
            "Manual raw hash verification should fail for wrong password"
        );
    }
}
