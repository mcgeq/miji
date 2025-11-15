use std::{str::FromStr, sync::Arc};

use chrono::Datelike;
use common::{
    BusinessCode,
    crud::service::{
        CrudConverter, CrudService, GenericCrudService, parse_enum_filed,
        update_entity_columns_simple,
    },
    error::{AppError, MijiResult},
    log::logger::NoopLogger,
    paginations::{Filter, PagedQuery, PagedResult},
    utils::date::DateUtils,
};
use entity::{localize::LocalizeModel, transactions::Column as TransactionColumn};
use once_cell::sync::Lazy;
use sea_orm::FromQueryResult;
use sea_orm::{
    ActiveModelTrait,
    ActiveValue::Set,
    ColumnTrait, Condition, DatabaseConnection, DatabaseTransaction, DbConn, EntityTrait,
    IntoActiveModel, QueryFilter, QueryOrder, QuerySelect, TransactionTrait,
    prelude::{Decimal, Expr},
    sea_query::{Alias, ExprTrait, Func, SimpleExpr},
};
use serde::{Deserialize, Serialize};
use snafu::GenerateImplicitData;
use tracing::{error, info};
use validator::Validate;

// 用于分类统计查询结果的结构体
#[derive(Debug, FromQueryResult)]
struct CategoryStatsRaw {
    category: String,
    amount: Decimal,
    count: i64,
}

use crate::{
    dto::{
        account::AccountType,
        transactions::{
            CategoryStats, CreateTransactionRequest, IncomeExpense, IncomeExpenseRaw,
            PaymentMethod, PaymentMethodStats, PaymentMethodStatsRaw, TimeTrendStats,
            TransactionStatsRequest, TransactionStatsResponse, TransactionStatsSummary,
            TransactionStatus, TransactionType, TransactionWithRelations, TransferRequest,
            UpdateTransactionRequest,
        },
    },
    error::MoneyError,
    services::{
        account::AccountService, currency::get_currency_service, transaction_hooks::NoOpHooks,
    },
};

#[derive(Debug, Clone)]
struct TransactionTypeConfig {
    field: &'static str,
    account_type: &'static str,
    #[allow(dead_code)]
    include_in_total: bool,
}

static TRANSACTION_TYPE_CONFIGS: Lazy<Vec<TransactionTypeConfig>> = Lazy::new(|| {
    vec![
        TransactionTypeConfig {
            field: "bank_savings",
            account_type: "Savings",
            include_in_total: true,
        },
        TransactionTypeConfig {
            field: "bank_savings",
            account_type: "Bank",
            include_in_total: true,
        },
        TransactionTypeConfig {
            field: "cash",
            account_type: "Cash",
            include_in_total: true,
        },
        TransactionTypeConfig {
            field: "credit_card",
            account_type: "CreditCard",
            include_in_total: true,
        },
        TransactionTypeConfig {
            field: "investment",
            account_type: "Investment",
            include_in_total: true,
        },
        TransactionTypeConfig {
            field: "alipay",
            account_type: "Alipay",
            include_in_total: true,
        },
        TransactionTypeConfig {
            field: "wechat",
            account_type: "WeChat",
            include_in_total: true,
        },
        TransactionTypeConfig {
            field: "cloud_quick_pass",
            account_type: "CloudQuickPass",
            include_in_total: true,
        },
        TransactionTypeConfig {
            field: "other",
            account_type: "Other",
            include_in_total: true,
        },
    ]
});

// 交易服务实现
pub struct TransactionService {
    inner: GenericCrudService<
        entity::transactions::Entity,
        TransactionFilter,
        CreateTransactionRequest,
        UpdateTransactionRequest,
        TransactionConverter,
        NoOpHooks,
    >,
}

impl Default for TransactionService {
    fn default() -> Self {
        Self::new(TransactionConverter, NoOpHooks, Arc::new(NoopLogger))
    }
}

impl TransactionService {
    pub fn new(
        converter: TransactionConverter,
        hooks: NoOpHooks,
        logger: Arc<dyn common::log::logger::OperationLogger>,
    ) -> Self {
        Self {
            inner: GenericCrudService::new(converter, hooks, logger),
        }
    }

    async fn fetch_account(
        &self,
        tx: &DatabaseTransaction,
        account_id: &str,
    ) -> MijiResult<entity::account::Model> {
        entity::account::Entity::find_by_id(account_id)
            .lock_exclusive()
            .one(tx)
            .await?
            .ok_or_else(|| AppError::simple(BusinessCode::NotFound, "Account not found"))
    }

    async fn update_account_balance(
        &self,
        tx: &DatabaseTransaction,
        account: &entity::account::Model,
        new_balance: Decimal,
        operation_type: &str,
    ) -> MijiResult<entity::account::Model> {
        let original_account = account.clone();
        let mut account_active = account.clone().into_active_model();
        account_active.serial_num = Set(account.serial_num.clone());
        account_active.balance = Set(new_balance);
        let updated_account = account_active.update(tx).await?;
        self.account_update_log(tx, &updated_account, &original_account, operation_type)
            .await?;
        Ok(updated_account)
    }

    pub async fn transfer(
        &self,
        db: &DatabaseConnection,
        data: TransferRequest,
    ) -> MijiResult<(entity::transactions::Model, entity::transactions::Model)> {
        data.validate().map_err(AppError::from_validation_errors)?;
        let tx = db.begin().await?;

        let from_account = self.fetch_account(&tx, &data.account_serial_num).await?;
        let to_account = self.fetch_account(&tx, &data.to_account_serial_num).await?;

        let amount = data.amount;
        if from_account.balance < amount {
            return Err(MoneyError::InsufficientFunds {
                balance: amount,
                backtrace: snafu::Backtrace::generate(),
            }
            .into());
        }

        self.apply_balances(&tx, &from_account, &to_account, amount)
            .await?;

        info!("from_account {:?}", from_account);
        info!("to_account {:?}", to_account);

        let (from_request, mut to_request) =
            self.build_transfer_requests(&data, &from_account, &to_account)?;

        info!("from_request {:?}", from_request);
        info!("to_request {:?}", to_request);

        let converter = TransactionConverter;
        let from_model = converter
            .create_to_active_model(from_request)?
            .insert(&tx)
            .await?;
        to_request.related_transaction_serial_num = Some(from_model.serial_num.clone());
        let to_model = converter
            .create_to_active_model(to_request)?
            .insert(&tx)
            .await?;

        info!("from_model {:?}", from_model);
        info!("to_model {:?}", to_model);

        self.log_transfer(&tx, &from_model, &to_model, None, None)
            .await?;

        tx.commit().await?;
        Ok((from_model, to_model))
    }

    pub async fn transfer_update(
        &self,
        db: &DatabaseConnection,
        transaction_id: &str,
        data: TransferRequest,
    ) -> MijiResult<(entity::transactions::Model, entity::transactions::Model)> {
        info!(
            "Starting transfer update for transaction_id: {}",
            transaction_id
        );

        // Step 1: Validate input data
        data.validate().map_err(|e| {
            error!("Validation failed for transfer update: {:?}", e);
            AppError::from_validation_errors(e)
        })?;
        if data.amount.is_sign_negative() {
            return Err(AppError::simple(
                BusinessCode::InvalidParameter,
                "Transfer amount must be non-negative",
            ));
        }

        let tx = db.begin().await?;

        // Step 2: Fetch original transfer pair Model
        let (original_outgoing, original_incoming) =
            self.fetch_related_transfer(&tx, transaction_id).await?;

        if original_incoming.category != "Transfer"
            || TransactionType::from_str(&original_incoming.transaction_type).map_err(|e| {
                AppError::simple(
                    BusinessCode::InvalidParameter,
                    format!("无效的交易类型: {e}"),
                )
            })? != TransactionType::Income
        {
            return Err(AppError::simple(
                BusinessCode::InvalidParameter,
                "Only Income Transfer transactions can be updated",
            ));
        }

        // Step 3: Validate refund amount
        let original_amount = original_outgoing.amount.abs();
        let refund_amount = data.amount;
        if refund_amount > original_amount {
            return Err(AppError::simple(
                BusinessCode::InvalidParameter,
                "Refund amount cannot exceed original transaction amount",
            ));
        }

        // Step 4: Re-fetch from_account for balance check
        let from_account = self.fetch_account(&tx, &data.account_serial_num).await?;
        if from_account.balance < refund_amount {
            return Err(MoneyError::InsufficientFunds {
                balance: refund_amount,
                backtrace: snafu::Backtrace::generate(),
            }
            .into());
        }
        let to_account = self.fetch_account(&tx, &data.to_account_serial_num).await?;

        // Step 5: Apply refund_amount to accounts
        self.apply_balances(&tx, &from_account, &to_account, refund_amount)
            .await?;

        // Step 6: Update original_incoming refund_amount and notes
        let update_at = DateUtils::local_now();
        let update_refund = |model: &entity::transactions::Model, prefix: &str| {
            let refund_amount_all = model.refund_amount + data.amount;
            entity::transactions::ActiveModel {
                serial_num: Set(model.serial_num.clone()),
                refund_amount: Set(refund_amount_all),
                notes: Set(Some(format!("{prefix} {refund_amount_all}"))),
                updated_at: Set(Some(update_at)),
                ..Default::default()
            }
        };

        let update_original_incoming = update_refund(&original_incoming, "退").update(&tx).await?;
        info!("Original_outgoing update {:?}", update_original_incoming);
        let update_original_outgoing = update_refund(&original_outgoing, "进").update(&tx).await?;
        info!("Original_outgoing update {:?}", update_original_outgoing);

        // Step 8: Build and update transaction requests
        let (mut from_request, mut to_request) =
            self.build_transfer_requests(&data, &from_account, &to_account)?;
        let set_completed = |req: &mut CreateTransactionRequest| {
            req.transaction_status = TransactionStatus::Completed;
        };
        set_completed(&mut from_request);
        set_completed(&mut to_request);

        from_request.related_transaction_serial_num = Some(original_incoming.serial_num.clone());
        to_request.related_transaction_serial_num = Some(original_outgoing.serial_num.clone());
        from_request.description = format!("退 {}", to_account.name.clone());
        to_request.description = format!("退 {}", from_account.name.clone());

        let to_active_model =
            |request: CreateTransactionRequest| -> MijiResult<entity::transactions::ActiveModel> {
                let mut model = entity::transactions::ActiveModel::try_from(request)?;
                model.related_transaction_serial_num =
                    Set(original_incoming.related_transaction_serial_num.clone());
                Ok(model)
            };

        let from_active_model = to_active_model(from_request)?;
        let to_active_model = to_active_model(to_request)?;

        let updated_outgoing = from_active_model.insert(&tx).await?;
        let updated_incoming = to_active_model.insert(&tx).await?;

        // Step 9: Log updates
        self.transaction_operation_log(
            &tx,
            &updated_outgoing,
            Some(self.serialize_model(&original_outgoing)?),
            "TRANSFER_UPDATE_OUT",
        )
        .await?;
        self.transaction_operation_log(
            &tx,
            &updated_incoming,
            Some(self.serialize_model(&original_incoming)?),
            "TRANSFER_UPDATE_IN",
        )
        .await?;

        // Step 10: Commit transaction
        tx.commit().await?;

        info!(
            "Transfer update completed successfully for transaction_id: {}",
            transaction_id
        );
        Ok((updated_outgoing, updated_incoming))
    }

    pub async fn transfer_delete(
        &self,
        db: &DatabaseConnection,
        transaction_id: &str,
    ) -> MijiResult<(entity::transactions::Model, entity::transactions::Model)> {
        let tx = db.begin().await?;
        info!("开始删除转账，交易ID: {}", transaction_id);

        let result = async {
            // 步骤1：获取转账交易对
            info!("获取交易ID为 {} 的转账对", transaction_id);
            let (original_outgoing, original_incoming) =
                self.fetch_related_transfer(&tx, transaction_id).await?;
            info!("获取到转出交易: {:?}", original_outgoing);
            info!("获取到转入交易: {:?}", original_incoming);

            // 步骤2：恢复账户余额
            let amount = original_outgoing.amount.abs();
            info!("恢复余额，金额: {}", amount);
            self.revert_balances(&tx, &original_outgoing, &original_incoming, amount)
                .await?;

            // 步骤3：标记原始交易为删除
            let updated_outgoing = self
                .mark_transaction_deleted(&tx, original_outgoing.clone())
                .await?;
            let updated_incoming = self
                .mark_transaction_deleted(&tx, original_incoming.clone())
                .await?;
            info!(
                "转出交易已标记删除: serial_num={}, is_deleted={}",
                updated_outgoing.serial_num, updated_outgoing.is_deleted
            );
            info!(
                "转入交易已标记删除: serial_num={}, is_deleted={}",
                updated_incoming.serial_num, updated_incoming.is_deleted
            );

            // 步骤4：创建并插入反向交易
            let (reverse_out_request, mut reverse_in_request) =
                self.build_reversal_requests(&original_outgoing, &original_incoming, amount);
            info!("反向转出请求: {:?}", reverse_out_request);
            info!("反向转入请求: {:?}", reverse_in_request);

            let converter = TransactionConverter;
            let reverse_out_model = converter
                .create_to_active_model(reverse_out_request)
                .map_err(|e| {
                    error!("转换反向转出请求失败: {:?}", e);
                    e
                })?
                .insert(&tx)
                .await
                .map_err(|e| {
                    error!("插入反向转出交易失败: {:?}", e);
                    e
                })?;
            info!(
                "插入反向转出交易: serial_num={}",
                reverse_out_model.serial_num
            );

            reverse_in_request.related_transaction_serial_num =
                Some(reverse_out_model.serial_num.clone());
            let reverse_in_model = converter
                .create_to_active_model(reverse_in_request)
                .map_err(|e| {
                    info!("转换反向转入请求失败: {:?}", e);
                    e
                })?
                .insert(&tx)
                .await
                .map_err(|e| {
                    info!("插入反向转入交易失败: {:?}", e);
                    e
                })?;
            info!(
                "插入反向转入交易: serial_num={}",
                reverse_in_model.serial_num
            );

            // 步骤5：记录日志
            let outgoing_snapshot = self.serialize_model(&original_outgoing)?;
            let incoming_snapshot = self.serialize_model(&original_incoming)?;
            self.log_transfer(
                &tx,
                &reverse_out_model,
                &reverse_in_model,
                Some(outgoing_snapshot.to_string()),
                Some(incoming_snapshot.to_string()),
            )
            .await?;

            Ok((reverse_out_model, reverse_in_model))
        }
        .await;

        match result {
            Ok(models) => {
                tx.commit().await?;
                Ok(models)
            }
            Err(e) => {
                error!("transfer_delete 错误: {:?}", e);
                tx.rollback().await?;
                Err(e)
            }
        }
    }

    // ----- Log
    async fn account_update_log(
        &self,
        tx: &DatabaseTransaction,
        updated_model: &entity::account::Model,
        original_model: &entity::account::Model,
        operation_type: &str,
    ) -> MijiResult<()> {
        let table_name = "accounts";
        let record_id = updated_model.serial_num.clone();
        let data_before = serde_json::to_value(original_model)
            .map_err(|e| AppError::internal_server_error(format!("Serialization failed: {e}")))?;
        let data_after = serde_json::to_value(updated_model)
            .map_err(|e| AppError::internal_server_error(format!("Serialization failed: {e}")))?;

        self.logger()
            .log_operation(
                operation_type,
                table_name,
                &record_id,
                Some(&data_before),
                Some(&data_after),
                Some(tx),
            )
            .await?;
        Ok(())
    }

    async fn transaction_operation_log(
        &self,
        tx: &DatabaseTransaction,
        model: &entity::transactions::Model,
        data_before: Option<serde_json::Value>,
        operation_type: &str,
    ) -> MijiResult<()> {
        let table_name = self.converter().table_name();
        let record_id = model.serial_num.clone();
        let data_after = self.serialize_model(model)?;

        self.logger()
            .log_operation(
                operation_type,
                table_name,
                &record_id,
                data_before.as_ref(),
                Some(&data_after),
                Some(tx),
            )
            .await?;
        Ok(())
    }

    // ================================
    // 辅助函数：统一日志
    // ================================
    async fn log_transfer(
        &self,
        tx: &DatabaseTransaction,
        out_model: &entity::transactions::Model,
        in_model: &entity::transactions::Model,
        out_snapshot: Option<String>,
        in_snapshot: Option<String>,
    ) -> MijiResult<()> {
        let out_before: Option<serde_json::Value> = match out_snapshot {
            Some(s) => Some(parse_json(&s, "out_snapshot")?),
            None => None,
        };

        let in_before: Option<serde_json::Value> = match in_snapshot {
            Some(s) => Some(parse_json(&s, "in_snapshot")?),
            None => None,
        };
        self.transaction_operation_log(tx, out_model, out_before, "TRANSFER_OUT")
            .await?;
        self.transaction_operation_log(tx, in_model, in_before, "TRANSFER_IN")
            .await?;
        Ok(())
    }

    // ================================
    // 辅助函数：余额更新
    // ================================
    async fn apply_balances(
        &self,
        tx: &DatabaseTransaction,
        from_account: &entity::account::Model,
        to_account: &entity::account::Model,
        amount: Decimal,
    ) -> MijiResult<()> {
        let _ = self
            .update_account_balance(
                tx,
                from_account,
                from_account.balance - amount,
                "BALANCE_UPDATE_FROM",
            )
            .await?;
        let _ = self
            .update_account_balance(
                tx,
                to_account,
                to_account.balance + amount,
                "BALANCE_UPDATE_TO",
            )
            .await?;
        Ok(())
    }

    async fn revert_balances(
        &self,
        tx: &DatabaseTransaction,
        outgoing: &entity::transactions::Model,
        incoming: &entity::transactions::Model,
        amount: Decimal,
    ) -> MijiResult<()> {
        let from_account = self.fetch_account(tx, &outgoing.account_serial_num).await?;
        let to_account = self.fetch_account(tx, &incoming.account_serial_num).await?;
        let _ = self
            .update_account_balance(
                tx,
                &from_account,
                from_account.balance + amount,
                "BALANCE_REVERSE_FROM",
            )
            .await?;
        let _ = self
            .update_account_balance(
                tx,
                &to_account,
                to_account.balance - amount,
                "BALANCE_REVERSE_TO",
            )
            .await?;
        Ok(())
    }

    // ================================
    // 辅助函数：标记交易删除
    // ================================
    async fn mark_transaction_deleted(
        &self,
        tx: &DatabaseTransaction,
        model: entity::transactions::Model,
    ) -> MijiResult<entity::transactions::Model> {
        let mut active = model.clone().into_active_model();
        active.serial_num = Set(model.serial_num.clone());
        active.is_deleted = Set(true);
        Ok(active.update(tx).await?)
    }

    // ================================
    // 构造正向转账请求
    // ================================
    fn build_transfer_requests(
        &self,
        data: &TransferRequest,
        from_account: &entity::account::Model,
        to_account: &entity::account::Model,
    ) -> MijiResult<(CreateTransactionRequest, CreateTransactionRequest)> {
        let date = data.date.unwrap_or(DateUtils::local_now());

        // 根据是否为空生成默认描述
        let from_description = if let Some(desc) = &data.description {
            if desc.trim().is_empty() {
                format!("转账至 {}", to_account.name)
            } else {
                desc.clone()
            }
        } else {
            format!("转账至 {}", to_account.name)
        };

        let to_description = if let Some(desc) = &data.description {
            if desc.trim().is_empty() {
                format!("转账来自 {}", from_account.name)
            } else {
                desc.clone()
            }
        } else {
            format!("转账来自 {}", from_account.name)
        };

        let from_request = CreateTransactionRequest {
            transaction_type: TransactionType::Expense,
            transaction_status: TransactionStatus::Completed,
            date,
            amount: data.amount,
            currency: data.currency.clone(),
            description: from_description,
            account_serial_num: from_account.serial_num.clone(),
            to_account_serial_num: Some(to_account.serial_num.clone()),
            category: "Transfer".to_string(),
            notes: data.description.clone(),
            sub_category: data.sub_category.clone(),
            tags: None,
            split_members: None,
            payment_method: data.payment_method.clone(),
            actual_payer_account: AccountType::from_str(&from_account.r#type).map_err(|e| {
                AppError::simple(
                    BusinessCode::InvalidParameter,
                    format!("无效的账户类型: {e}"),
                )
            })?,
            related_transaction_serial_num: None,
            // 分期相关字段
            is_installment: None,
            total_periods: None,
            remaining_periods: None,
            installment_amount: Some(Decimal::ZERO),
            remaining_periods_amount: Some(Decimal::ZERO),
            first_due_date: None,
            family_ledger_serial_nums: None,
        };

        let to_request = CreateTransactionRequest {
            transaction_type: TransactionType::Income,
            transaction_status: TransactionStatus::Completed,
            date,
            amount: data.amount,
            currency: data.currency.clone(),
            description: to_description,
            notes: data.description.clone(),
            account_serial_num: to_account.serial_num.clone(),
            to_account_serial_num: Some(from_account.serial_num.clone()),
            category: "Transfer".to_string(),
            sub_category: data.sub_category.clone(),
            tags: None,
            split_members: None,
            payment_method: data.payment_method.clone(),
            actual_payer_account: AccountType::from_str(&to_account.r#type).map_err(|e| {
                AppError::simple(
                    BusinessCode::InvalidParameter,
                    format!("无效的账户类型: {e}"),
                )
            })?,
            related_transaction_serial_num: None, // 插入后回填
            // 分期相关字段
            is_installment: None,
            total_periods: None,
            remaining_periods: None,
            installment_amount: Some(Decimal::ZERO),
            remaining_periods_amount: Some(Decimal::ZERO),
            first_due_date: None,
            family_ledger_serial_nums: None,
        };

        Ok((from_request, to_request))
    }

    // ================================
    // 构造 reversal request
    // ================================
    fn build_reversal_requests(
        &self,
        outgoing: &entity::transactions::Model,
        incoming: &entity::transactions::Model,
        amount: Decimal,
    ) -> (CreateTransactionRequest, CreateTransactionRequest) {
        let date = DateUtils::local_now();

        // 解析原交易描述
        fn swap_transfer_description(desc: &str) -> String {
            let desc = desc.trim();
            let mut from = "";
            let mut to = "";
            for part in desc.split_whitespace() {
                if part.starts_with("转账至") {
                    to = part.trim_start_matches("转账至");
                } else if part.starts_with("转账来自") {
                    from = part.trim_start_matches("转账来自");
                }
            }
            if from.is_empty() && to.is_empty() {
                format!("冲正：{desc}") // 如果无法解析，则直接加“冲正：”
            } else {
                format!("冲正：转账来自 {from} 转账至 {to}")
            }
        }

        let reverse_out_description = if outgoing.description.trim().is_empty() {
            format!(
                "冲正：转账来自 {} 转账至 {}",
                incoming.account_serial_num, outgoing.account_serial_num
            )
        } else {
            swap_transfer_description(&outgoing.description)
        };

        let reverse_in_description = if incoming.description.trim().is_empty() {
            format!(
                "冲正：转账来自 {} 转账至 {}",
                outgoing.account_serial_num, incoming.account_serial_num
            )
        } else {
            swap_transfer_description(&incoming.description)
        };

        let reverse_out_request = CreateTransactionRequest {
            transaction_type: TransactionType::Expense,
            transaction_status: TransactionStatus::Reversed,
            date,
            amount,
            currency: outgoing.currency.clone(),
            description: reverse_out_description,
            notes: outgoing.notes.clone(),
            account_serial_num: incoming.account_serial_num.clone(),
            to_account_serial_num: Some(outgoing.account_serial_num.clone()),
            category: "Transfer".to_string(),
            sub_category: None,
            tags: None,
            split_members: None,
            payment_method: parse_enum_filed(
                &outgoing.payment_method,
                "payment_method",
                PaymentMethod::Other,
            ),
            actual_payer_account: parse_enum_filed(
                &outgoing.actual_payer_account,
                "actual_payer_account",
                AccountType::Savings,
            ),
            related_transaction_serial_num: None,
            // 分期相关字段
            is_installment: None,
            first_due_date: None,
            total_periods: None,
            remaining_periods: None,
            installment_amount: Some(Decimal::ZERO),
            remaining_periods_amount: Some(Decimal::ZERO),
            family_ledger_serial_nums: None,
        };

        let reverse_in_request = CreateTransactionRequest {
            transaction_type: TransactionType::Income,
            transaction_status: TransactionStatus::Reversed,
            date,
            amount,
            currency: outgoing.currency.clone(),
            description: reverse_in_description,
            notes: incoming.notes.clone(),
            account_serial_num: outgoing.account_serial_num.clone(),
            to_account_serial_num: Some(incoming.account_serial_num.clone()),
            category: "Transfer".to_string(),
            sub_category: None,
            tags: None,
            split_members: None,
            payment_method: parse_enum_filed(
                &outgoing.payment_method,
                "payment_method",
                PaymentMethod::Other,
            ),
            actual_payer_account: parse_enum_filed(
                &outgoing.actual_payer_account,
                "actual_payer_account",
                AccountType::Savings,
            ),
            related_transaction_serial_num: None,
            // 分期相关字段
            is_installment: None,
            total_periods: None,
            remaining_periods: None,
            installment_amount: Some(Decimal::ZERO),
            remaining_periods_amount: Some(Decimal::ZERO),
            first_due_date: None,
            family_ledger_serial_nums: None,
        };

        (reverse_out_request, reverse_in_request)
    }

    // ================================
    // 查找并校验关联转账交易对
    // ================================
    async fn fetch_related_transfer(
        &self,
        tx: &DatabaseTransaction,
        transaction_id: &str,
    ) -> MijiResult<(entity::transactions::Model, entity::transactions::Model)> {
        let outgoing = entity::transactions::Entity::find_by_id(transaction_id)
            .lock_exclusive()
            .one(tx)
            .await?
            .ok_or_else(|| AppError::simple(BusinessCode::NotFound, "Transaction not found"))?;

        if outgoing.category != "Transfer" {
            return Err(AppError::simple(
                BusinessCode::NotFound,
                "Only transfer transactions can be reversed",
            ));
        }

        // 单向关联
        // let related_id = outgoing
        //     .related_transaction_serial_num
        //     .clone()
        //     .ok_or_else(|| {
        //         AppError::simple(BusinessCode::NotFound, "Missing related transaction")
        //     })?;

        let incoming = entity::transactions::Entity::find()
            .filter(entity::transactions::Column::RelatedTransactionSerialNum.eq(transaction_id))
            .lock_exclusive()
            .one(tx)
            .await?
            .ok_or_else(|| {
                AppError::simple(BusinessCode::NotFound, "Related transaction not found")
            })?;

        if outgoing.transaction_type == "Expense" {
            Ok((outgoing, incoming))
        } else {
            Ok((incoming, outgoing))
        }
    }

    fn serialize_model(
        &self,
        model: &entity::transactions::Model,
    ) -> MijiResult<serde_json::Value> {
        serde_json::to_value(model)
            .map_err(|e| AppError::internal_server_error(format!("Serialization failed: {e}")))
    }
}

impl std::ops::Deref for TransactionService {
    type Target = GenericCrudService<
        entity::transactions::Entity,
        TransactionFilter,
        CreateTransactionRequest,
        UpdateTransactionRequest,
        TransactionConverter,
        NoOpHooks,
    >;

    fn deref(&self) -> &Self::Target {
        &self.inner
    }
}

// 交易转换器
#[derive(Debug)]
pub struct TransactionConverter;

impl CrudConverter<entity::transactions::Entity, CreateTransactionRequest, UpdateTransactionRequest>
    for TransactionConverter
{
    fn create_to_active_model(
        &self,
        data: CreateTransactionRequest,
    ) -> MijiResult<entity::transactions::ActiveModel> {
        entity::transactions::ActiveModel::try_from(data).map_err(AppError::from_validation_errors)
    }

    fn update_to_active_model(
        &self,
        model: entity::transactions::Model,
        data: UpdateTransactionRequest,
    ) -> MijiResult<entity::transactions::ActiveModel> {
        entity::transactions::ActiveModel::try_from(data)
            .map(|mut active_model| {
                active_model.serial_num = Set(model.serial_num.clone());
                active_model.created_at = Set(model.created_at);
                active_model.updated_at = Set(Some(DateUtils::local_now()));
                active_model
            })
            .map_err(AppError::from_validation_errors)
    }

    fn primary_key_to_string(&self, model: &entity::transactions::Model) -> String {
        model.serial_num.clone()
    }

    fn table_name(&self) -> &'static str {
        "transactions"
    }
}

impl TransactionConverter {
    pub async fn model_to_with_relations(
        &self,
        db: &DbConn,
        model: entity::transactions::Model,
    ) -> MijiResult<TransactionWithRelations> {
        let account_service = AccountService::default();
        let cny_service = get_currency_service();

        let (account, currency, family_member) = tokio::try_join!(
            async {
                account_service
                    .get_account_with_relations(db, model.account_serial_num.clone())
                    .await
            },
            async { cny_service.get_by_id(db, model.currency.clone()).await },
            async {
                let serial_nums: Vec<String> = model
                    .split_members
                    .iter()
                    .filter_map(|v| v.as_str().map(|s| s.to_string()))
                    .collect();
                entity::family_member::Entity::find()
                    .filter(entity::family_member::Column::SerialNum.is_in(serial_nums))
                    .all(db)
                    .await
                    .map_err(Into::into)
            }
        )?;
        Ok(TransactionWithRelations {
            transaction: model.to_local(),
            account,
            currency: currency.to_local(),
            family_member: family_member.into_iter().map(|f| f.to_local()).collect(),
        })
    }
}

// 交易过滤器
#[derive(Debug, Clone, Validate, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct TransactionFilter {
    pub transaction_type: Option<String>,
    pub transaction_status: Option<String>,
    pub date_start: Option<String>,
    pub date_end: Option<String>,
    pub amount_min: Option<Decimal>,
    pub amount_max: Option<Decimal>,
    pub currency: Option<String>,
    pub account_serial_num: Option<String>,
    pub category: Option<String>,
    pub sub_category: Option<String>,
    pub payment_method: Option<String>,
    pub actual_payer_account: Option<String>,
    pub is_deleted: Option<bool>,
}

impl Filter<entity::transactions::Entity> for TransactionFilter {
    fn to_condition(&self) -> Condition {
        let mut condition = Condition::all();

        if let Some(transaction_type) = &self.transaction_type {
            info!("TransactionFilter type {:?}", transaction_type);
            condition =
                condition.add(entity::transactions::Column::TransactionType.eq(transaction_type));
        }
        if let Some(transaction_status) = &self.transaction_status {
            condition = condition
                .add(entity::transactions::Column::TransactionStatus.eq(transaction_status));
        }
        if let Some(date_start) = &self.date_start {
            condition = condition.add(entity::transactions::Column::Date.gte(date_start));
        }
        if let Some(date_end) = &self.date_end {
            condition = condition.add(entity::transactions::Column::Date.lte(date_end));
        }
        if let Some(amount_min) = &self.amount_min {
            condition = condition.add(entity::transactions::Column::Amount.gte(*amount_min));
        }
        if let Some(amount_max) = &self.amount_max {
            condition = condition.add(entity::transactions::Column::Amount.lte(*amount_max));
        }
        if let Some(currency) = &self.currency {
            condition = condition.add(entity::transactions::Column::Currency.eq(currency));
        }
        if let Some(account_serial_num) = &self.account_serial_num {
            condition = condition
                .add(entity::transactions::Column::AccountSerialNum.eq(account_serial_num));
        }
        if let Some(category) = &self.category {
            condition = condition.add(entity::transactions::Column::Category.eq(category));
        }
        if let Some(sub_category) = &self.sub_category {
            condition = condition.add(entity::transactions::Column::SubCategory.eq(sub_category));
        }
        if let Some(payment_method) = &self.payment_method {
            condition =
                condition.add(entity::transactions::Column::PaymentMethod.eq(payment_method));
        }
        if let Some(actual_payer_account) = &self.actual_payer_account {
            condition = condition
                .add(entity::transactions::Column::ActualPayerAccount.eq(actual_payer_account));
        }
        let is_deleted = self.is_deleted.unwrap_or_default();
        condition = condition.add(entity::transactions::Column::IsDeleted.eq(is_deleted as i32));

        condition
    }
}

// =======================================
// 新增带关联方法
// =======================================
impl TransactionService {
    pub async fn trans_create_with_relations(
        &self,
        db: &DbConn,
        data: CreateTransactionRequest,
    ) -> MijiResult<TransactionWithRelations> {
        // 保存 family_ledger_serial_nums 用于后续创建关联
        let family_ledger_serial_nums = data.family_ledger_serial_nums.clone();

        // 创建交易
        let model = self.create(db, data).await?;

        // 如果指定了家庭记账本，为每个记账本创建关联记录并更新统计
        if let Some(ledger_serials) = family_ledger_serial_nums {
            let transaction_serial = model.serial_num.clone();

            for ledger_serial in ledger_serials {
                if ledger_serial.is_empty() {
                    continue;
                }

                // 创建家庭记账本与交易的关联
                let association = entity::family_ledger_transaction::ActiveModel {
                    family_ledger_serial_num: sea_orm::ActiveValue::Set(ledger_serial.clone()),
                    transaction_serial_num: sea_orm::ActiveValue::Set(transaction_serial.clone()),
                    created_at: sea_orm::ActiveValue::Set(DateUtils::local_now()),
                    updated_at: sea_orm::ActiveValue::Set(None),
                };
                association.insert(db).await?;

                tracing::info!(
                    "创建交易与家庭记账本关联成功: transaction={}, ledger={}",
                    transaction_serial,
                    ledger_serial
                );

                // 手动更新家庭记账本统计数据
                let ledger = entity::family_ledger::Entity::find_by_id(&ledger_serial)
                    .one(db)
                    .await?
                    .ok_or_else(|| AppError::simple(BusinessCode::NotFound, "家庭记账本不存在"))?;

                let mut ledger_active = ledger.clone().into_active_model();

                // 更新交易数量
                let current_transactions = ledger.transactions;
                ledger_active.transactions = sea_orm::ActiveValue::Set(current_transactions + 1);

                // 更新时间戳
                ledger_active.updated_at = sea_orm::ActiveValue::Set(Some(DateUtils::local_now()));

                // 保存更新
                ledger_active.update(db).await?;

                tracing::info!(
                    "更新家庭记账本统计成功: ledger={}, transactions={}",
                    ledger_serial,
                    current_transactions + 1
                );
            }
        }

        self.converter().model_to_with_relations(db, model).await
    }

    pub async fn trans_get_with_relations(
        &self,
        db: &DbConn,
        id: String,
    ) -> MijiResult<TransactionWithRelations> {
        let model = self.get_by_id(db, id).await?;
        self.converter().model_to_with_relations(db, model).await
    }

    pub async fn trans_update_with_relations(
        &self,
        db: &DbConn,
        id: String,
        data: UpdateTransactionRequest,
    ) -> MijiResult<TransactionWithRelations> {
        if let Some(amount) = &data.amount
            && amount.is_sign_negative()
        {
            let model = self.get_by_id(db, id.clone()).await?;
            let mut new_data = data.clone();
            new_data.amount = Some(new_data.amount.unwrap() + model.amount);
            let result = self.update(db, id, new_data).await?;
            return self.converter().model_to_with_relations(db, result).await;
        }

        let model = self.update(db, id, data).await?;
        self.converter().model_to_with_relations(db, model).await
    }

    pub async fn trans_delete_with_relations(
        &self,
        db: &DbConn,
        serial_num: &str,
    ) -> MijiResult<()> {
        update_entity_columns_simple::<entity::transactions::Entity, _>(
            db,
            vec![(entity::transactions::Column::SerialNum, vec![serial_num])],
            vec![
                (entity::transactions::Column::IsDeleted, Expr::value(true)),
                (
                    entity::transactions::Column::UpdatedAt,
                    Expr::value(DateUtils::local_now()),
                ),
            ],
        )
        .await
        .map(|_| ())
    }

    pub async fn trans_transfer_create_with_relations(
        &self,
        db: &DbConn,
        data: TransferRequest,
    ) -> MijiResult<(TransactionWithRelations, TransactionWithRelations)> {
        let (from_model, to_model) = self.transfer(db, data).await?;
        let f = self
            .converter()
            .model_to_with_relations(db, from_model)
            .await?;
        let t = self
            .converter()
            .model_to_with_relations(db, to_model)
            .await?;
        Ok((f, t))
    }

    pub async fn trans_transfer_update_with_relations(
        &self,
        db: &DatabaseConnection,
        transaction_id: &str,
        data: TransferRequest,
    ) -> MijiResult<(TransactionWithRelations, TransactionWithRelations)> {
        let (from_model, to_model) = self.transfer_update(db, transaction_id, data).await?;
        let from_rel = self
            .converter()
            .model_to_with_relations(db, from_model)
            .await?;
        let to_rel = self
            .converter()
            .model_to_with_relations(db, to_model)
            .await?;
        Ok((from_rel, to_rel))
    }

    pub async fn trans_transfer_delete_with_relations(
        &self,
        db: &DatabaseConnection,
        serial_num: &str,
    ) -> MijiResult<(TransactionWithRelations, TransactionWithRelations)> {
        let (from_model, to_model) = self.transfer_delete(db, serial_num).await?;
        let f = self
            .converter()
            .model_to_with_relations(db, from_model)
            .await?;
        let t = self
            .converter()
            .model_to_with_relations(db, to_model)
            .await?;
        Ok((f, t))
    }

    pub async fn trans_list_with_relations(
        &self,
        db: &DbConn,
        filters: TransactionFilter,
    ) -> MijiResult<Vec<TransactionWithRelations>> {
        let models = self.list_with_filter(db, filters).await?;
        let mut result = Vec::with_capacity(models.len());
        for m in models {
            result.push(self.converter().model_to_with_relations(db, m).await?);
        }
        Ok(result)
    }

    pub async fn trans_list_paged_with_relations(
        &self,
        db: &DbConn,
        query: PagedQuery<TransactionFilter>,
    ) -> MijiResult<PagedResult<TransactionWithRelations>> {
        let paged = self.inner.list_paged(db, query).await?;
        let mut rows_with_relations = Vec::with_capacity(paged.rows.len());
        for m in paged.rows {
            let tx_with_rel = self.converter().model_to_with_relations(db, m).await?;
            rows_with_relations.push(tx_with_rel);
        }

        Ok(PagedResult {
            rows: rows_with_relations,
            total_count: paged.total_count,
            current_page: paged.current_page,
            page_size: paged.page_size,
            total_pages: paged.total_pages,
        })
    }

    pub async fn query_income_and_expense(
        &self,
        db: &DatabaseConnection,
        start_date: String,
        end_date: String,
    ) -> MijiResult<IncomeExpense> {
        let mut query = entity::transactions::Entity::find()
            .select_only()
            .filter(TransactionColumn::IsDeleted.eq(0))
            .filter(TransactionColumn::Date.gte(start_date))
            .filter(TransactionColumn::Date.lt(end_date));

        // Total income and expense
        let total_income_expr = Expr::val(0.0).add(
            SimpleExpr::FunctionCall(Func::coalesce(vec![
                SimpleExpr::FunctionCall(Func::sum(
                    Expr::case(
                        Condition::all()
                            .add(TransactionColumn::TransactionType.eq("Income"))
                            .add(TransactionColumn::Category.ne("Transfer"))
                            .add(
                                // 排除分期交易（is_installment = true 或 is_installment IS NULL 为 false/null）
                                Expr::col(TransactionColumn::IsInstallment)
                                    .is_null()
                                    .or(Expr::col(TransactionColumn::IsInstallment).eq(false)),
                            ),
                        Expr::col(TransactionColumn::Amount),
                    )
                    .finally(0.0)
                    .cast_as(Alias::new("DECIMAL(16,4)")),
                )),
                Expr::val(0.0).into(),
            ]))
            .cast_as(Alias::new("DECIMAL(16,4)")),
        );

        let total_expense_expr = Expr::val(0.0).add(
            SimpleExpr::FunctionCall(Func::coalesce(vec![
                SimpleExpr::FunctionCall(Func::sum(
                    Expr::case(
                        Condition::all()
                            .add(TransactionColumn::TransactionType.eq("Expense"))
                            .add(TransactionColumn::Category.ne("Transfer"))
                            .add(
                                // 排除分期交易（is_installment = true 或 is_installment IS NULL 为 false/null）
                                Expr::col(TransactionColumn::IsInstallment)
                                    .is_null()
                                    .or(Expr::col(TransactionColumn::IsInstallment).eq(false)),
                            ),
                        Expr::col(TransactionColumn::Amount),
                    )
                    .finally(0.0)
                    .cast_as(Alias::new("DECIMAL(16,4)")),
                )),
                Expr::val(0.0).into(),
            ]))
            .cast_as(Alias::new("DECIMAL(16,4)")),
        );

        // Transfer income and expense
        let transfer_income_expr = Expr::val(0.0).add(
            SimpleExpr::FunctionCall(Func::coalesce(vec![
                SimpleExpr::FunctionCall(Func::sum(
                    Expr::case(
                        Condition::all()
                            .add(TransactionColumn::TransactionType.eq("Income"))
                            .add(TransactionColumn::Category.eq("Transfer"))
                            .add(TransactionColumn::ActualPayerAccount.ne("CreditCard"))
                            .add(
                                // 排除分期交易
                                Expr::col(TransactionColumn::IsInstallment)
                                    .is_null()
                                    .or(Expr::col(TransactionColumn::IsInstallment).eq(false)),
                            ),
                        Expr::col(TransactionColumn::Amount),
                    )
                    .finally(0.0)
                    .cast_as(Alias::new("DECIMAL(16,4)")),
                )),
                Expr::val(0.0).into(),
            ]))
            .cast_as(Alias::new("DECIMAL(16,4)")),
        );

        let transfer_expense_expr = Expr::val(0.0).add(
            SimpleExpr::FunctionCall(Func::coalesce(vec![
                SimpleExpr::FunctionCall(Func::sum(
                    Expr::case(
                        Condition::all()
                            .add(TransactionColumn::TransactionType.eq("Expense"))
                            .add(TransactionColumn::Category.eq("Transfer"))
                            .add(TransactionColumn::ActualPayerAccount.ne("CreditCard"))
                            .add(
                                // 排除分期交易
                                Expr::col(TransactionColumn::IsInstallment)
                                    .is_null()
                                    .or(Expr::col(TransactionColumn::IsInstallment).eq(false)),
                            ),
                        Expr::col(TransactionColumn::Amount),
                    )
                    .finally(0.0)
                    .cast_as(Alias::new("DECIMAL(16,4)")),
                )),
                Expr::val(0.0).into(),
            ]))
            .cast_as(Alias::new("DECIMAL(16,4)")),
        );

        query = query
            .expr_as(total_income_expr, "total")
            .expr_as(total_expense_expr, "total_expense")
            .expr_as(transfer_income_expr, "transfer_income")
            .expr_as(transfer_expense_expr, "transfer_expense");

        // Add account type specific sums
        for config in TRANSACTION_TYPE_CONFIGS.iter() {
            let income_expr = Expr::val(0.0).add(
                SimpleExpr::FunctionCall(Func::coalesce(vec![
                    SimpleExpr::FunctionCall(Func::sum(
                        Expr::case(
                            Condition::all()
                                .add(TransactionColumn::TransactionType.eq("Income"))
                                .add(TransactionColumn::ActualPayerAccount.eq(config.account_type))
                                .add(
                                    // 排除分期交易
                                    Expr::col(TransactionColumn::IsInstallment)
                                        .is_null()
                                        .or(Expr::col(TransactionColumn::IsInstallment).eq(false)),
                                ),
                            Expr::col(TransactionColumn::Amount),
                        )
                        .finally(0.0)
                        .cast_as(Alias::new("DECIMAL(16,4)")),
                    )),
                    Expr::val(0.0).into(),
                ]))
                .cast_as(Alias::new("DECIMAL(16,4)")),
            );

            let expense_expr = Expr::val(0.0).add(
                SimpleExpr::FunctionCall(Func::coalesce(vec![
                    SimpleExpr::FunctionCall(Func::sum(
                        Expr::case(
                            Condition::all()
                                .add(TransactionColumn::TransactionType.eq("Expense"))
                                .add(TransactionColumn::ActualPayerAccount.eq(config.account_type))
                                .add(
                                    // 排除分期交易
                                    Expr::col(TransactionColumn::IsInstallment)
                                        .is_null()
                                        .or(Expr::col(TransactionColumn::IsInstallment).eq(false)),
                                ),
                            Expr::col(TransactionColumn::Amount),
                        )
                        .finally(0.0)
                        .cast_as(Alias::new("DECIMAL(16,4)")),
                    )),
                    Expr::val(0.0).into(),
                ]))
                .cast_as(Alias::new("DECIMAL(16,4)")),
            );

            query = query
                .expr_as(income_expr, format!("{}_income", config.field))
                .expr_as(expense_expr, format!("{}_expense", config.field));
        }

        let result = query
            .into_model::<IncomeExpenseRaw>()
            .one(db)
            .await
            .map_err(AppError::from)?
            .map(IncomeExpense::from)
            .unwrap_or(IncomeExpense::default());

        Ok(result)
    }

    /// 获取交易统计数据
    pub async fn get_transaction_stats(
        &self,
        db: &DatabaseConnection,
        request: TransactionStatsRequest,
    ) -> MijiResult<TransactionStatsResponse> {
        let start_date = request.start_date;
        let end_date = request.end_date;

        // 构建基础查询条件
        let mut base_condition = Condition::all()
            .add(TransactionColumn::IsDeleted.eq(false))
            .add(TransactionColumn::Date.gte(&start_date))
            .add(TransactionColumn::Date.lte(&end_date));

        // 添加筛选条件
        if let Some(category) = &request.category {
            base_condition = base_condition.add(TransactionColumn::Category.eq(category));
        }
        if let Some(sub_category) = &request.sub_category {
            base_condition = base_condition.add(TransactionColumn::SubCategory.eq(sub_category));
        }
        if let Some(account_serial_num) = &request.account_serial_num {
            base_condition =
                base_condition.add(TransactionColumn::AccountSerialNum.eq(account_serial_num));
        }
        if let Some(transaction_type) = &request.transaction_type {
            base_condition =
                base_condition.add(TransactionColumn::TransactionType.eq(transaction_type));
        }
        if let Some(currency) = &request.currency {
            base_condition = base_condition.add(TransactionColumn::Currency.eq(currency));
        }

        // 获取基础统计数据
        let income_expense = self
            .query_income_and_expense(db, start_date.clone(), end_date.clone())
            .await?;

        // 获取交易列表用于统计（现在主要用于分类统计，交易笔数使用all_transactions）
        let _transactions = entity::transactions::Entity::find()
            .filter(base_condition.clone())
            .all(db)
            .await
            .map_err(AppError::from)?;

        // 获取全部交易笔数（不受分类类型筛选影响）
        let mut all_transactions_condition = Condition::all()
            .add(TransactionColumn::IsDeleted.eq(false))
            .add(TransactionColumn::Date.gte(&start_date))
            .add(TransactionColumn::Date.lte(&end_date));

        // 添加非分类相关的筛选条件
        if let Some(account_serial_num) = &request.account_serial_num {
            all_transactions_condition = all_transactions_condition
                .add(TransactionColumn::AccountSerialNum.eq(account_serial_num));
        }
        if let Some(currency) = &request.currency {
            all_transactions_condition =
                all_transactions_condition.add(TransactionColumn::Currency.eq(currency));
        }

        let all_transactions = entity::transactions::Entity::find()
            .filter(all_transactions_condition)
            .all(db)
            .await
            .map_err(AppError::from)?;

        let total_income = income_expense.income.total;
        let total_expense = income_expense.expense.total;
        // 转账总额只计算支出部分，避免重复计算（转账会产生支出和收入两笔记录）
        let total_transfer = income_expense.transfer.expense;
        let net_income = total_income - total_expense;
        // 交易笔数使用全部交易的笔数，不受分类类型筛选影响
        let transaction_count = all_transactions.len() as i32;
        let average_transaction = if transaction_count > 0 {
            (total_income + total_expense) / Decimal::from(transaction_count)
        } else {
            Decimal::ZERO
        };

        let summary = TransactionStatsSummary {
            total_income,
            total_expense,
            net_income,
            transaction_count,
            average_transaction,
        };

        // 按分类统计
        let top_categories = self
            .get_category_stats(db, &base_condition, &total_expense)
            .await?;

        // 获取收入分类统计
        let top_income_categories = self
            .get_income_category_stats(db, &base_condition, &total_income)
            .await?;

        // 获取转账分类统计
        let top_transfer_categories = self
            .get_transfer_category_stats(db, &base_condition, &total_transfer)
            .await?;

        // 按时间维度统计趋势
        let monthly_trends = self
            .get_monthly_trends(db, &start_date, &end_date, &base_condition)
            .await?;
        let weekly_trends = self
            .get_weekly_trends(db, &start_date, &end_date, &base_condition)
            .await?;

        // 按支付渠道统计
        let top_payment_methods = self
            .get_payment_method_stats(db, &base_condition, &total_expense)
            .await?;

        // 获取收入支付渠道统计
        let top_income_payment_methods = self
            .get_income_payment_method_stats(db, &base_condition, &total_income)
            .await?;

        // 获取转账支付渠道统计
        let top_transfer_payment_methods = self
            .get_transfer_payment_method_stats(db, &base_condition, &total_transfer)
            .await?;

        Ok(TransactionStatsResponse {
            summary,
            top_categories,
            top_income_categories,
            top_transfer_categories,
            top_payment_methods,
            top_income_payment_methods,
            top_transfer_payment_methods,
            monthly_trends,
            weekly_trends,
        })
    }

    /// 获取分类统计
    async fn get_category_stats(
        &self,
        db: &DatabaseConnection,
        base_condition: &Condition,
        total_expense: &Decimal,
    ) -> MijiResult<Vec<CategoryStats>> {
        let mut condition = base_condition.clone();
        condition = condition.add(TransactionColumn::TransactionType.eq("Expense"));

        let category_stats = entity::transactions::Entity::find()
            .select_only()
            .column(TransactionColumn::Category)
            .expr_as(Expr::col(TransactionColumn::Amount).sum(), "amount")
            .expr_as(Expr::col(TransactionColumn::SerialNum).count(), "count")
            .filter(condition)
            .group_by(TransactionColumn::Category)
            .order_by_desc(Expr::col(TransactionColumn::Amount).sum())
            .limit(10)
            .into_model::<CategoryStatsRaw>()
            .all(db)
            .await
            .map_err(AppError::from)?;

        let mut result = Vec::new();
        for stats in category_stats {
            let percentage = if *total_expense > Decimal::ZERO {
                (stats.amount / *total_expense) * Decimal::from(100)
            } else {
                Decimal::ZERO
            };

            result.push(CategoryStats {
                category: stats.category,
                amount: stats.amount,
                count: stats.count as i32,
                percentage,
            });
        }

        Ok(result)
    }

    /// 获取收入分类统计
    async fn get_income_category_stats(
        &self,
        db: &DatabaseConnection,
        base_condition: &Condition,
        total_income: &Decimal,
    ) -> MijiResult<Vec<CategoryStats>> {
        let mut condition = base_condition.clone();
        condition = condition.add(TransactionColumn::TransactionType.eq("Income"));

        let category_stats = entity::transactions::Entity::find()
            .select_only()
            .column(TransactionColumn::Category)
            .expr_as(Expr::col(TransactionColumn::Amount).sum(), "amount")
            .expr_as(Expr::col(TransactionColumn::SerialNum).count(), "count")
            .filter(condition)
            .group_by(TransactionColumn::Category)
            .order_by_desc(Expr::col(TransactionColumn::Amount).sum())
            .limit(10)
            .into_model::<CategoryStatsRaw>()
            .all(db)
            .await
            .map_err(AppError::from)?;

        let mut result = Vec::new();
        for stats in category_stats {
            let percentage = if *total_income > Decimal::ZERO {
                (stats.amount / *total_income) * Decimal::from(100)
            } else {
                Decimal::ZERO
            };

            result.push(CategoryStats {
                category: stats.category,
                amount: stats.amount,
                count: stats.count as i32,
                percentage,
            });
        }

        Ok(result)
    }

    /// 获取转账分类统计
    async fn get_transfer_category_stats(
        &self,
        db: &DatabaseConnection,
        base_condition: &Condition,
        total_transfer: &Decimal,
    ) -> MijiResult<Vec<CategoryStats>> {
        let mut condition = base_condition.clone();
        // 转账是根据分类来筛选的，不是根据交易类型
        condition = condition.add(TransactionColumn::Category.eq("Transfer"));
        // 只统计转账的支出部分，避免重复计算（转账会产生支出和收入两笔记录）
        condition = condition.add(TransactionColumn::TransactionType.eq("Expense"));

        let category_stats = entity::transactions::Entity::find()
            .select_only()
            .column(TransactionColumn::Category)
            .expr_as(Expr::col(TransactionColumn::Amount).sum(), "amount")
            .expr_as(Expr::col(TransactionColumn::SerialNum).count(), "count")
            .filter(condition)
            .group_by(TransactionColumn::Category)
            .order_by_desc(Expr::col(TransactionColumn::Amount).sum())
            .limit(10)
            .into_model::<CategoryStatsRaw>()
            .all(db)
            .await
            .map_err(AppError::from)?;

        let mut result = Vec::new();
        for stats in category_stats {
            let percentage = if *total_transfer > Decimal::ZERO {
                (stats.amount / *total_transfer) * Decimal::from(100)
            } else {
                Decimal::ZERO
            };

            result.push(CategoryStats {
                category: stats.category,
                amount: stats.amount,
                count: stats.count as i32,
                percentage,
            });
        }

        Ok(result)
    }

    /// 获取月度趋势
    async fn get_monthly_trends(
        &self,
        db: &DatabaseConnection,
        start_date: &str,
        end_date: &str,
        _base_condition: &Condition,
    ) -> MijiResult<Vec<TimeTrendStats>> {
        let mut trends = Vec::new();
        let mut current = chrono::NaiveDate::parse_from_str(start_date, "%Y-%m-%d")
            .map_err(|e| AppError::internal_server_error(format!("Invalid start date: {e}")))?;

        let end = chrono::NaiveDate::parse_from_str(end_date, "%Y-%m-%d")
            .map_err(|e| AppError::internal_server_error(format!("Invalid end date: {e}")))?;

        while current <= end {
            let month_start = current.format("%Y-%m-%d").to_string();
            let month_end = if current.month() == 12 {
                format!("{}-12-31", current.year())
            } else {
                let next_month = current.with_month0(current.month0() + 1).unwrap();
                (next_month - chrono::Duration::days(1))
                    .format("%Y-%m-%d")
                    .to_string()
            };

            let income_expense = self
                .query_income_and_expense(db, month_start.clone(), month_end)
                .await?;

            trends.push(TimeTrendStats {
                period: current.format("%Y-%m").to_string(),
                income: income_expense.income.total,
                expense: income_expense.expense.total,
                net_income: income_expense.income.total - income_expense.expense.total,
            });

            current = if current.month() == 12 {
                current
                    .with_year(current.year() + 1)
                    .unwrap()
                    .with_month0(0)
                    .unwrap()
            } else {
                current.with_month0(current.month0() + 1).unwrap()
            };
        }

        Ok(trends)
    }

    /// 获取周度趋势
    async fn get_weekly_trends(
        &self,
        db: &DatabaseConnection,
        start_date: &str,
        end_date: &str,
        _base_condition: &Condition,
    ) -> MijiResult<Vec<TimeTrendStats>> {
        let mut trends = Vec::new();
        let mut current = chrono::NaiveDate::parse_from_str(start_date, "%Y-%m-%d")
            .map_err(|e| AppError::internal_server_error(format!("Invalid start date: {e}")))?;

        let end = chrono::NaiveDate::parse_from_str(end_date, "%Y-%m-%d")
            .map_err(|e| AppError::internal_server_error(format!("Invalid end date: {e}")))?;

        // 找到当前周的起始日期
        let weekday = current.weekday();
        let days_from_monday = weekday.num_days_from_monday();
        current -= chrono::Duration::days(days_from_monday as i64);

        while current <= end {
            let week_start = current.format("%Y-%m-%d").to_string();
            let week_end = (current + chrono::Duration::days(6))
                .format("%Y-%m-%d")
                .to_string();

            let income_expense = self
                .query_income_and_expense(db, week_start.clone(), week_end)
                .await?;

            trends.push(TimeTrendStats {
                period: format!("第{}周", current.iso_week().week()),
                income: income_expense.income.total,
                expense: income_expense.expense.total,
                net_income: income_expense.income.total - income_expense.expense.total,
            });

            current += chrono::Duration::days(7);
        }

        Ok(trends)
    }

    /// 获取支付渠道统计
    async fn get_payment_method_stats(
        &self,
        db: &DatabaseConnection,
        base_condition: &Condition,
        total_expense: &Decimal,
    ) -> MijiResult<Vec<PaymentMethodStats>> {
        let mut condition = base_condition.clone();
        condition = condition.add(TransactionColumn::TransactionType.eq("Expense"));

        let payment_method_stats = entity::transactions::Entity::find()
            .select_only()
            .column(TransactionColumn::PaymentMethod)
            .expr_as(Expr::col(TransactionColumn::Amount).sum(), "amount")
            .expr_as(Expr::col(TransactionColumn::SerialNum).count(), "count")
            .filter(condition)
            .group_by(TransactionColumn::PaymentMethod)
            .order_by_desc(Expr::col(TransactionColumn::Amount).sum())
            .limit(10)
            .into_model::<PaymentMethodStatsRaw>()
            .all(db)
            .await
            .map_err(AppError::from)?;

        let mut result = Vec::new();
        for stats in payment_method_stats {
            let percentage = if *total_expense > Decimal::ZERO {
                (stats.amount / *total_expense) * Decimal::from(100)
            } else {
                Decimal::ZERO
            };

            result.push(PaymentMethodStats {
                payment_method: stats.payment_method,
                amount: stats.amount,
                count: stats.count as i32,
                percentage,
            });
        }

        Ok(result)
    }

    /// 获取收入支付渠道统计
    async fn get_income_payment_method_stats(
        &self,
        db: &DatabaseConnection,
        base_condition: &Condition,
        total_income: &Decimal,
    ) -> MijiResult<Vec<PaymentMethodStats>> {
        let mut condition = base_condition.clone();
        condition = condition.add(TransactionColumn::TransactionType.eq("Income"));

        let payment_method_stats = entity::transactions::Entity::find()
            .select_only()
            .column(TransactionColumn::PaymentMethod)
            .expr_as(Expr::col(TransactionColumn::Amount).sum(), "amount")
            .expr_as(Expr::col(TransactionColumn::SerialNum).count(), "count")
            .filter(condition)
            .group_by(TransactionColumn::PaymentMethod)
            .order_by_desc(Expr::col(TransactionColumn::Amount).sum())
            .limit(10)
            .into_model::<PaymentMethodStatsRaw>()
            .all(db)
            .await
            .map_err(AppError::from)?;

        let mut result = Vec::new();
        for stats in payment_method_stats {
            let percentage = if *total_income > Decimal::ZERO {
                (stats.amount / *total_income) * Decimal::from(100)
            } else {
                Decimal::ZERO
            };

            result.push(PaymentMethodStats {
                payment_method: stats.payment_method,
                amount: stats.amount,
                count: stats.count as i32,
                percentage,
            });
        }

        Ok(result)
    }

    /// 获取转账支付渠道统计
    async fn get_transfer_payment_method_stats(
        &self,
        db: &DatabaseConnection,
        base_condition: &Condition,
        total_transfer: &Decimal,
    ) -> MijiResult<Vec<PaymentMethodStats>> {
        let mut condition = base_condition.clone();
        // 转账是根据分类来筛选的，不是根据交易类型
        condition = condition.add(TransactionColumn::Category.eq("Transfer"));
        // 只统计转账的支出部分，避免重复计算（转账会产生支出和收入两笔记录）
        condition = condition.add(TransactionColumn::TransactionType.eq("Expense"));

        let payment_method_stats = entity::transactions::Entity::find()
            .select_only()
            .column(TransactionColumn::PaymentMethod)
            .expr_as(Expr::col(TransactionColumn::Amount).sum(), "amount")
            .expr_as(Expr::col(TransactionColumn::SerialNum).count(), "count")
            .filter(condition)
            .group_by(TransactionColumn::PaymentMethod)
            .order_by_desc(Expr::col(TransactionColumn::Amount).sum())
            .limit(10)
            .into_model::<PaymentMethodStatsRaw>()
            .all(db)
            .await
            .map_err(AppError::from)?;

        let mut result = Vec::new();
        for stats in payment_method_stats {
            let percentage = if *total_transfer > Decimal::ZERO {
                (stats.amount / *total_transfer) * Decimal::from(100)
            } else {
                Decimal::ZERO
            };

            result.push(PaymentMethodStats {
                payment_method: stats.payment_method,
                amount: stats.amount,
                count: stats.count as i32,
                percentage,
            });
        }

        Ok(result)
    }
}

fn parse_json<T: serde::de::DeserializeOwned>(s: &str, field: &str) -> MijiResult<T> {
    serde_json::from_str(s).map_err(|e| {
        AppError::internal_server_error(format!("Failed to parse JSON field '{field}': {e}"))
    })
}
