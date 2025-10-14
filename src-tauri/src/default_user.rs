use common::{argon2id::helper::Argon2Helper, error::AppError, business_code::BusinessCode};
use sea_orm::{DatabaseConnection, EntityTrait, QueryFilter, ColumnTrait, ActiveModelBehavior, Set};
use entity::prelude::*;
use entity::users;
use entity::family_member;

const DEFAULT_USER_EMAIL: &str = "miji@miji.com";
const DEFAULT_USER_NAME: &str = "miji";
const DEFAULT_USER_PASSWORD: &str = "miji@4321QW";

/// 检查默认用户是否已存在
pub async fn check_default_user_exists(db: &DatabaseConnection) -> Result<bool, AppError> {
    let user = Users::find()
        .filter(users::Column::Email.eq(DEFAULT_USER_EMAIL))
        .one(db)
        .await
        .map_err(|e| {
            AppError::simple(
                BusinessCode::DatabaseError,
                format!("Failed to check default user: {e}"),
            )
        })?;
    
    Ok(user.is_some())
}

/// 创建默认用户
pub async fn create_default_user(db: &DatabaseConnection) -> Result<(), AppError> {
    // 检查用户是否已存在
    if check_default_user_exists(db).await? {
        println!("Default user already exists, skipping creation");
        return Ok(());
    }

    println!("Creating default user...");

    // 生成密码哈希
    let argon = Argon2Helper::new()?;
    let password_hash = argon.create_hashed_password(DEFAULT_USER_PASSWORD)?;
    let password_json = serde_json::to_string(&password_hash).map_err(|e| {
        AppError::simple(
            BusinessCode::SerializationError,
            format!("Failed to serialize password hash: {e}"),
        )
    })?;

    // 生成用户序列号
    let user_serial_num = format!("user-{}", chrono::Utc::now().timestamp_millis());
    
    // 创建用户实体
    let mut user = users::ActiveModel::new();
    user.serial_num = Set(user_serial_num.clone());
    user.name = Set(DEFAULT_USER_NAME.to_string());
    user.email = Set(DEFAULT_USER_EMAIL.to_string());
    user.password = Set(password_json);
    user.phone = Set(None);
    user.avatar_url = Set(None);
    user.last_login_at = Set(None);
    user.is_verified = Set(true);
    user.role = Set("User".to_string());
    user.status = Set("Active".to_string());
    user.email_verified_at = Set(Some(chrono::Utc::now().into()));
    user.phone_verified_at = Set(None);
    user.bio = Set(None);
    user.language = Set(Some("zh".to_string()));
    user.timezone = Set(Some("Asia/Shanghai".to_string()));
    user.last_active_at = Set(None);
    user.deleted_at = Set(None);
    user.created_at = Set(chrono::Utc::now().into());
    user.updated_at = Set(None);

    // 插入用户
    let _user_result = Users::insert(user).exec(db).await.map_err(|e| {
        AppError::simple(
            BusinessCode::DatabaseError,
            format!("Failed to create default user: {e}"),
        )
    })?;

    println!("Default user created successfully");

    // 创建对应的家庭成员
    create_default_family_member(db).await?;

    Ok(())
}

/// 创建默认家庭成员
async fn create_default_family_member(db: &DatabaseConnection) -> Result<(), AppError> {
    // 生成家庭成员序列号
    let member_serial_num = format!("member-{}", chrono::Utc::now().timestamp_millis());
    
    // 创建家庭成员实体
    let mut family_member = family_member::ActiveModel::new();
    family_member.serial_num = Set(member_serial_num);
    family_member.name = Set(DEFAULT_USER_NAME.to_string());
    family_member.role = Set("Member".to_string());
    family_member.is_primary = Set(true);
    family_member.permissions = Set("read,write,delete".to_string());
    family_member.created_at = Set(chrono::Utc::now().into());
    family_member.updated_at = Set(None);

    // 插入家庭成员
    FamilyMember::insert(family_member).exec(db).await.map_err(|e| {
        AppError::simple(
            BusinessCode::DatabaseError,
            format!("Failed to create default family member: {e}"),
        )
    })?;

    println!("Default family member created successfully");
    Ok(())
}
