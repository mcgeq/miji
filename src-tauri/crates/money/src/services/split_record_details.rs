use common::{
    BusinessCode,
    crud::service::{CrudConverter, CrudService, GenericCrudService},
    error::{AppError, MijiResult},
    paginations::{Filter, PagedQuery, PagedResult},
    utils::date::DateUtils,
};
use sea_orm::{
    ActiveModelTrait,
    ActiveValue::Set,
    ColumnTrait, Condition, DbConn, EntityTrait, QueryFilter, TransactionTrait,
    prelude::async_trait::async_trait,
};
use std::sync::Arc;
use tracing::info;
use validator::Validate;

use crate::dto::split_record_details::{
    SplitRecordDetailCreate, SplitRecordDetailResponse, SplitRecordDetailUpdate,
    SplitRecordStatistics, SplitRecordWithDetails, SplitRecordWithDetailsCreate,
    SplitRecordWithDetailsQuery,
};

// ==================== Filter ====================

impl Filter<entity::split_record_details::Entity> for SplitRecordWithDetailsQuery {
    fn to_condition(&self) -> Condition {
        let mut condition = Condition::all();

        if let Some(ref _split_record_serial_num) = self.family_ledger_serial_num {
            // 通过split_records表的family_ledger_serial_num查询
            // 这里需要join操作，暂时简单实现
            // TODO: 实现join查询
        }

        if let Some(ref member_serial_num) = self.member_serial_num {
            condition = condition.add(
                entity::split_record_details::Column::MemberSerialNum.eq(member_serial_num),
            );
        }

        condition
    }
}

// ==================== Converter ====================

#[derive(Debug)]
pub struct SplitRecordDetailConverter;

impl CrudConverter<
    entity::split_record_details::Entity,
    SplitRecordDetailCreate,
    SplitRecordDetailUpdate,
> for SplitRecordDetailConverter
{
    fn create_to_active_model(
        &self,
        _data: SplitRecordDetailCreate,
    ) -> MijiResult<entity::split_record_details::ActiveModel> {
        // 注意：这里需要split_record_serial_num，所以这个方法不会直接使用
        // 实际创建会在Service的自定义方法中处理
        Err(AppError::simple(
            BusinessCode::InvalidParameter,
            "Use create_with_split_record_serial_num instead",
        ))
    }

    fn update_to_active_model(
        &self,
        model: entity::split_record_details::Model,
        data: SplitRecordDetailUpdate,
    ) -> MijiResult<entity::split_record_details::ActiveModel> {
        let mut active_model = entity::split_record_details::ActiveModel {
            serial_num: Set(model.serial_num),
            split_record_serial_num: Set(model.split_record_serial_num),
            member_serial_num: Set(model.member_serial_num),
            amount: Set(model.amount),
            percentage: Set(model.percentage),
            weight: Set(model.weight),
            is_paid: Set(model.is_paid),
            paid_at: Set(model.paid_at),
            created_at: Set(model.created_at),
            updated_at: Set(None),
        };

        data.apply_to_model(&mut active_model);
        Ok(active_model)
    }

    fn primary_key_to_string(&self, model: &entity::split_record_details::Model) -> String {
        model.serial_num.clone()
    }

    fn table_name(&self) -> &'static str {
        "split_record_details"
    }
}

impl SplitRecordDetailConverter {
    /// 将Model转换为Response，并填充成员名称
    pub async fn model_to_response(
        &self,
        db: &DbConn,
        model: entity::split_record_details::Model,
    ) -> MijiResult<SplitRecordDetailResponse> {
        let mut response = SplitRecordDetailResponse::from(model.clone());

        // 查询成员名称
        if let Ok(Some(member)) = entity::family_member::Entity::find()
            .filter(entity::family_member::Column::SerialNum.eq(&model.member_serial_num))
            .one(db)
            .await
        {
            response.member_name = Some(member.name);
        }

        Ok(response)
    }
}

// ==================== Hooks ====================

#[derive(Debug)]
pub struct SplitRecordDetailHooks;

#[async_trait]
impl common::crud::hooks::Hooks<entity::split_record_details::Entity, SplitRecordDetailCreate, SplitRecordDetailUpdate>
    for SplitRecordDetailHooks
{
    async fn before_create(&self, _tx: &sea_orm::DatabaseTransaction, _data: &SplitRecordDetailCreate) -> MijiResult<()> {
        Ok(())
    }
    async fn after_create(&self, _tx: &sea_orm::DatabaseTransaction, _model: &entity::split_record_details::Model) -> MijiResult<()> {
        Ok(())
    }
    async fn before_update(
        &self,
        _tx: &sea_orm::DatabaseTransaction,
        _model: &entity::split_record_details::Model,
        _data: &SplitRecordDetailUpdate,
    ) -> MijiResult<()> {
        Ok(())
    }
    async fn after_update(&self, _tx: &sea_orm::DatabaseTransaction, _model: &entity::split_record_details::Model) -> MijiResult<()> {
        Ok(())
    }
    async fn before_delete(&self, _tx: &sea_orm::DatabaseTransaction, _model: &entity::split_record_details::Model) -> MijiResult<()> {
        Ok(())
    }
    async fn after_delete(&self, _tx: &sea_orm::DatabaseTransaction, _model: &entity::split_record_details::Model) -> MijiResult<()> {
        Ok(())
    }
}

// ==================== Service ====================

pub struct SplitRecordDetailService {
    inner: GenericCrudService<
        entity::split_record_details::Entity,
        SplitRecordWithDetailsQuery,
        SplitRecordDetailCreate,
        SplitRecordDetailUpdate,
        SplitRecordDetailConverter,
        SplitRecordDetailHooks,
    >,
}

impl Default for SplitRecordDetailService {
    fn default() -> Self {
        Self::new(
            SplitRecordDetailConverter,
            SplitRecordDetailHooks,
            Arc::new(common::log::logger::NoopLogger),
        )
    }
}

impl SplitRecordDetailService {
    pub fn new(
        converter: SplitRecordDetailConverter,
        hooks: SplitRecordDetailHooks,
        logger: Arc<dyn common::log::logger::OperationLogger>,
    ) -> Self {
        Self {
            inner: GenericCrudService::new(converter, hooks, logger),
        }
    }

    /// 创建完整的分摊记录（主记录 + 明细）
    pub async fn create_split_record_with_details(
        &self,
        db: &DbConn,
        data: SplitRecordWithDetailsCreate,
    ) -> MijiResult<SplitRecordWithDetails> {
        // 验证数据
        data.validate().map_err(AppError::from_validation_errors)?;
        
        // 验证分摊逻辑
        data.validate_split_logic()
            .map_err(|e| AppError::simple(BusinessCode::ValidationError, e))?;

        // 开始事务
        let txn = db.begin().await?;

        // 1. 创建主记录（使用现有的split_records表的payer/owe模式）
        // 这里我们创建一个主记录来标识这次分摊
        let main_record_serial_num = common::utils::uuid::McgUuid::uuid(38);
        let now = DateUtils::local_now();

        // 注意：由于原有的split_records表是payer/owe模式，
        // 我们需要决定如何存储主记录
        // 方案：主记录的payer是付款人，owe是第一个成员（作为标识）
        let first_member = data
            .details
            .first()
            .ok_or_else(|| AppError::simple(BusinessCode::InvalidParameter, "分摊明细不能为空"))?;

        let main_record = entity::split_records::ActiveModel {
            serial_num: Set(main_record_serial_num.clone()),
            transaction_serial_num: Set(data.transaction_serial_num.clone()),
            family_ledger_serial_num: Set(data.family_ledger_serial_num.clone()),
            split_rule_serial_num: Set(None),
            payer_member_serial_num: Set(data.payer_member_serial_num.clone().unwrap_or_default()),
            owe_member_serial_num: Set(first_member.member_serial_num.clone()),
            total_amount: Set(data.total_amount),
            split_amount: Set(first_member.amount),
            split_percentage: Set(first_member.percentage),
            currency: Set(data.currency.clone()),
            status: Set("Pending".to_string()),
            split_type: Set(data.rule_type.clone()),
            description: Set(None),
            notes: Set(None),
            confirmed_at: Set(None),
            paid_at: Set(None),
            due_date: Set(None),
            reminder_sent: Set(false),
            last_reminder_at: Set(None),
            created_at: Set(now),
            updated_at: Set(None),
        };

        let saved_main_record = main_record.insert(&txn).await?;

        // 2. 创建所有明细记录
        let mut detail_responses = Vec::new();
        for detail in data.details {
            let active_model = detail.to_active_model(main_record_serial_num.clone());
            let saved_detail = active_model.insert(&txn).await?;
            
            let mut response = SplitRecordDetailResponse::from(saved_detail);
            response.member_name = Some(detail.member_name.clone());
            detail_responses.push(response);
        }

        // 提交事务
        txn.commit().await?;

        info!(
            "Created split record with {} details, serial_num: {}",
            detail_responses.len(),
            main_record_serial_num
        );

        // 3. 构建返回结果
        Ok(SplitRecordWithDetails {
            serial_num: saved_main_record.serial_num,
            transaction_serial_num: saved_main_record.transaction_serial_num,
            family_ledger_serial_num: saved_main_record.family_ledger_serial_num,
            rule_type: saved_main_record.split_type,
            total_amount: saved_main_record.total_amount,
            currency: saved_main_record.currency,
            payer_member_serial_num: Some(saved_main_record.payer_member_serial_num),
            payer_member_name: None, // 需要额外查询
            created_at: saved_main_record.created_at,
            updated_at: saved_main_record.updated_at,
            details: detail_responses,
        })
    }

    /// 获取分摊记录详情（包含所有明细）
    pub async fn get_split_record_with_details(
        &self,
        db: &DbConn,
        split_record_serial_num: String,
    ) -> MijiResult<SplitRecordWithDetails> {
        // 1. 查询主记录
        let main_record = entity::split_records::Entity::find()
            .filter(entity::split_records::Column::SerialNum.eq(&split_record_serial_num))
            .one(db)
            .await?
            .ok_or_else(|| AppError::simple(BusinessCode::NotFound, "分摊记录不存在"))?;

        // 2. 查询所有明细
        let details = entity::split_record_details::Entity::find()
            .filter(
                entity::split_record_details::Column::SplitRecordSerialNum
                    .eq(&split_record_serial_num),
            )
            .all(db)
            .await?;

        // 3. 转换为Response并填充成员名称
        let converter = SplitRecordDetailConverter;
        let mut detail_responses = Vec::new();
        for detail in details {
            let response = converter.model_to_response(db, detail).await?;
            detail_responses.push(response);
        }

        // 4. 查询付款人名称
        let payer_member_name = if !main_record.payer_member_serial_num.is_empty() {
            entity::family_member::Entity::find()
                .filter(
                    entity::family_member::Column::SerialNum
                        .eq(&main_record.payer_member_serial_num),
                )
                .one(db)
                .await?
                .map(|m| m.name)
        } else {
            None
        };

        Ok(SplitRecordWithDetails {
            serial_num: main_record.serial_num,
            transaction_serial_num: main_record.transaction_serial_num,
            family_ledger_serial_num: main_record.family_ledger_serial_num,
            rule_type: main_record.split_type,
            total_amount: main_record.total_amount,
            currency: main_record.currency,
            payer_member_serial_num: Some(main_record.payer_member_serial_num),
            payer_member_name,
            created_at: main_record.created_at,
            updated_at: main_record.updated_at,
            details: detail_responses,
        })
    }

    /// 更新明细支付状态
    pub async fn update_detail_payment_status(
        &self,
        db: &DbConn,
        detail_serial_num: String,
        is_paid: bool,
    ) -> MijiResult<SplitRecordDetailResponse> {
        let detail = entity::split_record_details::Entity::find()
            .filter(entity::split_record_details::Column::SerialNum.eq(&detail_serial_num))
            .one(db)
            .await?
            .ok_or_else(|| AppError::simple(BusinessCode::NotFound, "分摊明细不存在"))?;

        let update = SplitRecordDetailUpdate {
            is_paid: Some(is_paid),
            paid_at: if is_paid {
                Some(DateUtils::local_now())
            } else {
                None
            },
            ..Default::default()
        };

        // 直接使用 SeaORM 更新
        let converter = SplitRecordDetailConverter;
        let active_model = converter.update_to_active_model(detail.clone(), update)?;
        let updated_model = active_model.update(db).await?;
        
        converter.model_to_response(db, updated_model).await
    }

    /// 获取分摊统计信息
    pub async fn get_statistics(
        &self,
        db: &DbConn,
        split_record_serial_num: String,
    ) -> MijiResult<SplitRecordStatistics> {
        let details = entity::split_record_details::Entity::find()
            .filter(
                entity::split_record_details::Column::SplitRecordSerialNum
                    .eq(&split_record_serial_num),
            )
            .all(db)
            .await?;

        let detail_responses: Vec<SplitRecordDetailResponse> =
            details.into_iter().map(|d| d.into()).collect();

        Ok(SplitRecordStatistics::from_details(&detail_responses))
    }

    /// 查询成员的所有分摊记录
    pub async fn list_member_split_details(
        &self,
        db: &DbConn,
        member_serial_num: String,
        page: Option<u64>,
        page_size: Option<u64>,
    ) -> MijiResult<PagedResult<SplitRecordDetailResponse>> {
        let page = page.unwrap_or(1);
        let page_size = page_size.unwrap_or(20);

        let filter = SplitRecordWithDetailsQuery {
            member_serial_num: Some(member_serial_num),
            ..Default::default()
        };

        // 使用过滤器查询
        let condition = Filter::to_condition(&filter);
        let models = entity::split_record_details::Entity::find()
            .filter(condition)
            .all(db)
            .await?;

        // 转换为Response
        // 转换为响应
        let converter = SplitRecordDetailConverter;
        let mut responses = Vec::new();
        for model in models {
            let response = converter.model_to_response(db, model).await?;
            responses.push(response);
        }
        
        let total_count = responses.len();
        let total_pages = (total_count as f64 / page_size as f64).ceil() as usize;

        Ok(PagedResult {
            rows: responses,
            total_count,
            current_page: page as usize,
            page_size: page_size as usize,
            total_pages,
        })
    }
}

impl std::ops::Deref for SplitRecordDetailService {
    type Target = GenericCrudService<
        entity::split_record_details::Entity,
        SplitRecordWithDetailsQuery,
        SplitRecordDetailCreate,
        SplitRecordDetailUpdate,
        SplitRecordDetailConverter,
        SplitRecordDetailHooks,
    >;

    fn deref(&self) -> &Self::Target {
        &self.inner
    }
}

#[async_trait]
impl CrudService<
    entity::split_record_details::Entity,
    SplitRecordWithDetailsQuery,
    SplitRecordDetailCreate,
    SplitRecordDetailUpdate,
> for SplitRecordDetailService
{
    async fn create(
        &self,
        db: &DbConn,
        data: SplitRecordDetailCreate,
    ) -> MijiResult<entity::split_record_details::Model> {
        self.inner.create(db, data).await
    }

    async fn get_by_id(
        &self,
        db: &DbConn,
        id: String,
    ) -> MijiResult<entity::split_record_details::Model> {
        self.inner.get_by_id(db, id).await
    }

    async fn update(
        &self,
        db: &DbConn,
        id: String,
        data: SplitRecordDetailUpdate,
    ) -> MijiResult<entity::split_record_details::Model> {
        self.inner.update(db, id, data).await
    }

    async fn delete(&self, db: &DbConn, id: String) -> MijiResult<()> {
        self.inner.delete(db, id).await
    }

    async fn list(&self, db: &DbConn) -> MijiResult<Vec<entity::split_record_details::Model>> {
        self.inner.list(db).await
    }

    async fn list_with_filter(
        &self,
        db: &DbConn,
        filter: SplitRecordWithDetailsQuery,
    ) -> MijiResult<Vec<entity::split_record_details::Model>> {
        self.inner.list_with_filter(db, filter).await
    }

    async fn list_paged(
        &self,
        db: &DbConn,
        query: PagedQuery<SplitRecordWithDetailsQuery>,
    ) -> MijiResult<PagedResult<entity::split_record_details::Model>> {
        self.inner.list_paged(db, query).await
    }

    async fn create_batch(
        &self,
        db: &DbConn,
        data: Vec<SplitRecordDetailCreate>,
    ) -> MijiResult<Vec<entity::split_record_details::Model>> {
        self.inner.create_batch(db, data).await
    }

    async fn delete_batch(&self, db: &DbConn, ids: Vec<String>) -> MijiResult<u64> {
        self.inner.delete_batch(db, ids).await
    }

    async fn exists(&self, db: &DbConn, id: String) -> MijiResult<bool> {
        self.inner.exists(db, id).await
    }

    async fn count(&self, db: &DbConn) -> MijiResult<u64> {
        self.inner.count(db).await
    }

    async fn count_with_filter(
        &self,
        db: &DbConn,
        filter: SplitRecordWithDetailsQuery,
    ) -> MijiResult<u64> {
        self.inner.count_with_filter(db, filter).await
    }
}
