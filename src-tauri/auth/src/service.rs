// -----------------------------------------------------------------------------
//    Copyright (C) 2025 mcge. All rights reserved.
// Author:         mcge
// Email:          <mcgeq@outlook.com>
// File:           service.rs
// Description:    About Auth service
// Create   Date:  2025-05-26 20:01:16
// Last Modified:  2025-05-27 22:19:35
// Modified   By:  mcgeq <mcgeq@outlook.com>
// -----------------------------------------------------------------------------

use chrono::{Local, Offset};
use common::{
    argon2id::{helper::Argon2Helper, store_hash::StoredHash},
    entity::{
        sea_orm_active_enums::{UserRole, UserStatus},
        user::{self, Model as UserModel},
    },
    error::{MijiError, MijiResult},
    sql_error::SQLError,
    utils::uuid::McgUuid,
};
use sea_orm::{ActiveModelTrait, ColumnTrait, DatabaseConnection, EntityTrait, QueryFilter, Set};
use serde_json::json;

use crate::{
    error::{AuthError, UserError},
    jwt::JwtHelper,
};

static JWT_SECRET: &str = "mcgeq";

pub struct AuthService;

impl AuthService {
    pub async fn register(
        db: &DatabaseConnection,
        name: &str,
        email: &str,
        password: &str,
        _code: &str,
    ) -> MijiResult<(UserModel, String)> {
        let helper = Argon2Helper::new()?;
        let hash = helper.create_hashed_password(password)?;
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
        let token = Self::user_token(&user.email, &user.role)?;
        Ok((user, token))
    }

    pub async fn login(
        db: &DatabaseConnection,
        email: &str,
        password: &str,
    ) -> MijiResult<(UserModel, String)> {
        let u = Self::user(db, email).await.unwrap();
        if u.status.eq(&UserStatus::Inactive) {
            Err(UserError::UserNotFound)?
        }
        let u = Self::check_password_hash(u, password)?;
        let token = Self::user_token(&u.email, &u.role)?;
        Ok((u, token))
    }

    pub async fn logout(db: &DatabaseConnection, email: &str, password: &str) -> MijiResult<bool> {
        let u = Self::user(db, email).await.unwrap();
        let u = Self::check_password_hash(u, password)?;
        let mut u: user::ActiveModel = u.into();
        u.status = Set(UserStatus::Inactive);
        u.update(db).await.map_err(|e| {
            let sql_error: SQLError = e.into();
            MijiError::from(sql_error)
        })?;
        Ok(true)
    }
    async fn user(db: &DatabaseConnection, email: &str) -> MijiResult<UserModel> {
        let u = user::Entity::find()
            .filter(user::Column::Email.eq(email))
            .one(db)
            .await
            .map_err(|e| {
                let sql_err: SQLError = e.into();
                MijiError::from(sql_err)
            })?
            .unwrap();
        Ok(u)
    }
    fn check_password_hash(user: UserModel, password: &str) -> MijiResult<UserModel> {
        let store: StoredHash = serde_json::from_value(json!(&user.password_hash)).unwrap();
        let helper = Argon2Helper::new()?;
        let verity_hash = helper.verify_hashed_password(password, &store)?;
        if !verity_hash {
            Err(AuthError::UserAndPasswordFailure)?
        }
        Ok(user)
    }

    fn user_token(user_id: &str, role: &UserRole) -> MijiResult<String> {
        let jwt = JwtHelper::new(JWT_SECRET.to_string());
        jwt.generate_token(user_id, &serde_json::to_string(role).unwrap())
    }
}
