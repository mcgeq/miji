use common::{
    business_code::BusinessCode,
    crud::service::{CrudConverter, CrudService, GenericCrudService},
    error::{AppError, MijiResult},
    log::logger::NoopLogger,
    paginations::EmptyFilter,
    utils::{date::DateUtils, uuid::McgUuid},
};
use entity::{family_ledger, prelude::*};
use sea_orm::{ActiveModelTrait, ActiveValue, DatabaseConnection, EntityTrait, Set};
use std::fmt;
use tracing::{info, instrument};

use crate::{
    dto::{
        family_ledger::{FamilyLedgerCreate, FamilyLedgerDetailResponse, FamilyLedgerStats, FamilyLedgerUpdate},
        family_member::FamilyMemberResponse,
        account::AccountResponse,
    },
    services::{
        family_ledger_hooks::FamilyLedgerHooks,
        family_ledger_member::FamilyLedgerMemberService,
        family_ledger_account::FamilyLedgerAccountService,
        family_member::FamilyMemberService,
        account::AccountService,
    },
};

pub type FamilyLedgerFilter = EmptyFilter;

#[derive(Debug)]
pub struct FamilyLedgerConverter;

impl CrudConverter<entity::family_ledger::Entity, FamilyLedgerCreate, FamilyLedgerUpdate>
    for FamilyLedgerConverter
{
    fn create_to_active_model(
        &self,
        data: FamilyLedgerCreate,
    ) -> MijiResult<entity::family_ledger::ActiveModel> {
        entity::family_ledger::ActiveModel::try_from(data).map_err(AppError::from_validation_errors)
    }

    fn update_to_active_model(
        &self,
        model: entity::family_ledger::Model,
        data: FamilyLedgerUpdate,
    ) -> MijiResult<entity::family_ledger::ActiveModel> {
        entity::family_ledger::ActiveModel::try_from(data)
            .map(|mut active_model| {
                active_model.name = ActiveValue::Set(model.name.clone());
                active_model.created_at = ActiveValue::Set(model.created_at);
                active_model.updated_at = ActiveValue::Set(Some(DateUtils::local_now()));
                active_model
            })
            .map_err(AppError::from_validation_errors)
    }

    fn primary_key_to_string(&self, model: &entity::family_ledger::Model) -> String {
        model.serial_num.clone()
    }

    fn table_name(&self) -> &'static str {
        "family_ledger"
    }
}

pub struct FamilyLedgerService {
    inner: GenericCrudService<
        entity::family_ledger::Entity,
        FamilyLedgerFilter,
        FamilyLedgerCreate,
        FamilyLedgerUpdate,
        FamilyLedgerConverter,
        FamilyLedgerHooks,
    >,
}

impl std::ops::Deref for FamilyLedgerService {
    type Target = GenericCrudService<
        entity::family_ledger::Entity,
        FamilyLedgerFilter,
        FamilyLedgerCreate,
        FamilyLedgerUpdate,
        FamilyLedgerConverter,
        FamilyLedgerHooks,
    >;

    fn deref(&self) -> &Self::Target {
        &self.inner
    }
}

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

impl FamilyLedgerService {
    pub fn new(
        converter: FamilyLedgerConverter,
        hooks: FamilyLedgerHooks,
        logger: std::sync::Arc<dyn common::log::logger::OperationLogger>,
    ) -> Self {
        Self {
            inner: GenericCrudService::new(converter, hooks, logger),
        }
    }
}

impl Default for FamilyLedgerService {
    fn default() -> Self {
        Self::new(
            FamilyLedgerConverter,
            FamilyLedgerHooks,
            std::sync::Arc::new(NoopLogger),
        )
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
            members: Set(0),
            accounts: Set(0),
            transactions: Set(0),
            budgets: Set(0),
            audit_logs: Set("[]".to_string()),
            ledger_type: Set(normalize_ledger_type(
                &data.ledger_type.unwrap_or_else(|| "Family".to_string()),
            )),
            settlement_cycle: Set(normalize_settlement_cycle(
                &data
                    .settlement_cycle
                    .unwrap_or_else(|| "Monthly".to_string()),
            )),
            settlement_day: Set(data.settlement_day.unwrap_or(1)),
            auto_settlement: Set(data.auto_settlement.unwrap_or(false)),
            default_split_rule: Set(data
                .default_split_rule
                .map(|v| serde_json::from_value(v).unwrap_or_default())),
            last_settlement_at: Set(None),
            next_settlement_at: Set(None),
            status: Set(normalize_status("Active")),
            created_at: Set(now),
            updated_at: Set(None),
        };

        let result = active_model.insert(db).await?;

        info!(
            "Created family ledger with serial_num: {}",
            result.serial_num
        );
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
        if let Some(settlement_day) = data.settlement_day {
            active_model.settlement_day = Set(settlement_day);
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

        FamilyLedger::delete_by_id(ledger.serial_num)
            .exec(db)
            .await?;

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

        let _ledger = self
            .get_by_id(db, serial_num.clone())
            .await?
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

    /// 获取家庭账本详情（包含成员和账户列表）
    #[instrument(skip(db))]
    pub async fn get_detail(
        &self,
        db: &DatabaseConnection,
        serial_num: String,
    ) -> Result<FamilyLedgerDetailResponse, AppError> {
        info!("Getting family ledger detail: {}", serial_num);

        // 1. 获取账本基本信息
        let ledger = self
            .get_by_id(db, serial_num.clone())
            .await?
            .ok_or_else(|| AppError::simple(BusinessCode::NotFound, "Family ledger not found"))?;

        // 2. 获取成员列表
        let member_service = FamilyLedgerMemberService::default();
        let member_relations = member_service.list_by_ledger(db, &serial_num).await?;
        let member_ids: Vec<String> = member_relations
            .iter()
            .map(|r| r.family_member_serial_num.clone())
            .collect();

        let family_member_service = FamilyMemberService::default();
        let mut member_list = Vec::new();
        for member_id in member_ids {
            let member = family_member_service.get_by_id(db, member_id).await?;
            member_list.push(FamilyMemberResponse::from(member));
        }

        // 3. 获取账户列表
        let account_service = FamilyLedgerAccountService::default();
        let account_relations = account_service.list_by_ledger(db, &serial_num).await?;
        let account_ids: Vec<String> = account_relations
            .iter()
            .map(|r| r.account_serial_num.clone())
            .collect();

        let acc_service = AccountService::default();
        let mut account_list = Vec::new();
        for account_id in account_ids {
            let account = acc_service.get_by_id(db, account_id).await?;
            account_list.push(AccountResponse::from(account));
        }

        // 4. 组装响应
        Ok(FamilyLedgerDetailResponse {
            serial_num: ledger.serial_num,
            name: ledger.name.unwrap_or_else(|| "未命名账本".to_string()),
            description: if ledger.description.is_empty() {
                None
            } else {
                Some(ledger.description)
            },
            base_currency: ledger.base_currency,
            ledger_type: ledger.ledger_type,
            settlement_cycle: ledger.settlement_cycle,
            auto_settlement: ledger.auto_settlement,
            settlement_day: ledger.settlement_day,
            total_income: Some(0.0),
            total_expense: Some(0.0),
            shared_expense: Some(0.0),
            personal_expense: Some(0.0),
            pending_settlement: Some(0.0),
            members: Some(ledger.members),
            accounts: Some(ledger.accounts),
            transactions: Some(ledger.transactions),
            budgets: Some(ledger.budgets),
            member_list,
            account_list,
            last_settlement_at: ledger.last_settlement_at.map(|dt| dt.to_rfc3339()),
            created_at: ledger.created_at.to_rfc3339(),
            updated_at: ledger.updated_at.map(|dt| dt.to_rfc3339()),
        })
    }
}

impl std::fmt::Debug for FamilyLedgerService {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("FamilyLedgerService")
            .field("inner", &"<GenericCrudService>") // 不打印内部细节
            .finish()
    }
}
