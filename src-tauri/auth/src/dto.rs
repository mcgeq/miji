use chrono::NaiveDateTime;
use common::entity::{
    sea_orm_active_enums::{UserRole, UserStatus},
    user,
};
use serde::{Deserialize, Serialize};
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

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LoginResponseDto {
    pub user: UserDto,
}

#[derive(Debug, Deserialize)]
pub struct RegisterInput {
    pub name: String,
    pub email: String,
    pub phone: Option<String>,
    pub password: String,
}

#[derive(Debug, Deserialize)]
pub struct LoginInput {
    pub email: String,
    pub password: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct UserDto {
    pub serial_num: String,
    pub name: String,
    pub email: String,
    pub avatar_url: Option<String>,
    pub role: UserRole,
    pub status: UserStatus,
    pub is_verified: bool,
    pub language: Option<String>,
    pub timezone: Option<String>,
    pub token: String,
    pub created_at: NaiveDateTime,
    pub updated_at: Option<NaiveDateTime>,
}

impl From<user::Model> for UserDto {
    fn from(user: user::Model) -> Self {
        Self {
            serial_num: user.serial_num,
            name: user.name,
            email: user.email,
            avatar_url: user.avatar_url,
            role: user.role,
            status: user.status,
            is_verified: user.is_verified,
            language: user.language,
            timezone: user.timezone,
            token: "".to_string(),
            created_at: user.created_at.with_timezone(&chrono::Local).naive_local(),
            updated_at: user
                .updated_at
                .map(|dt| dt.with_timezone(&chrono::Local).naive_local()),
        }
    }
}

impl From<LoginResponse> for LoginResponseDto {
    fn from(value: LoginResponse) -> Self {
        let mut user = UserDto::from(value.user);
        user.token = value.token;
        Self { user }
    }
}
