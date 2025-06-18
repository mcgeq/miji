// -----------------------------------------------------------------------------
//    Copyright (C) 2025 mcge. All rights reserved.
// Author:         mcge
// Email:          <mcgeq@outlook.com>
// File:           jwt.rs
// Description:    About jsonwebtoken
// Create   Date:  2025-05-26 19:53:47
// Last Modified:  2025-06-18 15:24:35
// Modified   By:  mcgeq <mcgeq@outlook.com>
// -----------------------------------------------------------------------------

use chrono::{Duration, Utc};
use jsonwebtoken::{DecodingKey, EncodingKey, Header, TokenData, Validation, decode, encode};
use serde::{Deserialize, Serialize};

use crate::{
    business_code::BusinessCode,
    error::{AuthError, MijiError, MijiResult},
};

#[derive(Debug, Serialize, Deserialize)]
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
        .map_err(|e| AuthError::TokenExpired {
            code: BusinessCode::AuthenticationFailed,
            message: e.to_string(),
        })?;
        Ok(token)
    }

    pub fn verify_token(&self, token: &str) -> MijiResult<Claims> {
        let token_data: TokenData<Claims> = decode::<Claims>(
            token,
            &DecodingKey::from_secret(self.secret.as_bytes()),
            &Validation::default(),
        )
        .map_err(|e| AuthError::TokenExpired {
            code: BusinessCode::AuthenticationFailed,
            message: e.to_string(),
        })?;
        Ok(token_data.claims)
    }

    pub fn is_token_valid(&self, token: &str) -> MijiResult<bool> {
        decode::<Claims>(
            token,
            &DecodingKey::from_secret(self.secret.as_bytes()),
            &Validation::default(),
        )
        .map_err(|e| {
            MijiError::from(AuthError::TokenExpired {
                code: BusinessCode::AuthenticationFailed,
                message: e.to_string(),
            })
        })?;
        Ok(true)
    }
}
