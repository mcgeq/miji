use std::sync::Arc;

use common::{
    crud::service::{CrudConverter, CrudService, GenericCrudService, LocalizableConverter},
    error::{AppError, MijiResult},
    paginations::{EmptyFilter, PagedQuery, PagedResult},
    utils::date::DateUtils,
};
use entity::localize::LocalizeModel;
use sea_orm::{ActiveValue, DbConn, EntityTrait, prelude::async_trait::async_trait};

use crate::{
    dto::tags::{TagCreate, TagUpdate},
    service::tags_hooks::TagsHooks,
};

pub type TagsFilter = EmptyFilter;

#[derive(Debug)]
pub struct TagsConverter;

impl CrudConverter<entity::tag::Entity, TagCreate, TagUpdate> for TagsConverter {
    fn create_to_active_model(&self, data: TagCreate) -> MijiResult<entity::tag::ActiveModel> {
        entity::tag::ActiveModel::try_from(data).map_err(AppError::from_validation_errors)
    }

    fn update_to_active_model(
        &self,
        model: entity::tag::Model,
        data: TagUpdate,
    ) -> MijiResult<entity::tag::ActiveModel> {
        entity::tag::ActiveModel::try_from(data)
            .map(|mut active_model| {
                active_model.serial_num = ActiveValue::Set(model.serial_num.clone());
                active_model.created_at = ActiveValue::Set(model.created_at);
                active_model.updated_at = ActiveValue::Set(Some(DateUtils::local_now()));
                active_model
            })
            .map_err(AppError::from_validation_errors)
    }

    fn primary_key_to_string(&self, model: &entity::tag::Model) -> String {
        model.serial_num.clone()
    }

    fn table_name(&self) -> &'static str {
        "tag"
    }
}

#[async_trait]
impl LocalizableConverter<entity::tag::Model> for TagsConverter {
    async fn model_with_local(&self, model: entity::tag::Model) -> MijiResult<entity::tag::Model> {
        Ok(model.to_local())
    }
}

// 标签服务实现
pub struct TagsService {
    inner: GenericCrudService<
        entity::tag::Entity,
        TagsFilter,
        TagCreate,
        TagUpdate,
        TagsConverter,
        TagsHooks,
    >,
}

impl Default for TagsService {
    fn default() -> Self {
        Self::new(
            TagsConverter,
            TagsHooks,
            Arc::new(common::log::logger::NoopLogger),
        )
    }
}

impl TagsService {
    pub fn new(
        converter: TagsConverter,
        hooks: TagsHooks,
        logger: Arc<dyn common::log::logger::OperationLogger>,
    ) -> Self {
        Self {
            inner: GenericCrudService::new(converter, hooks, logger),
        }
    }
}

impl std::ops::Deref for TagsService {
    type Target = GenericCrudService<
        entity::tag::Entity,
        TagsFilter,
        TagCreate,
        TagUpdate,
        TagsConverter,
        TagsHooks,
    >;

    fn deref(&self) -> &Self::Target {
        &self.inner
    }
}

impl TagsService {
    pub async fn tag_get(&self, db: &DbConn, serial_num: String) -> MijiResult<entity::tag::Model> {
        let opt_model = if serial_num.is_empty() {
            entity::tag::Entity::find().one(db).await?
        } else {
            Some(self.get_by_id(db, serial_num).await?)
        };
        let model = opt_model.ok_or_else(|| {
            AppError::simple(common::BusinessCode::NotFound, "tag notfound".to_string())
        })?;
        self.converter().model_with_local(model).await
    }

    pub async fn tag_create(&self, db: &DbConn, data: TagCreate) -> MijiResult<entity::tag::Model> {
        let model = self.create(db, data).await?;
        self.converter().model_with_local(model).await
    }

    pub async fn tag_update(
        &self,
        db: &DbConn,
        serial_num: String,
        data: TagUpdate,
    ) -> MijiResult<entity::tag::Model> {
        let model = self.update(db, serial_num, data).await?;
        self.converter().model_with_local(model).await
    }

    pub async fn tag_delete(&self, db: &DbConn, serial_num: String) -> MijiResult<()> {
        self.delete(db, serial_num).await
    }

    pub async fn tag_list(&self, db: &DbConn) -> MijiResult<Vec<entity::tag::Model>> {
        let models = self.list(db).await?;
        self.converter().localize_models(models).await
    }

    // ✅ 列表查询（带过滤）
    pub async fn tag_list_with_filter(
        &self,
        db: &DbConn,
        filter: TagsFilter,
    ) -> MijiResult<Vec<entity::tag::Model>> {
        let models = self.list_with_filter(db, filter).await?;
        self.converter().localize_models(models).await
    }

    // ✅ 分页查询
    pub async fn tag_list_paged(
        &self,
        db: &DbConn,
        query: PagedQuery<TagsFilter>,
    ) -> MijiResult<PagedResult<entity::tag::Model>> {
        self.list_paged(db, query)
            .await?
            .map_async(|rows| self.converter().localize_models(rows))
            .await
    }

    // ✅ 批量创建
    pub async fn tag_create_batch(
        &self,
        db: &DbConn,
        data: Vec<TagCreate>,
    ) -> MijiResult<Vec<entity::tag::Model>> {
        let models = self.create_batch(db, data).await?;
        self.converter().localize_models(models).await
    }

    // ✅ 批量删除
    pub async fn tag_delete_batch(&self, db: &DbConn, ids: Vec<String>) -> MijiResult<u64> {
        self.delete_batch(db, ids).await
    }

    // ✅ 判断是否存在
    pub async fn tag_exists(&self, db: &DbConn, serial_num: String) -> MijiResult<bool> {
        self.exists(db, serial_num).await
    }

    // ✅ 总条数
    pub async fn tag_count(&self, db: &DbConn) -> MijiResult<u64> {
        self.count(db).await
    }

    // ✅ 条件总条数
    pub async fn tag_count_with_filter(&self, db: &DbConn, filter: TagsFilter) -> MijiResult<u64> {
        self.count_with_filter(db, filter).await
    }
}
