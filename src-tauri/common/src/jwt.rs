// -----------------------------------------------------------------------------
//    Copyright (C) 2025 mcge. All rights reserved.
// Author:         mcge
// Email:          <mcgeq@outlook.com>
// File:           jwt.rs
// Description:    About jsonwebtoken
// Create   Date:  2025-05-26 19:53:47
// Last Modified:  2025-08-06 21:47:39
// Modified   By:  mcgeq <mcgeq@outlook.com>
// -----------------------------------------------------------------------------

use chrono::{Duration, Utc};
use jsonwebtoken::{DecodingKey, EncodingKey, Header, TokenData, Validation, decode, encode};
use serde::{Deserialize, Serialize};

use crate::{
    BusinessCode,
    error::{AppError, MijiResult},
};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Claims {
    pub sub: String,
    pub exp: usize,
    pub role: String,
}

pub struct JwtHelper {
    secret: String,
}

impl JwtHelper {
    pub fn new(secret: String) -> Self {
        Self { secret }
    }

    pub fn generate_token(
        &self,
        user_id: &str,
        role: &str,
        expirted_at: i64,
    ) -> MijiResult<String> {
        let exp = Utc::now()
            .checked_add_signed(Duration::hours(expirted_at))
            .expect("valid timestamp")
            .timestamp() as usize;
        let claims = Claims {
            sub: user_id.to_owned(),
            exp,
            role: role.to_owned(),
        };
        let token = encode(
            &Header::default(),
            &claims,
            &EncodingKey::from_secret(self.secret.as_bytes()),
        )
        .map_err(|e| {
            AppError::simple(
                BusinessCode::TokenGenerationFailed,
                format!("Failed to generate token: {}", e),
            )
        })?;
        Ok(token)
    }

    pub fn verify_token(&self, token: &str) -> MijiResult<Claims> {
        let token_data: TokenData<Claims> = decode::<Claims>(
            token,
            &DecodingKey::from_secret(self.secret.as_bytes()),
            &Validation::default(),
        )
        .map_err(|e| match e.kind() {
            jsonwebtoken::errors::ErrorKind::ExpiredSignature => {
                AppError::simple(BusinessCode::TokenExpired, "Token has expired")
            }
            _ => AppError::simple(BusinessCode::TokenInvalid, format!("Invalid token: {e}")),
        })?;
        Ok(token_data.claims)
    }

    pub fn is_token_valid(&self, token: &str) -> MijiResult<bool> {
        decode::<Claims>(
            token,
            &DecodingKey::from_secret(self.secret.as_bytes()),
            &Validation::default(),
        )
        .map_err(|e| match e.kind() {
            jsonwebtoken::errors::ErrorKind::ExpiredSignature => {
                AppError::simple(BusinessCode::TokenExpired, "Token has expired")
            }
            _ => AppError::simple(BusinessCode::TokenInvalid, format!("Invalid token: {}", e)),
        })?;
        Ok(true)
    }
}
