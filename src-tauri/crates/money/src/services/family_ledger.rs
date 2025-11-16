use common::{
    business_code::BusinessCode,
    crud::service::{CrudConverter, CrudService, GenericCrudService},
    error::{AppError, MijiResult},
    log::logger::NoopLogger,
    paginations::EmptyFilter,
    utils::{date::DateUtils, uuid::McgUuid},
};
use entity::{family_ledger, prelude::*};
use sea_orm::{ActiveModelTrait, ActiveValue, ColumnTrait, DatabaseConnection, EntityTrait, QueryFilter, Set};
use std::collections::HashSet;
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

        use entity::prelude::*;
        use sea_orm::prelude::Decimal;
        use std::collections::HashMap;

        // 获取该账本下的所有交易
        let family_ledger_transactions = FamilyLedgerTransaction::find()
            .filter(entity::family_ledger_transaction::Column::FamilyLedgerSerialNum.eq(&serial_num))
            .all(db)
            .await?;

        let transaction_ids: Vec<String> = family_ledger_transactions
            .iter()
            .map(|r| r.transaction_serial_num.clone())
            .collect();

        // 获取所有交易详情
        let transactions = if !transaction_ids.is_empty() {
            Transactions::find()
                .filter(entity::transactions::Column::SerialNum.is_in(transaction_ids))
                .all(db)
                .await?
        } else {
            vec![]
        };

        // 计算收入和支出
        let mut total_income = Decimal::ZERO;
        let mut total_expense = Decimal::ZERO;

        for transaction in &transactions {
            match transaction.transaction_type.as_str() {
                "Income" => total_income += transaction.amount,
                "Expense" => total_expense += transaction.amount,
                _ => {}
            }
        }

        // 获取成员数量
        let member_service = FamilyLedgerMemberService::default();
        let members = member_service.list_by_ledger(db, &serial_num).await?;
        let member_count = members.len();

        // 获取分摊记录用于计算共享支出和个人支出
        let split_records = entity::split_records::Entity::find()
            .filter(entity::split_records::Column::FamilyLedgerSerialNum.eq(&serial_num))
            .all(db)
            .await?;

        // 统计每笔交易的分摊人数
        let mut transaction_split_counts: HashMap<String, usize> = HashMap::new();
        for record in &split_records {
            *transaction_split_counts
                .entry(record.transaction_serial_num.clone())
                .or_insert(0) += 1;
        }

        // 计算共享支出和个人支出
        let mut shared_expense = Decimal::ZERO;
        let mut personal_expense = Decimal::ZERO;

        for transaction in &transactions {
            if transaction.transaction_type == "Expense" {
                let split_count = transaction_split_counts
                    .get(&transaction.serial_num)
                    .unwrap_or(&0);
                
                if *split_count > 1 {
                    shared_expense += transaction.amount;
                } else if *split_count == 1 {
                    personal_expense += transaction.amount;
                }
            }
        }

        // 计算待结算金额（所有未支付的分摊记录总额）
        let pending_settlement: Decimal = split_records
            .iter()
            .filter(|r| r.status == "Pending" || r.status == "Confirmed")
            .map(|r| r.split_amount)
            .sum();

        // 计算成员统计
        use crate::dto::family_ledger::MemberStats;
        let mut member_stats_map: HashMap<String, (String, Decimal, Decimal, HashSet<String>)> = HashMap::new();
        
        // 获取所有成员信息
        let family_member_service = FamilyMemberService::default();
        for member_relation in &members {
            let member = family_member_service.get_by_id(db, member_relation.family_member_serial_num.clone()).await?;
            member_stats_map.insert(
                member.serial_num.clone(),
                (member.name, Decimal::ZERO, Decimal::ZERO, HashSet::new())
            );
        }
        
        // 统计每个成员的支付和应分摊
        for record in &split_records {
            // 统计付款人的总支付
            if let Some((_, total_paid, _, transactions_set)) = member_stats_map.get_mut(&record.payer_member_serial_num) {
                *total_paid += record.split_amount;
                transactions_set.insert(record.transaction_serial_num.clone());
            }
            
            // 统计欠款人的总应分摊
            if let Some((_, _, total_owed, transactions_set)) = member_stats_map.get_mut(&record.owe_member_serial_num) {
                *total_owed += record.split_amount;
                transactions_set.insert(record.transaction_serial_num.clone());
            }
        }
        
        // 计算每个成员的待结算金额
        let mut member_pending_settlement: HashMap<String, Decimal> = HashMap::new();
        for record in &split_records {
            if record.status == "Pending" || record.status == "Confirmed" {
                *member_pending_settlement
                    .entry(record.owe_member_serial_num.clone())
                    .or_insert(Decimal::ZERO) += record.split_amount;
            }
        }
        
        // 统计每个成员的分摊记录数
        let mut member_split_counts: HashMap<String, i32> = HashMap::new();
        for record in &split_records {
            *member_split_counts
                .entry(record.owe_member_serial_num.clone())
                .or_insert(0) += 1;
        }
        
        // 构建成员统计数组
        let member_stats: Vec<MemberStats> = member_stats_map
            .into_iter()
            .map(|(member_serial_num, (member_name, total_paid, total_owed, transactions_set))| {
                let total_paid_f64 = total_paid.to_string().parse().unwrap_or(0.0);
                let total_owed_f64 = total_owed.to_string().parse().unwrap_or(0.0);
                let pending = member_pending_settlement
                    .get(&member_serial_num)
                    .unwrap_or(&Decimal::ZERO)
                    .to_string()
                    .parse()
                    .unwrap_or(0.0);
                let split_count = *member_split_counts.get(&member_serial_num).unwrap_or(&0);
                
                MemberStats {
                    member_serial_num,
                    member_name,
                    total_paid: total_paid_f64,
                    total_owed: total_owed_f64,
                    net_balance: total_paid_f64 - total_owed_f64,
                    pending_settlement: pending,
                    transaction_count: transactions_set.len() as i32,
                    split_count,
                }
            })
            .collect();

        let stats = FamilyLedgerStats {
            family_ledger_serial_num: serial_num,
            total_income: total_income.to_string().parse().unwrap_or(0.0),
            total_expense: total_expense.to_string().parse().unwrap_or(0.0),
            shared_expense: shared_expense.to_string().parse().unwrap_or(0.0),
            personal_expense: personal_expense.to_string().parse().unwrap_or(0.0),
            pending_settlement: pending_settlement.to_string().parse().unwrap_or(0.0),
            member_count: member_count as i32,
            active_transaction_count: transactions.len() as i32,
            member_stats,
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

        // 2.1 统计每个成员的交易数、总支付和应分摊金额
        // 现在只使用 split_records 表（已废弃 split_members JSON）
        use std::collections::{HashMap, HashSet};
        use sea_orm::prelude::Decimal;
        
        let mut member_transaction_counts: HashMap<String, i32> = HashMap::new();
        let mut member_total_paid: HashMap<String, Decimal> = HashMap::new();
        let mut member_total_owed: HashMap<String, Decimal> = HashMap::new();
        
        // 查询该账本下的所有分摊记录
        let split_records = entity::split_records::Entity::find()
            .filter(entity::split_records::Column::FamilyLedgerSerialNum.eq(&serial_num))
            .all(db)
            .await?;
        
        // 使用 split_records 表统计
        let mut member_transactions: HashMap<String, HashSet<String>> = HashMap::new();
        
        for record in split_records {
            // 付款人参与的交易
            member_transactions
                .entry(record.payer_member_serial_num.clone())
                .or_insert_with(HashSet::new)
                .insert(record.transaction_serial_num.clone());
            
            // 欠款人参与的交易
            member_transactions
                .entry(record.owe_member_serial_num.clone())
                .or_insert_with(HashSet::new)
                .insert(record.transaction_serial_num.clone());
            
            // 统计付款人的总支付金额（付款人为欠款人支付的金额）
            *member_total_paid
                .entry(record.payer_member_serial_num.clone())
                .or_insert(Decimal::ZERO) += record.split_amount;
            
            // 统计欠款人的应分摊金额（欠款人应该承担的金额）
            *member_total_owed
                .entry(record.owe_member_serial_num)
                .or_insert(Decimal::ZERO) += record.split_amount;
        }
        
        for (member_id, transactions) in member_transactions {
            member_transaction_counts.insert(member_id, transactions.len() as i32);
        }

        let family_member_service = FamilyMemberService::default();
        let mut member_list = Vec::new();
        for member_id in member_ids {
            let member = family_member_service.get_by_id(db, member_id.clone()).await?;
            let mut member_response = FamilyMemberResponse::from(member);
            // 设置交易数量统计
            member_response.transaction_count = *member_transaction_counts.get(&member_id).unwrap_or(&0);
            // 设置总支付金额
            member_response.total_paid = *member_total_paid.get(&member_id).unwrap_or(&Decimal::ZERO);
            // 设置应分摊金额
            member_response.total_owed = *member_total_owed.get(&member_id).unwrap_or(&Decimal::ZERO);
            // 计算净余额 (总支付 - 应分摊)
            member_response.balance = member_response.total_paid - member_response.total_owed;
            member_list.push(member_response);
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

        // 4. 查询 currency 详情
        use crate::dto::currency::CurrencyResponse;
        let base_currency_detail = if let Ok(Some(currency_model)) = Currency::find_by_id(&ledger.base_currency)
            .one(db)
            .await 
        {
            Some(CurrencyResponse::from(currency_model))
        } else {
            tracing::warn!("Currency {} not found", ledger.base_currency);
            None
        };

        // 5. 组装响应
        Ok(FamilyLedgerDetailResponse {
            serial_num: ledger.serial_num,
            name: ledger.name.unwrap_or_else(|| "未命名账本".to_string()),
            description: if ledger.description.is_empty() {
                None
            } else {
                Some(ledger.description)
            },
            base_currency: ledger.base_currency,
            base_currency_detail,
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

    /// 将 Model 转换为 Response，并填充 Currency 详情
    pub async fn model_to_response(
        &self,
        db: &DatabaseConnection,
        model: family_ledger::Model,
    ) -> MijiResult<crate::dto::family_ledger::FamilyLedgerResponse> {
        use crate::dto::{family_ledger::FamilyLedgerResponse, currency::CurrencyResponse};
        use entity::prelude::*;

        let mut response = FamilyLedgerResponse::from(model.clone());
        
        // 查询 currency 详情
        if let Ok(Some(currency_model)) = Currency::find_by_id(&model.base_currency)
            .one(db)
            .await 
        {
            response.base_currency_detail = Some(CurrencyResponse::from(currency_model));
            tracing::debug!("Found currency detail for {}", model.base_currency);
        } else {
            tracing::warn!("Currency {} not found in database", model.base_currency);
        }
        
        Ok(response)
    }
    
    /// 批量转换 Models 到 Responses，并填充 Currency 详情（优化版：批量查询）
    pub async fn models_to_responses(
        &self,
        db: &DatabaseConnection,
        models: Vec<family_ledger::Model>,
    ) -> MijiResult<Vec<crate::dto::family_ledger::FamilyLedgerResponse>> {
        use crate::dto::currency::CurrencyResponse;
        use entity::prelude::*;
        use std::collections::{HashSet, HashMap};

        // 收集所有不同的 currency code
        let currency_codes: HashSet<String> = models
            .iter()
            .map(|m| m.base_currency.clone())
            .collect();
        
        tracing::debug!("Fetching {} unique currencies", currency_codes.len());
        
        // 批量查询所有 currency（避免 N+1 查询）
        let currencies = Currency::find()
            .filter(entity::currency::Column::Code.is_in(currency_codes))
            .all(db)
            .await?;
        
        // 构建 code -> Currency 映射
        let currency_map: HashMap<String, CurrencyResponse> = currencies
            .into_iter()
            .map(|c| (c.code.clone(), CurrencyResponse::from(c)))
            .collect();
        
        tracing::debug!("Found {} currencies in database", currency_map.len());
        
        // 转换
        let mut responses = Vec::with_capacity(models.len());
        for model in models {
            let mut response = crate::dto::family_ledger::FamilyLedgerResponse::from(model.clone());
            response.base_currency_detail = currency_map.get(&model.base_currency).cloned();
            
            if response.base_currency_detail.is_none() {
                tracing::warn!("Currency {} not found", model.base_currency);
            }
            
            responses.push(response);
        }
        
        Ok(responses)
    }
}

impl std::fmt::Debug for FamilyLedgerService {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("FamilyLedgerService")
            .field("inner", &"<GenericCrudService>") // 不打印内部细节
            .finish()
    }
}
