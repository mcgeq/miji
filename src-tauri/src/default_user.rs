use common::utils::uuid::McgUuid;
use common::{argon2id::helper::Argon2Helper, business_code::BusinessCode, error::AppError};
use entity::family_member;
use entity::prelude::*;
use entity::users;
use sea_orm::{
    ActiveModelBehavior, ColumnTrait, DatabaseConnection, EntityTrait, QueryFilter, Set,
};

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
    let user_serial_num = McgUuid::uuid(38);

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
    create_default_family_member(db, &user_serial_num).await?;

    Ok(())
}

/// 创建默认家庭成员
async fn create_default_family_member(
    db: &DatabaseConnection,
    serial_num: &str,
) -> Result<(), AppError> {
    // 创建家庭成员实体
    let mut family_member = family_member::ActiveModel::new();
    family_member.serial_num = Set(serial_num.to_string());
    family_member.name = Set(DEFAULT_USER_NAME.to_string());
    family_member.role = Set("Member".to_string());
    family_member.is_primary = Set(true);
    family_member.permissions = Set("read,write,delete".to_string());
    family_member.created_at = Set(chrono::Utc::now().into());
    family_member.updated_at = Set(None);

    // 插入家庭成员
    FamilyMember::insert(family_member)
        .exec(db)
        .await
        .map_err(|e| {
            AppError::simple(
                BusinessCode::DatabaseError,
                format!("Failed to create default family member: {e}"),
            )
        })?;

    println!("Default family member created successfully");
    Ok(())
}

/// 删除 miji 用户及其家庭成员
pub async fn delete_miji_user(db: &DatabaseConnection) -> Result<(), AppError> {
    println!("Deleting miji user and family member...");

    // 查找 miji 用户
    let user = Users::find()
        .filter(users::Column::Email.eq(DEFAULT_USER_EMAIL))
        .one(db)
        .await
        .map_err(|e| {
            AppError::simple(
                BusinessCode::DatabaseError,
                format!("Failed to find miji user: {e}"),
            )
        })?;

    if let Some(user_model) = user {
        // 删除对应的家庭成员
        delete_miji_family_member(db, &user_model.serial_num).await?;

        // 删除用户
        Users::delete_by_id(&user_model.serial_num)
            .exec(db)
            .await
            .map_err(|e| {
                AppError::simple(
                    BusinessCode::DatabaseError,
                    format!("Failed to delete miji user: {e}"),
                )
            })?;

        println!("Miji user and family member deleted successfully");
    } else {
        println!("Miji user not found, nothing to delete");
    }

    Ok(())
}

/// 删除 miji 家庭成员
async fn delete_miji_family_member(db: &DatabaseConnection, user_serial_num: &str) -> Result<(), AppError> {
    // 查找对应的家庭成员
    let family_member = FamilyMember::find()
        .filter(family_member::Column::SerialNum.eq(user_serial_num))
        .one(db)
        .await
        .map_err(|e| {
            AppError::simple(
                BusinessCode::DatabaseError,
                format!("Failed to find miji family member: {e}"),
            )
        })?;

    if let Some(family_member_model) = family_member {
        // 删除家庭成员
        FamilyMember::delete_by_id(&family_member_model.serial_num)
            .exec(db)
            .await
            .map_err(|e| {
                AppError::simple(
                    BusinessCode::DatabaseError,
                    format!("Failed to delete miji family member: {e}"),
                )
            })?;

        println!("Miji family member deleted successfully");
    } else {
        println!("Miji family member not found, nothing to delete");
    }

    Ok(())
}
