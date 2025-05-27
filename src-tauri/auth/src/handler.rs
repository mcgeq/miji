use common::error::MijiResult;
use sea_orm::DatabaseConnection;

use crate::{
    dto::{LoginPayload, LoginResponse, RegisterPayload},
    service::AuthService,
};

pub async fn register_handler(
    db: &DatabaseConnection,
    payload: RegisterPayload,
) -> MijiResult<LoginResponse> {
    let (user, token) = AuthService::register(
        db,
        &payload.name,
        &payload.email,
        &payload.password,
        &payload.code,
    )
    .await?;
    Ok(LoginResponse { token, user })
}

pub async fn login_handler(
    db: &DatabaseConnection,
    payload: LoginPayload,
) -> MijiResult<LoginResponse> {
    let (user, token) = AuthService::login(db, &payload.email, &payload.password).await?;
    Ok(LoginResponse { token, user })
}

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
