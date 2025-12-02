use std::{collections::HashMap, sync::Arc};

use common::{
    crud::service::{CrudConverter, CrudService, GenericCrudService, LocalizableConverter},
    error::{AppError, MijiResult},
    paginations::{EmptyFilter, PagedQuery, PagedResult},
    utils::date::DateUtils,
};
use entity::localize::LocalizeModel;
use sea_orm::{
    ActiveValue, ColumnTrait, DbConn, EntityTrait, QueryFilter, prelude::async_trait::async_trait,
};

use crate::{
    dto::family_member::{FamilyMemberCreate, FamilyMemberUpdate, FamilyMemberSearchQuery},
    services::family_member_hooks::FamilyMemberHooks,
};

pub type FamilyMemberFilter = EmptyFilter;

#[derive(Debug)]
pub struct FamilyMemberConverter;

impl CrudConverter<entity::family_member::Entity, FamilyMemberCreate, FamilyMemberUpdate>
    for FamilyMemberConverter
{
    fn create_to_active_model(
        &self,
        data: FamilyMemberCreate,
    ) -> MijiResult<entity::family_member::ActiveModel> {
        entity::family_member::ActiveModel::try_from(data).map_err(AppError::from_validation_errors)
    }

    fn update_to_active_model(
        &self,
        model: entity::family_member::Model,
        data: FamilyMemberUpdate,
    ) -> MijiResult<entity::family_member::ActiveModel> {
        entity::family_member::ActiveModel::try_from(data)
            .map(|mut active_model| {
                active_model.name = ActiveValue::Set(model.name.clone());
                active_model.created_at = ActiveValue::Set(model.created_at);
                active_model.updated_at = ActiveValue::Set(Some(DateUtils::local_now()));
                active_model
            })
            .map_err(AppError::from_validation_errors)
    }

    fn primary_key_to_string(&self, model: &entity::family_member::Model) -> String {
        model.name.clone()
    }

    fn table_name(&self) -> &'static str {
        "family_member"
    }
}

#[async_trait]
impl LocalizableConverter<entity::family_member::Model> for FamilyMemberConverter {
    async fn model_with_local(
        &self,
        model: entity::family_member::Model,
    ) -> MijiResult<entity::family_member::Model> {
        Ok(model.to_local())
    }
}

pub struct FamilyMemberService {
    inner: GenericCrudService<
        entity::family_member::Entity,
        FamilyMemberFilter,
        FamilyMemberCreate,
        FamilyMemberUpdate,
        FamilyMemberConverter,
        FamilyMemberHooks,
    >,
}

impl Default for FamilyMemberService {
    fn default() -> Self {
        Self::new(
            FamilyMemberConverter,
            FamilyMemberHooks,
            Arc::new(common::log::logger::NoopLogger),
        )
    }
}

impl FamilyMemberService {
    pub fn new(
        converter: FamilyMemberConverter,
        hooks: FamilyMemberHooks,
        logger: Arc<dyn common::log::logger::OperationLogger>,
    ) -> Self {
        Self {
            inner: GenericCrudService::new(converter, hooks, logger),
        }
    }
}

impl std::ops::Deref for FamilyMemberService {
    type Target = GenericCrudService<
        entity::family_member::Entity,
        FamilyMemberFilter,
        FamilyMemberCreate,
        FamilyMemberUpdate,
        FamilyMemberConverter,
        FamilyMemberHooks,
    >;

    fn deref(&self) -> &Self::Target {
        &self.inner
    }
}

impl FamilyMemberService {
    pub async fn family_member_get(
        &self,
        db: &DbConn,
        serial_num: String,
    ) -> MijiResult<entity::family_member::Model> {
        let model = self.get_by_id(db, serial_num).await?;
        self.converter().model_with_local(model).await
    }

    pub async fn family_member_create(
        &self,
        db: &DbConn,
        data: FamilyMemberCreate,
    ) -> MijiResult<entity::family_member::Model> {
        let model = self.create(db, data).await?;
        self.converter().model_with_local(model).await
    }

    pub async fn family_member_update(
        &self,
        db: &DbConn,
        serial_num: String,
        data: FamilyMemberUpdate,
    ) -> MijiResult<entity::family_member::Model> {
        let model = self.update(db, serial_num, data).await?;
        self.converter().model_with_local(model).await
    }

    pub async fn family_member_delete(&self, db: &DbConn, id: String) -> MijiResult<()> {
        self.delete(db, id).await
    }

    pub async fn family_member_list_paged(
        &self,
        db: &DbConn,
        query: PagedQuery<FamilyMemberFilter>,
    ) -> MijiResult<PagedResult<entity::family_member::Model>> {
        self.list_paged(db, query)
            .await?
            .map_async(|rows| self.converter().localize_models(rows))
            .await
    }

    pub async fn family_member_list(
        &self,
        db: &DbConn,
    ) -> MijiResult<Vec<entity::family_member::Model>> {
        let models = self.list(db).await?;
        // 对每个 Model 调用 model_with_local
        let mut local_models = Vec::with_capacity(models.len());
        for model in models {
            local_models.push(self.converter().model_with_local(model).await?);
        }
        Ok(local_models)
    }

    pub async fn family_member_batch_get(
        &self,
        db: &DbConn,
        ids: &[String],
    ) -> MijiResult<HashMap<String, entity::family_member::Model>> {
        if ids.is_empty() {
            return Ok(HashMap::new());
        }
        const CHUNK_SIZE: usize = 1000;
        let mut result = HashMap::new();
        for chunk in ids.chunks(CHUNK_SIZE) {
            let owners = entity::family_member::Entity::find()
                .filter(entity::family_member::Column::SerialNum.is_in(chunk))
                .all(db)
                .await
                .map_err(AppError::from)?;
            result.extend(
                owners
                    .into_iter()
                    .map(|owner| (owner.serial_num.clone(), owner.to_local())),
            );
        }
        Ok(result)
    }

    /// 搜索家庭成员
    pub async fn search_family_members(
        &self,
        db: &DbConn,
        query: FamilyMemberSearchQuery,
        limit: Option<u32>,
    ) -> MijiResult<Vec<entity::family_member::Model>> {
        use entity::family_member::Entity as FamilyMemberEntity;
        use sea_orm::{QueryOrder, QuerySelect, Condition};
        
        let mut conditions = Condition::all();
        
        // 添加基础过滤条件 - 排除已删除成员（如果有deleted_at字段）
        // 这里假设status字段来标识活跃状态
        
        // 关键词搜索 - 支持姓名或邮箱模糊匹配
        if let Some(keyword) = &query.keyword {
            if !keyword.trim().is_empty() {
                let keyword_condition = Condition::any()
                    .add(entity::family_member::Column::Name.contains(keyword.trim()));
                
                // 如果有邮箱字段，也加入搜索
                if let Some(_) = &query.email {
                    conditions = conditions.add(
                        keyword_condition.add(
                            entity::family_member::Column::Email.contains(keyword.trim())
                        )
                    );
                } else {
                    conditions = conditions.add(keyword_condition);
                }
            }
        }
        
        // 精确姓名搜索
        if let Some(name) = &query.name {
            if !name.trim().is_empty() {
                conditions = conditions.add(entity::family_member::Column::Name.contains(name.trim()));
            }
        }
        
        // 精确邮箱搜索
        if let Some(email) = &query.email {
            if !email.trim().is_empty() {
                conditions = conditions.add(entity::family_member::Column::Email.contains(email.trim()));
            }
        }
        
        // 状态过滤
        if let Some(status) = &query.status {
            conditions = conditions.add(entity::family_member::Column::Status.eq(status));
        }
        
        // 角色过滤
        if let Some(role) = &query.role {
            conditions = conditions.add(entity::family_member::Column::Role.eq(role));
        }
        
        // 用户ID过滤
        if let Some(user_id) = &query.user_id {
            conditions = conditions.add(entity::family_member::Column::UserId.eq(user_id));
        }
        
        let mut query_builder = FamilyMemberEntity::find()
            .filter(conditions)
            .order_by_desc(entity::family_member::Column::CreatedAt);
            
        // 应用限制
        if let Some(limit) = limit {
            query_builder = query_builder.limit(limit as u64);
        }
        
        let models = query_builder
            .all(db)
            .await
            .map_err(AppError::from)?;
            
        // 应用本地化
        let mut local_models = Vec::with_capacity(models.len());
        for model in models {
            local_models.push(self.converter().model_with_local(model).await?);
        }
        
        Ok(local_models)
    }

    /// 获取最近创建的家庭成员
    pub async fn list_recent_family_members(
        &self,
        db: &DbConn,
        limit: Option<u32>,
        days_back: Option<u32>,
    ) -> MijiResult<Vec<entity::family_member::Model>> {
        use entity::family_member::Entity as FamilyMemberEntity;
        use sea_orm::{QueryOrder, QuerySelect};
        use chrono::{Duration, Utc};
        
        let limit = limit.unwrap_or(10);
        let days = days_back.unwrap_or(30);
        
        // 计算日期范围
        let cutoff_date = Utc::now() - Duration::days(days as i64);
        
        let models = FamilyMemberEntity::find()
            .filter(entity::family_member::Column::CreatedAt.gte(cutoff_date.with_timezone(&chrono::FixedOffset::east_opt(8 * 3600).unwrap())))
            .order_by_desc(entity::family_member::Column::CreatedAt)
            .limit(limit as u64)
            .all(db)
            .await
            .map_err(AppError::from)?;
            
        // 应用本地化
        let mut local_models = Vec::with_capacity(models.len());
        for model in models {
            local_models.push(self.converter().model_with_local(model).await?);
        }
        
        Ok(local_models)
    }
}
