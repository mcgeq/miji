use common::{error::AppError, utils::{date::DateUtils, uuid::McgUuid}};
use entity::{split_record_details, split_records};
use sea_orm::{
    ActiveModelTrait, ActiveValue::Set, ColumnTrait, DatabaseConnection, EntityTrait, QueryFilter,
    prelude::Decimal,
};

use crate::dto::transactions::{SplitConfigRequest, SplitConfigResponse, SplitMemberResponse};

/// 标准化分摊类型字符串（匹配数据库 CHECK 约束）
fn normalize_split_type(split_type: &str) -> String {
    match split_type.to_uppercase().as_str() {
        "EQUAL" => "Equal".to_string(),
        "PERCENTAGE" => "Percentage".to_string(),
        "FIXEDAMOUNT" | "FIXED_AMOUNT" => "FixedAmount".to_string(),
        "WEIGHTED" => "Weighted".to_string(),
        _ => split_type.to_string(), // 保持原样，让数据库约束捕获错误
    }
}

/// 创建分摊记录
pub async fn create_split_records(
    db: &DatabaseConnection,
    transaction_serial_num: String,
    family_ledger_serial_num: String,
    payer_member_serial_num: String,
    split_config: SplitConfigRequest,
    total_amount: Decimal,
    currency: String,
) -> Result<(), AppError> {
    // 创建主记录
    let split_record = split_records::ActiveModel {
        serial_num: Set(McgUuid::uuid(38)),
        transaction_serial_num: Set(transaction_serial_num.clone()),
        family_ledger_serial_num: Set(family_ledger_serial_num),
        split_rule_serial_num: Set(None),
        payer_member_serial_num: Set(payer_member_serial_num.clone()),
        owe_member_serial_num: Set(payer_member_serial_num), // 初始设为付款人
        total_amount: Set(total_amount),
        split_amount: Set(total_amount),
        split_percentage: Set(None),
        currency: Set(currency),
        status: Set("Pending".to_string()),
        split_type: Set(normalize_split_type(&split_config.split_type)),
        description: Set(None),
        notes: Set(None),
        confirmed_at: Set(None),
        paid_at: Set(None),
        due_date: Set(None),
        reminder_sent: Set(false),
        last_reminder_at: Set(None),
        created_at: Set(DateUtils::local_now()),
        updated_at: Set(None),
    };

    let split_record_model = split_record.insert(db).await?;

    // 创建详情记录
    for member in split_config.members {
        let detail = split_record_details::ActiveModel {
            serial_num: Set(McgUuid::uuid(38)),
            split_record_serial_num: Set(split_record_model.serial_num.clone()),
            member_serial_num: Set(member.member_serial_num),
            amount: Set(member.amount),
            percentage: Set(member.percentage),
            weight: Set(member.weight),
            is_paid: Set(false),
            paid_at: Set(None),
            created_at: Set(DateUtils::local_now()),
            updated_at: Set(None),
        };
        detail.insert(db).await?;
    }

    Ok(())
}

/// 查询交易的分摊配置
pub async fn get_split_config(
    db: &DatabaseConnection,
    transaction_serial_num: &str,
) -> Result<Option<SplitConfigResponse>, AppError> {
    // 查询分摊记录
    let split_records_list = split_records::Entity::find()
        .filter(split_records::Column::TransactionSerialNum.eq(transaction_serial_num))
        .all(db)
        .await?;

    if split_records_list.is_empty() {
        return Ok(None);
    }

    // 假设一个交易只有一个分摊记录
    let split_record = &split_records_list[0];

    // 查询详情
    let details = split_record_details::Entity::find()
        .filter(split_record_details::Column::SplitRecordSerialNum.eq(&split_record.serial_num))
        .all(db)
        .await?;

    // 查询成员名称
    let member_serial_nums: Vec<String> = details.iter().map(|d| d.member_serial_num.clone()).collect();
    let members_map = entity::family_member::Entity::find()
        .filter(entity::family_member::Column::SerialNum.is_in(member_serial_nums))
        .all(db)
        .await?
        .into_iter()
        .map(|m| (m.serial_num.clone(), m.name.clone()))
        .collect::<std::collections::HashMap<_, _>>();

    let members = details
        .into_iter()
        .map(|d| SplitMemberResponse {
            member_serial_num: d.member_serial_num.clone(),
            member_name: members_map
                .get(&d.member_serial_num)
                .cloned()
                .unwrap_or_else(|| "Unknown".to_string()),
            amount: d.amount,
            percentage: d.percentage,
            weight: d.weight,
            is_paid: d.is_paid,
            paid_at: d.paid_at.map(|dt| dt.into()),
        })
        .collect();

    Ok(Some(SplitConfigResponse {
        enabled: true,
        split_type: split_record.split_type.clone(),
        members,
    }))
}

/// 删除交易的分摊记录
pub async fn delete_split_records(
    db: &DatabaseConnection,
    transaction_serial_num: &str,
) -> Result<(), AppError> {
    // 查询分摊记录
    let split_records_list = split_records::Entity::find()
        .filter(split_records::Column::TransactionSerialNum.eq(transaction_serial_num))
        .all(db)
        .await?;

    for record in split_records_list {
        // 删除详情（级联删除会自动处理，但为了明确性可以手动删除）
        split_record_details::Entity::delete_many()
            .filter(split_record_details::Column::SplitRecordSerialNum.eq(&record.serial_num))
            .exec(db)
            .await?;

        // 删除主记录
        split_records::Entity::delete_by_id(record.serial_num)
            .exec(db)
            .await?;
    }

    Ok(())
}

/// 更新分摊记录
pub async fn update_split_records(
    db: &DatabaseConnection,
    transaction_serial_num: String,
    family_ledger_serial_num: String,
    payer_member_serial_num: String,
    split_config: SplitConfigRequest,
    total_amount: Decimal,
    currency: String,
) -> Result<(), AppError> {
    // 删除旧记录
    delete_split_records(db, &transaction_serial_num).await?;

    // 创建新记录
    create_split_records(
        db,
        transaction_serial_num,
        family_ledger_serial_num,
        payer_member_serial_num,
        split_config,
        total_amount,
        currency,
    )
    .await
}
