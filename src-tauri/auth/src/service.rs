// -----------------------------------------------------------------------------
//    Copyright (C) 2025 mcge. All rights reserved.
// Author:         mcge
// Email:          <mcgeq@outlook.com>
// File:           service.rs
// Description:    About Auth service
// Create   Date:  2025-05-26 20:01:16
// Last Modified:  2025-05-26 23:11:01
// Modified   By:  mcgeq <mcgeq@outlook.com>
// -----------------------------------------------------------------------------

use chrono::{Local, Offset};
use common::{
    argon2id::helper::Argon2Helper,
    entity::user::{self, Model as UserModel},
    error::{MijiError, MijiResult},
    sql_error::SQLError,
    utils::uuid::McgUuid,
};
use log::info;
use sea_orm::{ActiveModelTrait, DatabaseConnection, Set};

pub struct AuthService;

impl AuthService {
    pub async fn register(
        db: &DatabaseConnection,
        name: &str,
        email: &str,
        password: &str,
        _code: &str,
    ) -> MijiResult<UserModel> {
        let helper = Argon2Helper::new()?;
        let hash = helper.create_hashed_password(password)?;
        let hs = serde_json::to_string(&hash).unwrap();
        info!("生成的hash: {hs}");
        let now = Local::now();
        let offset = now.offset().fix();
        let fixed_offset_time = now.with_timezone(&offset);
        let user = user::ActiveModel {
            serial_num: Set(McgUuid::uuid(32)),
            name: Set(name.to_string()),
            email: Set(email.to_string()),
            password_hash: Set(serde_json::to_string(&hash).unwrap()),
            is_verified: Set(false),
            role: Set(common::entity::sea_orm_active_enums::UserRole::User),
            status: Set(common::entity::sea_orm_active_enums::UserStatus::Active),
            created_at: Set(fixed_offset_time),
            ..Default::default()
        };
        let user = user.insert(db).await.map_err(|e| {
            let sql_error: SQLError = e.into();
            MijiError::from(sql_error)
        })?;
        Ok(user)
    }
}
