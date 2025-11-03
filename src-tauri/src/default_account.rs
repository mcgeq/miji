use common::utils::{date::DateUtils, uuid::McgUuid};
use common::{business_code::BusinessCode, error::AppError};
use entity::account;
use sea_orm::prelude::Decimal;
use sea_orm::{
    ActiveModelBehavior, ColumnTrait, DatabaseConnection, EntityTrait, QueryFilter, Set,
};

/// 检查默认虚拟账户是否已存在
pub async fn check_default_virtual_account_exists(
    db: &DatabaseConnection,
) -> Result<bool, AppError> {
    let account = account::Entity::find()
        .filter(account::Column::Name.eq("收支内部户"))
        .filter(account::Column::IsVirtual.eq(true))
        .one(db)
        .await
        .map_err(|e| {
            AppError::simple(
                BusinessCode::DatabaseError,
                format!("Failed to check default virtual account: {e}"),
            )
        })?;

    Ok(account.is_some())
}

/// 创建默认虚拟账户
pub async fn create_default_virtual_account(db: &DatabaseConnection) -> Result<(), AppError> {
    // 检查虚拟账户是否已存在
    if check_default_virtual_account_exists(db).await? {
        println!("Default virtual account already exists, skipping creation");
        return Ok(());
    }

    println!("Creating default virtual account...");

    // 生成账户序列号
    let account_serial_num = McgUuid::uuid(38);

    // 获取当前时间
    let now = DateUtils::local_now();

    // 创建虚拟账户实体
    let mut virtual_account = account::ActiveModel::new();
    virtual_account.serial_num = Set(account_serial_num);
    virtual_account.name = Set("收支内部户".to_string());
    virtual_account.description = Set(Some("系统默认内部账户，用于收支记录".to_string()));
    virtual_account.r#type = Set("Other".to_string());
    virtual_account.balance = Set(Decimal::ZERO);
    virtual_account.initial_balance = Set(Decimal::ZERO);
    virtual_account.currency = Set("CNY".to_string());
    virtual_account.is_shared = Set(Some(false));
    virtual_account.owner_id = Set(None);
    virtual_account.color = Set(None);
    virtual_account.is_active = Set(true);
    virtual_account.is_virtual = Set(true);
    virtual_account.created_at = Set(now);
    virtual_account.updated_at = Set(Some(now));

    // 插入虚拟账户
    account::Entity::insert(virtual_account)
        .exec(db)
        .await
        .map_err(|e| {
            AppError::simple(
                BusinessCode::DatabaseError,
                format!("Failed to create default virtual account: {e}"),
            )
        })?;

    println!("Default virtual account created successfully");
    Ok(())
}
