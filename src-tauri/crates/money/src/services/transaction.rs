use common::{
    BusinessCode,
    crud::service::{CrudConverter, GenericCrudService},
    error::{AppError, MijiResult},
    paginations::Filter,
    utils::{date::DateUtils, uuid::McgUuid},
};
use sea_orm::{
    ActiveModelTrait, ActiveValue::Set, ColumnTrait, Condition, DatabaseConnection,
    DatabaseTransaction, EntityTrait, IntoActiveModel, QuerySelect, TransactionTrait,
    prelude::Decimal,
};
use serde::{Deserialize, Serialize};
use snafu::GenerateImplicitData;
use std::sync::Arc;
use validator::Validate;

use crate::{
    dto::transactions::{CreateTransactionRequest, TransferRequest, UpdateTransactionRequest},
    error::MoneyError,
    services::transaction_hooks::NoOpHooks,
};

#[derive(Debug, Clone, Validate, Serialize, Deserialize)]
pub struct TransactionFilter {
    pub serial_num: Option<String>,
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
    pub is_deleted: Option<i32>,
}

impl Filter<entity::transactions::Entity> for TransactionFilter {
    fn to_condition(&self) -> Condition {
        let mut condition = Condition::all();

        if let Some(serial_num) = &self.serial_num {
            condition = condition.add(entity::transactions::Column::SerialNum.eq(serial_num));
        }
        if let Some(transaction_type) = &self.transaction_type {
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
        if let Some(is_deleted) = self.is_deleted {
            condition = condition.add(entity::transactions::Column::IsDeleted.eq(is_deleted));
        }

        condition
    }
}

#[derive(Debug)]
pub struct TransactionConverter;

impl CrudConverter<entity::transactions::Entity, CreateTransactionRequest, UpdateTransactionRequest>
    for TransactionConverter
{
    fn create_to_active_model(
        &self,
        data: CreateTransactionRequest,
    ) -> MijiResult<entity::transactions::ActiveModel> {
        Ok(data.into())
    }

    fn update_to_active_model(
        &self,
        model: entity::transactions::Model,
        data: UpdateTransactionRequest,
    ) -> MijiResult<entity::transactions::ActiveModel> {
        let mut active_model = model.into_active_model();
        data.apply_to_model(&mut active_model);
        Ok(active_model)
    }

    fn primary_key_to_string(&self, model: &entity::transactions::Model) -> String {
        model.serial_num.clone()
    }

    fn table_name(&self) -> &'static str {
        "transactions"
    }
}

pub struct TransactionServiceImpl {
    service: GenericCrudService<
        entity::transactions::Entity,
        TransactionFilter,
        CreateTransactionRequest,
        UpdateTransactionRequest,
        TransactionConverter,
        NoOpHooks,
    >,
}

impl TransactionServiceImpl {
    pub fn new(
        converter: TransactionConverter,
        hooks: NoOpHooks,
        logger: Arc<dyn common::log::logger::OperationLogger>,
    ) -> Self {
        Self {
            service: GenericCrudService::new(converter, hooks, logger),
        }
    }

    pub async fn transfer(
        &self,
        db: &DatabaseConnection,
        data: TransferRequest,
    ) -> MijiResult<(entity::transactions::Model, entity::transactions::Model)> {
        // 验证数据
        data.validate().map_err(AppError::from_validation_errors)?;

        // 开始事务
        let tx = db.begin().await?;

        // 查询转出账户
        let from_account = entity::account::Entity::find_by_id(&data.from_account)
            .lock_exclusive()
            .one(&tx)
            .await?
            .ok_or_else(|| AppError::simple(BusinessCode::NotFound, "From account not found"))?;

        // 查询转入账户
        let to_account = entity::account::Entity::find_by_id(&data.to_account)
            .lock_exclusive()
            .one(&tx)
            .await?
            .ok_or_else(|| AppError::simple(BusinessCode::NotFound, "To account not found"))?;

        // 检查转出账户余额是否充足
        if from_account.balance < data.amount {
            return Err(MoneyError::InsufficientFunds {
                balance: data.amount,
                backtrace: snafu::Backtrace::generate(),
            }
            .into());
        }

        // 克隆账户用于日志记录
        let original_from_account = from_account.clone();
        let original_to_account = to_account.clone();

        // 更新账户余额
        let new_from_balance = from_account.balance - data.amount;
        let new_to_balance = to_account.balance + data.amount;

        // 更新转出账户
        let mut from_account_active = from_account.into_active_model();
        from_account_active.balance = Set(new_from_balance);
        let updated_from_account = from_account_active.update(&tx).await?;

        // 记录账户更新日志
        self.log_account_update(
            &tx,
            &updated_from_account,
            &original_from_account,
            "BALANCE_UPDATE_FROM",
        )
        .await?;

        // 更新转入账户
        let mut to_account_active = to_account.into_active_model();
        to_account_active.balance = Set(new_to_balance);
        let updated_to_account = to_account_active.update(&tx).await?;

        // 记录账户更新日志
        self.log_account_update(
            &tx,
            &updated_to_account,
            &original_to_account,
            "BALANCE_UPDATE_TO",
        )
        .await?;

        // 生成唯一序列号
        let trans_from_serial_num = McgUuid::uuid(38);
        let trans_to_serial_num = McgUuid::uuid(38);
        let now = DateUtils::current_datetime_local_fixed().to_string();

        // 创建转出交易
        let from_tx = entity::transactions::ActiveModel {
            serial_num: Set(trans_from_serial_num.clone()),
            transaction_type: Set("Expense".to_string()),
            transaction_status: Set("Completed".to_string()),
            date: Set(data.date.clone().unwrap_or_else(|| now.clone())),
            amount: Set(-data.amount), // 转出为负
            currency: Set(data.currency.clone()),
            description: Set(data.description.clone()),
            notes: Set(data.notes.clone()),
            account_serial_num: Set(data.from_account.clone()),
            category: Set("Transfer".to_string()),
            sub_category: Set(None),
            tags: Set(None),
            split_members: Set(None),
            payment_method: Set(data.payment_method.clone()),
            actual_payer_account: Set(data.from_account.clone()),
            related_transaction_serial_num: Set(Some(trans_to_serial_num.clone())),
            is_deleted: Set(0),
            created_at: Set(now.clone()),
            updated_at: Set(Some(now.clone())),
        };

        // 创建转入交易
        let to_tx = entity::transactions::ActiveModel {
            serial_num: Set(trans_to_serial_num.clone()),
            transaction_type: Set("Income".to_string()),
            transaction_status: Set("Completed".to_string()),
            date: Set(data.date.unwrap_or_else(|| now.clone())),
            amount: Set(data.amount), // 转入为正
            currency: Set(data.currency.clone()),
            description: Set(data.description.clone()),
            notes: Set(data.notes.clone()),
            account_serial_num: Set(data.to_account.clone()),
            category: Set("Transfer".to_string()),
            sub_category: Set(None),
            tags: Set(None),
            split_members: Set(None),
            payment_method: Set(data.payment_method.clone()),
            actual_payer_account: Set(data.from_account.clone()),
            related_transaction_serial_num: Set(Some(trans_from_serial_num.clone())),
            is_deleted: Set(0),
            created_at: Set(now.clone()),
            updated_at: Set(Some(now)),
        };

        // 插入数据库
        let from_model = from_tx.insert(&tx).await?;
        let to_model = to_tx.insert(&tx).await?;

        // 记录交易日志
        self.log_transaction_operation(&tx, &from_model, None, "TRANSFER_OUT")
            .await?;

        self.log_transaction_operation(&tx, &to_model, None, "TRANSFER_IN")
            .await?;

        // 提交事务
        tx.commit().await?;

        Ok((from_model, to_model))
    }

    /// 删除转账交易（撤销转账）
    pub async fn delete_transfer(
        &self,
        db: &DatabaseConnection,
        transaction_id: &str,
    ) -> MijiResult<(entity::transactions::Model, entity::transactions::Model)> {
        // 开始事务
        let tx = db.begin().await?;

        // 查找原始转出交易
        let original_outgoing = entity::transactions::Entity::find_by_id(transaction_id)
            .lock_exclusive()
            .one(&tx)
            .await?
            .ok_or_else(|| AppError::simple(BusinessCode::NotFound, "Transaction not found"))?;

        // 在移动前克隆原始转出交易
        let original_outgoing_clone = original_outgoing.clone();

        // 验证是否为转账交易
        if original_outgoing.category != "Transfer" {
            return Err(AppError::simple(
                BusinessCode::NotFound,
                "Only transfer transactions can be reversed",
            ));
        }

        // 获取关联交易ID
        let related_id = original_outgoing
            .related_transaction_serial_num
            .as_ref()
            .ok_or_else(|| {
                AppError::simple(
                    BusinessCode::NotFound,
                    "Transfer transaction missing related transaction",
                )
            })?
            .clone(); // 克隆字符串

        // 查找原始转入交易
        let original_incoming = entity::transactions::Entity::find_by_id(&related_id)
            .lock_exclusive()
            .one(&tx)
            .await?
            .ok_or_else(|| {
                AppError::simple(BusinessCode::NotFound, "Related transaction not found")
            })?;

        // 在移动前克隆原始转入交易
        let original_incoming_clone = original_incoming.clone();

        // 验证两条交易是否匹配
        if original_incoming.related_transaction_serial_num.as_deref() != Some(transaction_id) {
            return Err(AppError::simple(
                BusinessCode::NotFound,
                "Transactions are not properly related",
            ));
        }

        // 查询转出账户
        let from_account =
            entity::account::Entity::find_by_id(&original_outgoing.account_serial_num)
                .lock_exclusive()
                .one(&tx)
                .await?
                .ok_or_else(|| {
                    AppError::simple(BusinessCode::NotFound, "From account not found")
                })?;

        // 查询转入账户
        let to_account = entity::account::Entity::find_by_id(&original_incoming.account_serial_num)
            .lock_exclusive()
            .one(&tx)
            .await?
            .ok_or_else(|| AppError::simple(BusinessCode::NotFound, "To account not found"))?;

        // 计算转账金额（取绝对值）
        let amount = original_outgoing.amount.abs();

        // 更新账户余额（反向操作）
        let new_from_balance = from_account.balance + amount; // 转出账户增加余额
        let new_to_balance = to_account.balance - amount; // 转入账户减少余额

        // 更新转出账户
        let mut from_account_active = from_account.clone().into_active_model();
        from_account_active.balance = Set(new_from_balance);
        let updated_from_account = from_account_active.update(&tx).await?;

        // 记录账户更新日志
        self.log_account_update(
            &tx,
            &updated_from_account,
            &from_account,
            "BALANCE_REVERSE_FROM",
        )
        .await?;

        // 更新转入账户
        let mut to_account_active = to_account.clone().into_active_model();
        to_account_active.balance = Set(new_to_balance);
        let updated_to_account = to_account_active.update(&tx).await?;

        // 记录账户更新日志
        self.log_account_update(&tx, &updated_to_account, &to_account, "BALANCE_REVERSE_TO")
            .await?;

        // 标记原始交易为已删除
        let mut original_outgoing_active = original_outgoing.into_active_model();
        original_outgoing_active.is_deleted = Set(1);
        let updated_outgoing = original_outgoing_active.update(&tx).await?;

        let mut original_incoming_active = original_incoming.into_active_model();
        original_incoming_active.is_deleted = Set(1);
        let updated_incoming = original_incoming_active.update(&tx).await?;

        // 记录交易更新日志
        self.log_transaction_operation(
            &tx,
            &updated_outgoing,
            Some(self.serialize_model(&original_outgoing_clone)?),
            "TRANSFER_REVERSE_OUT",
        )
        .await?;

        self.log_transaction_operation(
            &tx,
            &updated_incoming,
            Some(self.serialize_model(&original_incoming_clone)?),
            "TRANSFER_REVERSE_IN",
        )
        .await?;

        // 生成唯一序列号
        let reverse_out_serial_num = McgUuid::uuid(38);
        let reverse_in_serial_num = McgUuid::uuid(38);
        let now = DateUtils::current_datetime_local_fixed().to_string();

        // 创建反向转出交易（原转入账户转出）
        let reverse_out = entity::transactions::ActiveModel {
            serial_num: Set(reverse_out_serial_num.clone()),
            transaction_type: Set("Expense".to_string()),
            transaction_status: Set("Reversed".to_string()),
            date: Set(now.clone()),
            amount: Set(-amount), // 转出为负
            currency: Set(original_outgoing_clone.currency.clone()),
            description: Set(format!(
                "Reversal of {}",
                original_outgoing_clone.description.clone()
            )),
            notes: original_outgoing_clone
                .notes
                .clone()
                .map(Set)
                .unwrap_or(Set("".to_string()))
                .into(),
            account_serial_num: Set(original_incoming_clone.account_serial_num.clone()),
            category: Set("Transfer".to_string()),
            sub_category: Set(None),
            tags: Set(None),
            split_members: Set(None),
            payment_method: Set(original_outgoing_clone.payment_method.clone()),
            actual_payer_account: Set(original_outgoing_clone.actual_payer_account.clone()),
            related_transaction_serial_num: Set(Some(reverse_in_serial_num.clone())),
            is_deleted: Set(0),
            created_at: Set(now.clone()),
            updated_at: Set(Some(now.clone())),
        };

        // 创建反向转入交易（原转出账户转入）
        let reverse_in = entity::transactions::ActiveModel {
            serial_num: Set(reverse_in_serial_num.clone()),
            transaction_type: Set("Income".to_string()),
            transaction_status: Set("Reversed".to_string()),
            date: Set(now.clone()),
            amount: Set(amount), // 转入为正
            currency: Set(original_outgoing_clone.currency.clone()),
            description: Set(format!(
                "Reversal of {}",
                &original_incoming_clone.description
            )),
            notes: original_incoming_clone
                .notes
                .clone()
                .map(Set)
                .unwrap_or(Set("".to_string()))
                .into(),
            account_serial_num: Set(original_outgoing_clone.account_serial_num.clone()),
            category: Set("Transfer".to_string()),
            sub_category: Set(None),
            tags: Set(None),
            split_members: Set(None),
            payment_method: Set(original_outgoing_clone.payment_method.clone()),
            actual_payer_account: Set(original_outgoing_clone.actual_payer_account.clone()),
            related_transaction_serial_num: Set(Some(reverse_out_serial_num.clone())),
            is_deleted: Set(0),
            created_at: Set(now.clone()),
            updated_at: Set(Some(now)),
        };

        // 插入数据库
        let reverse_out_model = reverse_out.insert(&tx).await?;
        let reverse_in_model = reverse_in.insert(&tx).await?;

        // 记录反向交易日志
        self.log_transaction_operation(
            &tx,
            &reverse_out_model,
            None,
            "TRANSFER_REVERSE_OUT_CREATE",
        )
        .await?;

        self.log_transaction_operation(&tx, &reverse_in_model, None, "TRANSFER_REVERSE_IN_CREATE")
            .await?;

        // 提交事务
        tx.commit().await?;

        Ok((reverse_out_model, reverse_in_model))
    }

    /// 记录账户更新日志
    async fn log_account_update(
        &self,
        tx: &DatabaseTransaction,
        updated_model: &entity::account::Model,
        original_model: &entity::account::Model,
        operation_type: &str,
    ) -> MijiResult<()> {
        let table_name = "accounts";
        let record_id = updated_model.serial_num.clone();

        // 序列化数据
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

    /// 记录交易操作日志
    async fn log_transaction_operation(
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

    /// 序列化模型为 JSON
    fn serialize_model(
        &self,
        model: &entity::transactions::Model,
    ) -> MijiResult<serde_json::Value> {
        serde_json::to_value(model)
            .map_err(|e| AppError::internal_server_error(format!("Serialization failed: {e}")))
    }
}

// 实现 Deref 以便可以直接访问底层服务的 CRUD 方法
impl std::ops::Deref for TransactionServiceImpl {
    type Target = GenericCrudService<
        entity::transactions::Entity,
        TransactionFilter,
        CreateTransactionRequest,
        UpdateTransactionRequest,
        TransactionConverter,
        NoOpHooks,
    >;

    fn deref(&self) -> &Self::Target {
        &self.service
    }
}

pub fn get_transaction_service() -> TransactionServiceImpl {
    TransactionServiceImpl::new(
        TransactionConverter,
        NoOpHooks,
        Arc::new(common::log::logger::NoopLogger),
    )
}
