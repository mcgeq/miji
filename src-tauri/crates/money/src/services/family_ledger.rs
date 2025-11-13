use entity::{family_ledger, prelude::*};
use sea_orm::{ActiveModelTrait, DatabaseConnection, EntityTrait, Set};
use tracing::{info, instrument};
use common::{business_code::BusinessCode, error::AppError, utils::{date::DateUtils, uuid::McgUuid}};

use crate::dto::family_ledger::{FamilyLedgerCreate, FamilyLedgerUpdate, FamilyLedgerStats};

/// 转换账本类型为数据库格式
fn normalize_ledger_type(ledger_type: &str) -> String {
    match ledger_type.to_uppercase().as_str() {
        "PERSONAL" => "Personal".to_string(),
        "FAMILY" => "Family".to_string(),
        "PROJECT" => "Project".to_string(),
        "BUSINESS" => "Business".to_string(),
        _ => "Family".to_string(), // 默认值
    }
}

/// 转换结算周期为数据库格式
fn normalize_settlement_cycle(cycle: &str) -> String {
    match cycle.to_uppercase().as_str() {
        "WEEKLY" => "Weekly".to_string(),
        "MONTHLY" => "Monthly".to_string(),
        "QUARTERLY" => "Quarterly".to_string(),
        "YEARLY" => "Yearly".to_string(),
        "MANUAL" => "Manual".to_string(),
        _ => "Monthly".to_string(), // 默认值
    }
}

/// 转换状态为数据库格式
fn normalize_status(status: &str) -> String {
    match status.to_uppercase().as_str() {
        "ACTIVE" => "Active".to_string(),
        "ARCHIVED" => "Archived".to_string(),
        "SUSPENDED" => "Suspended".to_string(),
        _ => "Active".to_string(), // 默认值
    }
}

#[derive(Debug)]
pub struct FamilyLedgerService;

impl Default for FamilyLedgerService {
    fn default() -> Self {
        Self
    }
}

impl FamilyLedgerService {
    /// 获取家庭账本列表
    #[instrument(skip(db))]
    pub async fn family_ledger_list(
        &self,
        db: &DatabaseConnection,
    ) -> Result<Vec<family_ledger::Model>, AppError> {
        info!("Getting family ledger list");
        
        let ledgers = FamilyLedger::find().all(db).await?;
        
        info!("Found {} family ledgers", ledgers.len());
        Ok(ledgers)
    }

    /// 根据ID获取家庭账本
    #[instrument(skip(db))]
    pub async fn get_by_id(
        &self,
        db: &DatabaseConnection,
        serial_num: String,
    ) -> Result<Option<family_ledger::Model>, AppError> {
        info!("Getting family ledger by id: {}", serial_num);
        
        let ledger = FamilyLedger::find_by_id(serial_num).one(db).await?;
        
        Ok(ledger)
    }

    /// 创建家庭账本
    #[instrument(skip(db))]
    pub async fn create(
        &self,
        db: &DatabaseConnection,
        data: FamilyLedgerCreate,
    ) -> Result<family_ledger::Model, AppError> {
        info!("Creating family ledger: {}", data.name);
        
        let serial_num = McgUuid::uuid(38);
        let now = DateUtils::local_now();
        
        let active_model = family_ledger::ActiveModel {
            serial_num: Set(serial_num),
            name: Set(Some(data.name)),
            description: Set(data.description.unwrap_or_default()),
            base_currency: Set(data.base_currency),
            members: Set(data.members.map(|v| v.to_string())),
            accounts: Set(data.accounts.map(|v| v.to_string())),
            transactions: Set(data.transactions.map(|v| v.to_string())),
            budgets: Set(data.budgets.map(|v| v.to_string())),
            audit_logs: Set("[]".to_string()),
            ledger_type: Set(normalize_ledger_type(&data.ledger_type.unwrap_or_else(|| "Family".to_string()))),
            settlement_cycle: Set(normalize_settlement_cycle(&data.settlement_cycle.unwrap_or_else(|| "Monthly".to_string()))),
            auto_settlement: Set(data.auto_settlement.unwrap_or(false)),
            default_split_rule: Set(data.default_split_rule.map(|v| serde_json::from_value(v).unwrap_or_default())),
            last_settlement_at: Set(None),
            next_settlement_at: Set(None),
            status: Set(normalize_status("Active")),
            created_at: Set(now),
            updated_at: Set(None),
        };

        let result = active_model.insert(db).await?;
        
        info!("Created family ledger with serial_num: {}", result.serial_num);
        Ok(result)
    }

    /// 更新家庭账本
    #[instrument(skip(db))]
    pub async fn update(
        &self,
        db: &DatabaseConnection,
        serial_num: String,
        data: FamilyLedgerUpdate,
    ) -> Result<family_ledger::Model, AppError> {
        info!("Updating family ledger: {}", serial_num);
        
        let ledger = FamilyLedger::find_by_id(&serial_num)
            .one(db)
            .await?
            .ok_or_else(|| AppError::simple(BusinessCode::NotFound, "Family ledger not found"))?;

        let now = DateUtils::local_now();
        
        let mut active_model: family_ledger::ActiveModel = ledger.into();
        
        if let Some(name) = data.name {
            active_model.name = Set(Some(name));
        }
        if let Some(description) = data.description {
            active_model.description = Set(description);
        }
        if let Some(base_currency) = data.base_currency {
            active_model.base_currency = Set(base_currency);
        }
        if let Some(ledger_type) = data.ledger_type {
            active_model.ledger_type = Set(normalize_ledger_type(&ledger_type));
        }
        if let Some(settlement_cycle) = data.settlement_cycle {
            active_model.settlement_cycle = Set(normalize_settlement_cycle(&settlement_cycle));
        }
        if let Some(auto_settlement) = data.auto_settlement {
            active_model.auto_settlement = Set(auto_settlement);
        }
        
        active_model.updated_at = Set(Some(now));

        let result = active_model.update(db).await?;
        
        info!("Updated family ledger: {}", result.serial_num);
        Ok(result)
    }

    /// 删除家庭账本
    #[instrument(skip(db))]
    pub async fn delete(
        &self,
        db: &DatabaseConnection,
        serial_num: String,
    ) -> Result<(), AppError> {
        info!("Deleting family ledger: {}", serial_num);
        
        let ledger = FamilyLedger::find_by_id(&serial_num)
            .one(db)
            .await?
            .ok_or_else(|| AppError::simple(BusinessCode::NotFound, "Family ledger not found"))?;

        FamilyLedger::delete_by_id(ledger.serial_num).exec(db).await?;
        
        info!("Deleted family ledger: {}", serial_num);
        Ok(())
    }

    /// 获取家庭账本统计信息
    #[instrument(skip(db))]
    pub async fn get_stats(
        &self,
        db: &DatabaseConnection,
        serial_num: String,
    ) -> Result<FamilyLedgerStats, AppError> {
        info!("Getting family ledger stats: {}", serial_num);
        
        let _ledger = self.get_by_id(db, serial_num.clone()).await?
            .ok_or_else(|| AppError::simple(BusinessCode::NotFound, "Family ledger not found"))?;
        
        // TODO: 实现更详细的统计逻辑，包括成员统计
        // 目前返回基础统计数据，因为实际的统计字段还没有在数据库中实现
        let stats = FamilyLedgerStats {
            family_ledger_serial_num: serial_num,
            total_income: 0.0,
            total_expense: 0.0,
            shared_expense: 0.0,
            personal_expense: 0.0,
            pending_settlement: 0.0,
            member_count: 0,
            active_transaction_count: 0,
            member_stats: vec![], // TODO: 实现成员统计
        };
        
        Ok(stats)
    }
}

/// 获取家庭账本服务实例
pub fn get_family_ledger_service() -> FamilyLedgerService {
    FamilyLedgerService::default()
}
