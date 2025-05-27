use common::error::{MijiError, MijiResult};
use sea_orm::DatabaseConnection;
use validator::Validate;

use crate::{
    dto::{LoginPayload, LoginResponse, RegisterPayload},
    error::AuthError,
    service::AuthService,
};

pub async fn register_handler(
    db: &DatabaseConnection,
    payload: RegisterPayload,
) -> MijiResult<LoginResponse> {
    if let Err(e) = payload.validate() {
        return Err(MijiError::Auth(Box::new(AuthError::Validation {
            details: e.to_string(),
        })));
    }
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
    if let Err(e) = payload.validate() {
        return Err(MijiError::Auth(Box::new(AuthError::Validation {
            details: e.to_string(),
        })));
    }

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
