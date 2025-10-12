use std::sync::Arc;

use common::{
    crud::service::{
        CrudConverter, CrudService, GenericCrudService, LocalizableConverter,
        update_entity_columns_simple,
    },
    error::{AppError, MijiResult},
    paginations::{DateRange, Filter, PagedQuery, PagedResult, Sortable},
    utils::date::DateUtils,
};
use entity::{localize::LocalizeModel, todo::Status};
use sea_orm::{
    ActiveValue, ColumnTrait, Condition, DbConn, EntityTrait, Order, PaginatorTrait, QueryFilter,
    QueryOrder, QuerySelect,
    prelude::{Expr, async_trait::async_trait},
};
use serde::{Deserialize, Serialize};
use validator::Validate;

use crate::{
    dto::todo::{TodoCreate, TodoUpdate},
    service::todo_hooks::TodoHooks,
};

#[derive(Debug, Clone, Serialize, Deserialize, Validate)]
#[serde(rename_all = "camelCase")]
pub struct TodosFilter {
    status: Option<String>,
    date_range: Option<DateRange>,
}

impl Filter<entity::todo::Entity> for TodosFilter {
    fn to_condition(&self) -> sea_orm::Condition {
        let mut condition = Condition::all();
        if let Some(status) = &self.status {
            condition = condition.add(entity::todo::Column::Status.eq(status));
        }
        if let Some(range) = &self.date_range {
            condition = condition.add(range.to_condition(entity::todo::Column::DueAt));
        }
        condition
    }
}

#[derive(Debug)]
pub struct TodosConverter;

impl CrudConverter<entity::todo::Entity, TodoCreate, TodoUpdate> for TodosConverter {
    fn create_to_active_model(&self, data: TodoCreate) -> MijiResult<entity::todo::ActiveModel> {
        entity::todo::ActiveModel::try_from(data).map_err(AppError::from_validation_errors)
    }

    fn update_to_active_model(
        &self,
        model: entity::todo::Model,
        data: TodoUpdate,
    ) -> MijiResult<entity::todo::ActiveModel> {
        entity::todo::ActiveModel::try_from(data)
            .map(|mut active_model| {
                active_model.serial_num = ActiveValue::Set(model.serial_num.clone());
                active_model.created_at = ActiveValue::Set(model.created_at);
                active_model.updated_at = ActiveValue::Set(Some(DateUtils::local_now()));
                active_model
            })
            .map_err(AppError::from_validation_errors)
    }

    fn primary_key_to_string(&self, model: &entity::todo::Model) -> String {
        model.serial_num.clone()
    }

    fn table_name(&self) -> &'static str {
        "todo"
    }
}

#[async_trait]
impl LocalizableConverter<entity::todo::Model> for TodosConverter {
    async fn model_with_local(
        &self,
        model: entity::todo::Model,
    ) -> MijiResult<entity::todo::Model> {
        Ok(model.to_local())
    }
}

// 待办事项服务实现
pub struct TodosService {
    inner: GenericCrudService<
        entity::todo::Entity,
        TodosFilter,
        TodoCreate,
        TodoUpdate,
        TodosConverter,
        TodoHooks,
    >,
}

impl TodosService {
    pub fn new(
        converter: TodosConverter,
        hooks: TodoHooks,
        logger: Arc<dyn common::log::logger::OperationLogger>,
    ) -> Self {
        Self {
            inner: GenericCrudService::new(converter, hooks, logger),
        }
    }
}

impl std::ops::Deref for TodosService {
    type Target = GenericCrudService<
        entity::todo::Entity,
        TodosFilter,
        TodoCreate,
        TodoUpdate,
        TodosConverter,
        TodoHooks,
    >;

    fn deref(&self) -> &Self::Target {
        &self.inner
    }
}

impl TodosService {
    pub async fn todo_get(
        &self,
        db: &DbConn,
        serial_num: String,
    ) -> MijiResult<entity::todo::Model> {
        let opt_model = if serial_num.is_empty() {
            entity::todo::Entity::find().one(db).await?
        } else {
            Some(self.get_by_id(db, serial_num).await?)
        };
        let model = opt_model.ok_or_else(|| {
            AppError::simple(common::BusinessCode::NotFound, "todo notfound".to_string())
        })?;
        self.converter().model_with_local(model).await
    }

    pub async fn todo_create(
        &self,
        db: &DbConn,
        data: TodoCreate,
    ) -> MijiResult<entity::todo::Model> {
        let model = self.create(db, data).await?;
        self.converter().model_with_local(model).await
    }

    pub async fn todo_update(
        &self,
        db: &DbConn,
        serial_num: String,
        data: TodoUpdate,
    ) -> MijiResult<entity::todo::Model> {
        let model = self.update(db, serial_num, data).await?;
        self.converter().model_with_local(model).await
    }

    pub async fn todo_toggle(
        &self,
        db: &DbConn,
        serial_num: String,
        status: Status,
    ) -> MijiResult<entity::todo::Model> {
        let now = DateUtils::local_now();
        let mut updates = vec![
            (entity::todo::Column::Status, Expr::value(status.clone())),
            (entity::todo::Column::UpdatedAt, Expr::value(now)),
        ];

        if status == Status::Completed {
            updates.push((entity::todo::Column::CompletedAt, Expr::value(now)));
        }

        update_entity_columns_simple::<entity::todo::Entity, _>(
            db,
            vec![(entity::todo::Column::SerialNum, vec![serial_num.clone()])],
            updates,
        )
        .await?;
        self.get_by_id(db, serial_num).await
    }

    pub async fn todo_delete(&self, db: &DbConn, id: String) -> MijiResult<()> {
        self.delete(db, id).await
    }

    pub async fn todo_list(&self, db: &DbConn) -> MijiResult<Vec<entity::todo::Model>> {
        let models = self.list(db).await?;
        self.converter().localize_models(models).await
    }

    pub async fn todo_list_with_filter(
        &self,
        db: &DbConn,
        filter: TodosFilter,
    ) -> MijiResult<Vec<entity::todo::Model>> {
        let models = self.list_with_filter(db, filter).await?;
        self.converter().localize_models(models).await
    }

    pub async fn todo_list_paged(
        &self,
        db: &DbConn,
        query: PagedQuery<TodosFilter>,
    ) -> MijiResult<PagedResult<entity::todo::Model>> {
        // Step 1: Calculate total count of all todos (with original filter, ignoring status)
        let mut total_query_builder =
            entity::todo::Entity::find().filter(query.filter.to_condition());
        total_query_builder = query.sort_options.apply_sort(total_query_builder);
        let total_count = total_query_builder
            .clone()
            .count(db)
            .await
            .map_err(AppError::from)? as usize;

        // Step 2: Query all todos, sorted by status (non-completed first) and Priority DESC
        let mut query_builder = entity::todo::Entity::find()
            .filter(query.filter.to_condition())
            .order_by(
                sea_orm::sea_query::Expr::cust("CASE WHEN status != 'Completed' THEN 0 ELSE 1 END"),
                Order::Desc, // Non-completed first, completed last
            )
            .order_by(entity::todo::Column::Priority, Order::Desc); // Then sort by Priority DESC

        // Apply additional sorting from sort_options
        query_builder = query.sort_options.apply_sort(query_builder);

        let offset = (query.current_page - 1) * query.page_size;
        let rows = query_builder
            .offset(offset as u64)
            .limit(query.page_size as u64)
            .all(db)
            .await
            .map_err(AppError::from)?;

        // Calculate total pages
        let total_pages = total_count.div_ceil(query.page_size);

        PagedResult {
            rows,
            total_count,
            current_page: query.current_page,
            page_size: query.page_size,
            total_pages,
        }
        .map_async(|rows| self.converter().localize_models(rows))
        .await
    }

    pub async fn todo_create_batch(
        &self,
        db: &DbConn,
        data: Vec<TodoCreate>,
    ) -> MijiResult<Vec<entity::todo::Model>> {
        let models = self.create_batch(db, data).await?;
        self.converter().localize_models(models).await
    }

    pub async fn todo_delete_batch(&self, db: &DbConn, ids: Vec<String>) -> MijiResult<u64> {
        self.delete_batch(db, ids).await
    }

    pub async fn todo_exists(&self, db: &DbConn, id: String) -> MijiResult<bool> {
        self.exists(db, id).await
    }

    pub async fn todo_count(&self, db: &DbConn) -> MijiResult<u64> {
        self.count(db).await
    }

    pub async fn todo_count_with_filter(
        &self,
        db: &DbConn,
        filter: TodosFilter,
    ) -> MijiResult<u64> {
        self.count_with_filter(db, filter).await
    }
}

pub fn get_todos_service() -> TodosService {
    TodosService::new(
        TodosConverter,
        TodoHooks,
        Arc::new(common::log::logger::NoopLogger),
    )
}
