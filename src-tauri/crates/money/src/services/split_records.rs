use std::{collections::HashMap, sync::Arc};

use common::{
    crud::service::{CrudConverter, CrudService, GenericCrudService, LocalizableConverter},
    error::{AppError, MijiResult},
    paginations::{EmptyFilter, PagedQuery, PagedResult},
    utils::date::DateUtils,
};
use entity::localize::LocalizeModel;
use sea_orm::{
    ActiveValue, ColumnTrait, DbConn, EntityTrait, QueryFilter, QueryOrder, QuerySelect,
    prelude::async_trait::async_trait, Condition, Order, JoinType, RelationTrait,
};
use sea_orm::prelude::Decimal;
use chrono::NaiveDate;

use crate::{
    dto::split_records::{
        SplitRecordCreate, SplitRecordUpdate, SplitRecordResponse, SplitRecordQuery,
        SplitRecordConfirm, SplitRecordPayment, SplitRecordStats, MemberSplitSummary
    },
    services::split_records_hooks::SplitRecordsHooks,
};

pub type SplitRecordsFilter = EmptyFilter;

#[derive(Debug)]
pub struct SplitRecordsConverter;

impl CrudConverter<entity::split_records::Entity, SplitRecordCreate, SplitRecordUpdate>
    for SplitRecordsConverter
{
    fn create_to_active_model(
        &self,
        data: SplitRecordCreate,
    ) -> MijiResult<entity::split_records::ActiveModel> {
        entity::split_records::ActiveModel::try_from(data)
            .map_err(AppError::from_validation_errors)
    }

    fn update_to_active_model(
        &self,
        model: entity::split_records::Model,
        data: SplitRecordUpdate,
    ) -> MijiResult<entity::split_records::ActiveModel> {
        let mut active_model = entity::split_records::ActiveModel {
            serial_num: ActiveValue::Set(model.serial_num.clone()),
            transaction_serial_num: ActiveValue::Set(model.transaction_serial_num.clone()),
            family_ledger_serial_num: ActiveValue::Set(model.family_ledger_serial_num.clone()),
            payer_member_serial_num: ActiveValue::Set(model.payer_member_serial_num.clone()),
            owe_member_serial_num: ActiveValue::Set(model.owe_member_serial_num.clone()),
            created_at: ActiveValue::Set(model.created_at),
            ..Default::default()
        };
        
        data.apply_to_model(&mut active_model);
        Ok(active_model)
    }

    fn primary_key_to_string(&self, model: &entity::split_records::Model) -> String {
        model.serial_num.clone()
    }
}

impl LocalizableConverter<entity::split_records::Entity> for SplitRecordsConverter {
    fn localize_model(
        &self,
        model: entity::split_records::Model,
        _locale: &str,
    ) -> MijiResult<entity::split_records::Model> {
        Ok(model.localize(_locale))
    }
}

pub type SplitRecordsService = GenericCrudService<
    entity::split_records::Entity,
    SplitRecordCreate,
    SplitRecordUpdate,
    SplitRecordsFilter,
    SplitRecordsConverter,
    SplitRecordsHooks,
>;

impl SplitRecordsService {
    pub fn new() -> Self {
        Self::with_converter_and_hooks(SplitRecordsConverter, SplitRecordsHooks)
    }

    /// 根据查询条件获取分摊记录
    pub async fn find_with_query(
        &self,
        db: &DbConn,
        query: SplitRecordQuery,
    ) -> MijiResult<PagedResult<SplitRecordResponse>> {
        let mut select = entity::split_records::Entity::find();

        // 应用查询条件
        if let Some(family_ledger_serial_num) = &query.family_ledger_serial_num {
            select = select.filter(
                entity::split_records::Column::FamilyLedgerSerialNum.eq(family_ledger_serial_num)
            );
        }
        
        if let Some(transaction_serial_num) = &query.transaction_serial_num {
            select = select.filter(
                entity::split_records::Column::TransactionSerialNum.eq(transaction_serial_num)
            );
        }
        
        if let Some(payer_member_serial_num) = &query.payer_member_serial_num {
            select = select.filter(
                entity::split_records::Column::PayerMemberSerialNum.eq(payer_member_serial_num)
            );
        }
        
        if let Some(owe_member_serial_num) = &query.owe_member_serial_num {
            select = select.filter(
                entity::split_records::Column::OweMemberSerialNum.eq(owe_member_serial_num)
            );
        }
        
        if let Some(status) = &query.status {
            select = select.filter(entity::split_records::Column::Status.eq(status));
        }
        
        if let Some(split_type) = &query.split_type {
            select = select.filter(entity::split_records::Column::SplitType.eq(split_type));
        }
        
        if let Some(start_date) = query.start_date {
            select = select.filter(entity::split_records::Column::CreatedAt.gte(start_date));
        }
        
        if let Some(end_date) = query.end_date {
            select = select.filter(entity::split_records::Column::CreatedAt.lte(end_date));
        }

        // 排序：创建时间降序
        select = select.order_by(entity::split_records::Column::CreatedAt, Order::Desc);

        let page = query.page.unwrap_or(1);
        let page_size = query.page_size.unwrap_or(20);
        
        let paginated_query = PagedQuery::new(page, page_size);
        let result = self.find_paged(db, select, paginated_query).await?;
        
        let responses: Vec<SplitRecordResponse> = result.data
            .into_iter()
            .map(SplitRecordResponse::from)
            .collect();
            
        Ok(PagedResult {
            data: responses,
            total: result.total,
            page: result.page,
            page_size: result.page_size,
            total_pages: result.total_pages,
        })
    }

    /// 根据交易ID获取分摊记录
    pub async fn find_by_transaction(
        &self,
        db: &DbConn,
        transaction_serial_num: &str,
    ) -> MijiResult<Vec<SplitRecordResponse>> {
        let records = entity::split_records::Entity::find()
            .filter(entity::split_records::Column::TransactionSerialNum.eq(transaction_serial_num))
            .order_by(entity::split_records::Column::CreatedAt, Order::Asc)
            .all(db)
            .await
            .map_err(AppError::from_db_error)?;

        Ok(records.into_iter().map(SplitRecordResponse::from).collect())
    }

    /// 确认分摊记录
    pub async fn confirm_records(
        &self,
        db: &DbConn,
        confirm_request: SplitRecordConfirm,
    ) -> MijiResult<Vec<SplitRecordResponse>> {
        let now = DateUtils::local_now();
        
        // 批量更新状态
        entity::split_records::Entity::update_many()
            .col_expr(
                entity::split_records::Column::Status,
                sea_orm::sea_query::Expr::value("Confirmed")
            )
            .col_expr(
                entity::split_records::Column::ConfirmedAt,
                sea_orm::sea_query::Expr::value(now)
            )
            .col_expr(
                entity::split_records::Column::UpdatedAt,
                sea_orm::sea_query::Expr::value(Some(now))
            )
            .filter(entity::split_records::Column::SerialNum.is_in(&confirm_request.serial_nums))
            .exec(db)
            .await
            .map_err(AppError::from_db_error)?;

        // 如果有备注，更新备注
        if let Some(notes) = confirm_request.notes {
            entity::split_records::Entity::update_many()
                .col_expr(
                    entity::split_records::Column::Notes,
                    sea_orm::sea_query::Expr::value(Some(notes))
                )
                .filter(entity::split_records::Column::SerialNum.is_in(&confirm_request.serial_nums))
                .exec(db)
                .await
                .map_err(AppError::from_db_error)?;
        }

        // 返回更新后的记录
        let updated_records = entity::split_records::Entity::find()
            .filter(entity::split_records::Column::SerialNum.is_in(&confirm_request.serial_nums))
            .all(db)
            .await
            .map_err(AppError::from_db_error)?;

        Ok(updated_records.into_iter().map(SplitRecordResponse::from).collect())
    }

    /// 支付分摊记录
    pub async fn pay_records(
        &self,
        db: &DbConn,
        payment_request: SplitRecordPayment,
    ) -> MijiResult<Vec<SplitRecordResponse>> {
        let now = DateUtils::local_now();
        
        // 批量更新状态
        entity::split_records::Entity::update_many()
            .col_expr(
                entity::split_records::Column::Status,
                sea_orm::sea_query::Expr::value("Paid")
            )
            .col_expr(
                entity::split_records::Column::PaidAt,
                sea_orm::sea_query::Expr::value(now)
            )
            .col_expr(
                entity::split_records::Column::UpdatedAt,
                sea_orm::sea_query::Expr::value(Some(now))
            )
            .filter(entity::split_records::Column::SerialNum.is_in(&payment_request.serial_nums))
            .exec(db)
            .await
            .map_err(AppError::from_db_error)?;

        // 如果有备注，更新备注
        if let Some(notes) = payment_request.notes {
            entity::split_records::Entity::update_many()
                .col_expr(
                    entity::split_records::Column::Notes,
                    sea_orm::sea_query::Expr::value(Some(notes))
                )
                .filter(entity::split_records::Column::SerialNum.is_in(&payment_request.serial_nums))
                .exec(db)
                .await
                .map_err(AppError::from_db_error)?;
        }

        // 返回更新后的记录
        let updated_records = entity::split_records::Entity::find()
            .filter(entity::split_records::Column::SerialNum.is_in(&payment_request.serial_nums))
            .all(db)
            .await
            .map_err(AppError::from_db_error)?;

        Ok(updated_records.into_iter().map(SplitRecordResponse::from).collect())
    }

    /// 获取分摊统计
    pub async fn get_statistics(
        &self,
        db: &DbConn,
        family_ledger_serial_num: &str,
        start_date: Option<NaiveDate>,
        end_date: Option<NaiveDate>,
    ) -> MijiResult<SplitRecordStats> {
        let mut condition = Condition::all()
            .add(entity::split_records::Column::FamilyLedgerSerialNum.eq(family_ledger_serial_num));

        if let Some(start) = start_date {
            condition = condition.add(entity::split_records::Column::CreatedAt.gte(start));
        }
        
        if let Some(end) = end_date {
            condition = condition.add(entity::split_records::Column::CreatedAt.lte(end));
        }

        let records = entity::split_records::Entity::find()
            .filter(condition)
            .all(db)
            .await
            .map_err(AppError::from_db_error)?;

        let total_records = records.len() as i64;
        let pending_records = records.iter().filter(|r| r.status == "Pending").count() as i64;
        let confirmed_records = records.iter().filter(|r| r.status == "Confirmed").count() as i64;
        let paid_records = records.iter().filter(|r| r.status == "Paid").count() as i64;

        let total_amount: Decimal = records.iter().map(|r| r.split_amount).sum();
        let pending_amount: Decimal = records.iter()
            .filter(|r| r.status == "Pending")
            .map(|r| r.split_amount)
            .sum();
        let paid_amount: Decimal = records.iter()
            .filter(|r| r.status == "Paid")
            .map(|r| r.split_amount)
            .sum();

        Ok(SplitRecordStats {
            total_records,
            pending_records,
            confirmed_records,
            paid_records,
            total_amount,
            pending_amount,
            paid_amount,
        })
    }

    /// 获取成员分摊汇总
    pub async fn get_member_summary(
        &self,
        db: &DbConn,
        family_ledger_serial_num: &str,
        member_serial_num: &str,
        start_date: Option<NaiveDate>,
        end_date: Option<NaiveDate>,
    ) -> MijiResult<MemberSplitSummary> {
        let mut condition = Condition::all()
            .add(entity::split_records::Column::FamilyLedgerSerialNum.eq(family_ledger_serial_num));

        if let Some(start) = start_date {
            condition = condition.add(entity::split_records::Column::CreatedAt.gte(start));
        }
        
        if let Some(end) = end_date {
            condition = condition.add(entity::split_records::Column::CreatedAt.lte(end));
        }

        // 获取作为付款人的记录
        let paid_records = entity::split_records::Entity::find()
            .filter(
                condition.clone()
                    .add(entity::split_records::Column::PayerMemberSerialNum.eq(member_serial_num))
            )
            .all(db)
            .await
            .map_err(AppError::from_db_error)?;

        // 获取作为欠款人的记录
        let owed_records = entity::split_records::Entity::find()
            .filter(
                condition
                    .add(entity::split_records::Column::OweMemberSerialNum.eq(member_serial_num))
            )
            .all(db)
            .await
            .map_err(AppError::from_db_error)?;

        let total_paid: Decimal = paid_records.iter().map(|r| r.split_amount).sum();
        let total_owed: Decimal = owed_records.iter().map(|r| r.split_amount).sum();
        let net_balance = total_paid - total_owed;
        let pending_amount: Decimal = owed_records.iter()
            .filter(|r| r.status == "Pending")
            .map(|r| r.split_amount)
            .sum();

        // 获取成员名称
        let member = entity::family_member::Entity::find_by_id(member_serial_num)
            .one(db)
            .await
            .map_err(AppError::from_db_error)?
            .ok_or_else(|| AppError::not_found("成员不存在"))?;

        Ok(MemberSplitSummary {
            member_serial_num: member_serial_num.to_string(),
            member_name: member.name,
            total_paid,
            total_owed,
            net_balance,
            pending_amount,
        })
    }

    /// 发送提醒
    pub async fn send_reminders(
        &self,
        db: &DbConn,
        family_ledger_serial_num: &str,
    ) -> MijiResult<i64> {
        let now = DateUtils::local_now();
        let today = now.date_naive();
        
        // 查找需要提醒的记录（状态为Confirmed且到期日期已到或即将到期）
        let records_to_remind = entity::split_records::Entity::find()
            .filter(
                Condition::all()
                    .add(entity::split_records::Column::FamilyLedgerSerialNum.eq(family_ledger_serial_num))
                    .add(entity::split_records::Column::Status.eq("Confirmed"))
                    .add(entity::split_records::Column::ReminderSent.eq(false))
                    .add(entity::split_records::Column::DueDate.lte(today))
            )
            .all(db)
            .await
            .map_err(AppError::from_db_error)?;

        let count = records_to_remind.len() as i64;

        if count > 0 {
            let serial_nums: Vec<String> = records_to_remind
                .iter()
                .map(|r| r.serial_num.clone())
                .collect();

            // 更新提醒状态
            entity::split_records::Entity::update_many()
                .col_expr(
                    entity::split_records::Column::ReminderSent,
                    sea_orm::sea_query::Expr::value(true)
                )
                .col_expr(
                    entity::split_records::Column::LastReminderAt,
                    sea_orm::sea_query::Expr::value(now)
                )
                .filter(entity::split_records::Column::SerialNum.is_in(serial_nums))
                .exec(db)
                .await
                .map_err(AppError::from_db_error)?;

            // TODO: 这里可以集成实际的提醒发送逻辑（邮件、短信、推送等）
        }

        Ok(count)
    }
}
