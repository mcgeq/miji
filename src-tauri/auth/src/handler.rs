use common::{entity::user, error::MijiResult};
use sea_orm::DatabaseConnection;
use serde::{Deserialize, Serialize};

use crate::service::AuthService;

#[derive(Debug, Deserialize)]
pub struct RegisterPayload {
    pub name: String,
    pub email: String,
    pub password: String,
    pub code: String,
}

#[derive(Debug, Deserialize)]
pub struct LoginPayload {
    pub email: String,
    pub password: String,
}

#[derive(Debug, Serialize)]
pub struct LoginResponse {
    pub token: String,
    pub user: user::Model,
}

pub async fn register_handler(
    db: &DatabaseConnection,
    payload: RegisterPayload,
) -> MijiResult<user::Model> {
    AuthService::register(
        db,
        &payload.name,
        &payload.email,
        &payload.password,
        &payload.code,
    )
    .await
}

// pub async fn login_handler(db: DbConn, payload: LoginPayload) -> MijiResult<LoginResponse> {
//     let (user, token) = AuthService::login(&db, &payload.email, &payload.password).await?;
//     Ok(LoginResponse { token, user })
// }
//
// pub async fn logout_handler(user: model::Model) -> MijiResult<()> {
//     AuthService::logout(&user)
// }
//
// pub async fn delete_account_handler(db: DbConn, user: model::Model) -> MijiResult<()> {
//     AuthService::delete_account(&db, user).await
// }
//
// /// 权限验证（可用于 beforeLoad）
// pub async fn ensure_admin(user: model::Model) -> MijiResult<()> {
//     AuthService::check_admin(&user)
// }
