// -----------------------------------------------------------------------------
//    Copyright (C) 2025 mcgeq. All rights reserved.
// Author:         mcgeq
// Email:          <mcgeq@outlook.com>
// File:           service.rs
// Description:    About Common
// Create   Date:  2025-08-07 09:16:50
// Last Modified:  2025-08-08 19:43:15
// Modified   By:  mcgeq <mcgeq@outlook.com>
// ----------------------------------------------------------------------------

use crate::{
    BusinessCode,
    crud::hooks::Hooks,
    error::{AppError, MijiResult},
    log::logger::OperationLogger,
    paginations::{Filter, PagedQuery, PagedResult, Sortable},
};
use sea_orm::{
    ActiveModelTrait, ColumnTrait, DbConn, EntityTrait, FromQueryResult, IntoActiveModel,
    PaginatorTrait, PrimaryKeyTrait, QueryFilter, QuerySelect, TransactionTrait, Value,
    prelude::async_trait::async_trait, sea_query::SimpleExpr,
};
use serde::{Serialize, de::DeserializeOwned};
use std::{fmt, str::FromStr, sync::Arc};
use tracing::{error, info};
use validator::Validate;

/// 重构后的 CRUD 服务 trait
#[async_trait]
pub trait CrudService<E, F, C, U>
where
    E: EntityTrait,
    E::Model: FromQueryResult + Serialize + Send + Sync + Clone,
    E::ActiveModel: ActiveModelTrait<Entity = E> + Send,
    E::PrimaryKey: PrimaryKeyTrait,
    <E::PrimaryKey as PrimaryKeyTrait>::ValueType: Clone + Send + Sync + 'static,
    F: Filter<E> + Send + Sync,
    C: Validate + Send + Sync,
    U: Validate + Send + Sync,
{
    // 基础 CRUD 操作
    async fn create(&self, db: &DbConn, data: C) -> MijiResult<E::Model>;
    async fn get_by_id(
        &self,
        db: &DbConn,
        id: <E::PrimaryKey as PrimaryKeyTrait>::ValueType,
    ) -> MijiResult<E::Model>;
    async fn update(
        &self,
        db: &DbConn,
        id: <E::PrimaryKey as PrimaryKeyTrait>::ValueType,
        data: U,
    ) -> MijiResult<E::Model>;
    async fn delete(
        &self,
        db: &DbConn,
        id: <E::PrimaryKey as PrimaryKeyTrait>::ValueType,
    ) -> MijiResult<()>;

    // 查询操作
    async fn list(&self, db: &DbConn) -> MijiResult<Vec<E::Model>>;
    async fn list_with_filter(&self, db: &DbConn, filter: F) -> MijiResult<Vec<E::Model>>;
    async fn list_paged(
        &self,
        db: &DbConn,
        query: PagedQuery<F>,
    ) -> MijiResult<PagedResult<E::Model>>;

    // 批量操作
    async fn create_batch(&self, db: &DbConn, data: Vec<C>) -> MijiResult<Vec<E::Model>>;
    async fn delete_batch(
        &self,
        db: &DbConn,
        ids: Vec<<E::PrimaryKey as PrimaryKeyTrait>::ValueType>,
    ) -> MijiResult<u64>;

    // 存在性检查
    async fn exists(
        &self,
        db: &DbConn,
        id: <E::PrimaryKey as PrimaryKeyTrait>::ValueType,
    ) -> MijiResult<bool>;
    async fn count(&self, db: &DbConn) -> MijiResult<u64>;
    async fn count_with_filter(&self, db: &DbConn, filter: F) -> MijiResult<u64>;

    // 可选的钩子方法
    async fn before_create(&self, _data: &C) -> MijiResult<()> {
        Ok(())
    }
    async fn after_create(&self, _model: &E::Model) -> MijiResult<()> {
        Ok(())
    }
    async fn before_update(&self, _model: &E::Model, _data: &U) -> MijiResult<()> {
        Ok(())
    }
    async fn after_update(&self, _model: &E::Model) -> MijiResult<()> {
        Ok(())
    }
    async fn before_delete(&self, _model: &E::Model) -> MijiResult<()> {
        Ok(())
    }
    async fn after_delete(
        &self,
        _id: &<E::PrimaryKey as PrimaryKeyTrait>::ValueType,
    ) -> MijiResult<()> {
        Ok(())
    }
}

/// 转换器 trait - 分离数据转换逻辑
pub trait CrudConverter<E, C, U>
where
    E: EntityTrait,
    E::ActiveModel: ActiveModelTrait<Entity = E>,
{
    /// 将创建数据转换为 ActiveModel
    fn create_to_active_model(&self, data: C) -> MijiResult<E::ActiveModel>;

    /// 将更新数据应用到现有 ActiveModel
    fn update_to_active_model(&self, model: E::Model, data: U) -> MijiResult<E::ActiveModel>;

    /// 获取主键值字符串表示
    fn primary_key_to_string(&self, model: &E::Model) -> String;

    /// 获取表名
    fn table_name(&self) -> &'static str;
}

/// 通用 CRUD 服务实现
pub struct GenericCrudService<E, F, C, U, Conv, H> {
    converter: Conv,
    hooks: H,
    logger: Arc<dyn OperationLogger>,
    _phantom: std::marker::PhantomData<(E, F, C, U)>,
}

impl<E, F, C, U, Conv, H> GenericCrudService<E, F, C, U, Conv, H>
where
    E: EntityTrait,
    E::Model: FromQueryResult + Serialize + Send + Sync + Clone,
    E::ActiveModel: ActiveModelTrait<Entity = E> + Send,
    E::PrimaryKey: PrimaryKeyTrait,
    <E::PrimaryKey as PrimaryKeyTrait>::ValueType: Clone + Send + Sync + 'static,
    F: Filter<E> + Send + Sync,
    C: Validate + Send + Sync,
    U: Validate + Send + Sync,
    Conv: CrudConverter<E, C, U>,
    H: Hooks<E, C, U>,
{
    pub fn new(converter: Conv, hooks: H, logger: Arc<dyn OperationLogger>) -> Self {
        Self {
            converter,
            hooks,
            logger,
            _phantom: std::marker::PhantomData,
        }
    }

    /// 获取转换器的引用
    pub fn converter(&self) -> &Conv {
        &self.converter
    }

    pub fn logger(&self) -> &dyn OperationLogger {
        self.logger.as_ref()
    }

    /// 序列化模型为 JSON
    fn serialize_model(&self, model: &E::Model) -> MijiResult<serde_json::Value> {
        serde_json::to_value(model)
            .map_err(|e| AppError::internal_server_error(format!("Serialization failed: {e}")))
    }
}

#[async_trait]
impl<E, F, C, U, Conv, H> CrudService<E, F, C, U> for GenericCrudService<E, F, C, U, Conv, H>
where
    E: EntityTrait,
    E::Model: FromQueryResult + Serialize + Send + Sync + Clone + IntoActiveModel<E::ActiveModel>,
    E::ActiveModel: ActiveModelTrait<Entity = E> + Send,
    E::PrimaryKey: PrimaryKeyTrait,
    <E::PrimaryKey as PrimaryKeyTrait>::ValueType: Clone + Send + Sync + 'static + PartialEq,
    E::Column: ColumnTrait + FromStr,
    F: Filter<E> + Send + Sync + Validate + std::fmt::Debug,
    C: Validate + Send + Sync + Clone,
    U: Validate + Send + Sync,
    Conv: CrudConverter<E, C, U> + Send + Sync,
    H: Hooks<E, C, U> + Send + Sync,
{
    async fn create(&self, db: &DbConn, data: C) -> MijiResult<E::Model> {
        // 验证数据
        self.validate_data(&data)?;
        let tx = db.begin().await?;

        // 前置钩子
        self.hooks.before_create(&tx, &data).await?;

        // 转换为 ActiveModel
        let active_model = self.converter.create_to_active_model(data)?;
        // 插入数据库
        let model = active_model.insert(&tx).await.map_err(AppError::from)?;

        // 记录日志
        let record_id = self.converter.primary_key_to_string(&model);
        let data_after = self.serialize_model(&model)?;
        let table_name = self.converter.table_name();

        // 记录日志
        self.logger
            .log_operation(
                "CREATE",
                table_name,
                &record_id,
                None,
                Some(&data_after),
                Some(&tx),
            )
            .await?;

        // 后置钩子
        self.hooks.after_create(&tx, &model).await?;
        tx.commit().await?;

        Ok(model)
    }

    async fn get_by_id(
        &self,
        db: &DbConn,
        id: <E::PrimaryKey as PrimaryKeyTrait>::ValueType,
    ) -> MijiResult<E::Model> {
        E::find_by_id(id)
            .one(db)
            .await
            .map_err(AppError::from)?
            .ok_or_else(|| AppError::simple(BusinessCode::NotFound, "Entity not found"))
    }

    async fn update(
        &self,
        db: &DbConn,
        id: <E::PrimaryKey as PrimaryKeyTrait>::ValueType,
        data: U,
    ) -> MijiResult<E::Model> {
        // 验证数据
        self.validate_update_data(&data)?;

        let tx = db.begin().await?;

        // 查找现有实体
        let existing_model = E::find_by_id(id.clone())
            .one(&tx)
            .await?
            .ok_or_else(|| AppError::simple(BusinessCode::NotFound, "Entity not found"))?;

        // 前置钩子
        self.hooks
            .before_update(&tx, &existing_model, &data)
            .await?;

        // 转换为 ActiveModel
        let active_model = self
            .converter
            .update_to_active_model(existing_model.clone(), data)?;

        // 更新数据库
        let updated_model = active_model.update(&tx).await?;

        // 记录日志
        let record_id = self.converter.primary_key_to_string(&updated_model);
        let data_before = self.serialize_model(&existing_model)?;
        let data_after = self.serialize_model(&updated_model)?;
        let table_name = self.converter.table_name();

        // 记录日志
        self.logger
            .log_operation(
                "UPDATE",
                table_name,
                &record_id,
                Some(&data_before),
                Some(&data_after),
                Some(&tx),
            )
            .await?;
        // 后置钩子
        self.hooks.after_update(&tx, &updated_model).await?;

        tx.commit().await?;

        Ok(updated_model)
    }

    async fn delete(
        &self,
        db: &DbConn,
        id: <E::PrimaryKey as PrimaryKeyTrait>::ValueType,
    ) -> MijiResult<()> {
        let tx = db.begin().await?;

        // 检查实体是否存在并获取实体信息
        let model = E::find_by_id(id.clone())
            .one(&tx)
            .await?
            .ok_or_else(|| AppError::simple(BusinessCode::NotFound, "Entity not found"))?;

        // 前置钩子
        self.hooks.before_delete(&tx, &model).await?;

        // 记录日志
        let record_id = self.converter.primary_key_to_string(&model);
        let data_before = self.serialize_model(&model)?;
        let table_name = self.converter.table_name();

        // 记录日志
        self.logger
            .log_operation(
                "DELETE",
                table_name,
                &record_id,
                Some(&data_before),
                None,
                Some(&tx),
            )
            .await?;

        // 删除实体
        E::delete_by_id(id.clone()).exec(&tx).await?;

        // 后置钩子
        self.hooks.after_delete(&tx, &model).await?;

        tx.commit().await?;

        Ok(())
    }

    async fn list(&self, db: &DbConn) -> MijiResult<Vec<E::Model>> {
        E::find().all(db).await.map_err(AppError::from)
    }

    async fn list_with_filter(&self, db: &DbConn, filter: F) -> MijiResult<Vec<E::Model>> {
        E::find()
            .filter(filter.to_condition())
            .all(db)
            .await
            .map_err(AppError::from)
    }

    async fn list_paged(
        &self,
        db: &DbConn,
        query: PagedQuery<F>,
    ) -> MijiResult<PagedResult<E::Model>> {
        info!("list_paged start Query {:?}", query);
        // 验证查询参数
        self.validate_paged_query(&query)?;

        // 构建基础查询
        let mut query_builder = E::find();

        // 应用过滤条件
        query_builder = query_builder.filter(query.filter.to_condition());

        info!("Before sort_options query_builder {:?}", query_builder);
        // 应用排序
        query_builder = query.sort_options.apply_sort(query_builder);
        info!("After sort_options query_builder {:?}", query_builder);
        // 计算总数
        let total_count = query_builder
            .clone()
            .count(db)
            .await
            .map_err(AppError::from)? as usize;

        // 计算总页数
        let total_pages = total_count.div_ceil(query.page_size);

        // 应用分页
        let offset = (query.current_page - 1) * query.page_size;
        let rows = query_builder
            .offset(offset as u64)
            .limit(query.page_size as u64)
            .all(db)
            .await
            .map_err(AppError::from)?;

        Ok(PagedResult {
            rows,
            total_count,
            current_page: query.current_page,
            page_size: query.page_size,
            total_pages,
        })
    }

    async fn create_batch(&self, db: &DbConn, data: Vec<C>) -> MijiResult<Vec<E::Model>> {
        if data.is_empty() {
            return Ok(Vec::new());
        }

        let tx = db.begin().await.map_err(AppError::from)?;
        let mut results = Vec::with_capacity(data.len());
        let mut logs = Vec::with_capacity(data.len());
        let table_name = self.converter.table_name();

        for item in data {
            // 验证每个数据项
            self.validate_data(&item)?;

            // 前置钩子
            self.hooks.before_create(&tx, &item).await?;

            // 转换并插入
            let active_model = self.converter.create_to_active_model(item)?;
            let model = active_model.insert(&tx).await.map_err(AppError::from)?;

            // 准备日志
            let record_id = self.converter.primary_key_to_string(&model);
            let data_after = self.serialize_model(&model)?;

            logs.push((table_name, record_id, None, Some(data_after)));

            // 后置钩子
            self.hooks.after_create(&tx, &model).await?;

            results.push(model);
        }

        // 批量记录日志
        for (target_table, record_id, data_before, data_after) in logs {
            self.logger
                .log_operation(
                    "CREATE_BATCH",
                    target_table,
                    &record_id,
                    data_before.as_ref(),
                    data_after.as_ref(),
                    Some(&tx),
                )
                .await?;
        }

        tx.commit().await.map_err(AppError::from)?;

        Ok(results)
    }

    async fn delete_batch(
        &self,
        db: &DbConn,
        ids: Vec<<E::PrimaryKey as PrimaryKeyTrait>::ValueType>,
    ) -> MijiResult<u64> {
        if ids.is_empty() {
            return Ok(0);
        }

        // 注意：这里简化了批量删除的实现，实际使用中可能需要根据具体 Entity 调整
        let tx = db.begin().await.map_err(AppError::from)?;
        let mut deleted_count = 0u64;
        let mut logs = Vec::new();
        let table_name = self.converter.table_name();

        for id in ids.iter() {
            // 获取要删除的实体（用于钩子）
            if let Ok(model) = self.get_by_id(db, id.clone()).await {
                // 执行前置钩子
                self.hooks.before_delete(&tx, &model).await?;

                // 准备日志
                let record_id = self.converter.primary_key_to_string(&model);
                let data_before = self.serialize_model(&model)?;
                logs.push((table_name, record_id, Some(data_before), None));

                // 删除单个实体
                let delete_result = E::delete_by_id(id.clone())
                    .exec(db)
                    .await
                    .map_err(AppError::from)?;
                deleted_count += delete_result.rows_affected;

                // 执行后置钩子
                self.hooks.after_delete(&tx, &model).await?;
            }
        }

        // 批量记录日志
        for (target_table, record_id, data_before, data_after) in logs {
            self.logger
                .log_operation(
                    "DELETE_BATCH",
                    target_table,
                    &record_id,
                    data_before.as_ref(),
                    data_after,
                    Some(&tx),
                )
                .await?;
        }

        tx.commit().await.map_err(AppError::from)?;

        Ok(deleted_count)
    }

    async fn exists(
        &self,
        db: &DbConn,
        id: <E::PrimaryKey as PrimaryKeyTrait>::ValueType,
    ) -> MijiResult<bool> {
        let count = E::find_by_id(id).count(db).await.map_err(AppError::from)?;
        Ok(count > 0)
    }

    async fn count(&self, db: &DbConn) -> MijiResult<u64> {
        E::find().count(db).await.map_err(AppError::from)
    }

    async fn count_with_filter(&self, db: &DbConn, filter: F) -> MijiResult<u64> {
        E::find()
            .filter(filter.to_condition())
            .count(db)
            .await
            .map_err(AppError::from)
    }
}

// 辅助方法实现
impl<E, F, C, U, Conv, H> GenericCrudService<E, F, C, U, Conv, H>
where
    E: EntityTrait,
    C: Validate,
    U: Validate,
    F: Validate,
{
    /// 验证创建数据
    fn validate_data(&self, data: &C) -> MijiResult<()> {
        data.validate().map_err(|e| {
            AppError::validation_failed(
                BusinessCode::ValidationError,
                "Validation failed",
                Some(self.format_validation_errors(e)),
            )
        })
    }

    /// 验证更新数据
    fn validate_update_data(&self, data: &U) -> MijiResult<()> {
        data.validate().map_err(|e| {
            AppError::validation_failed(
                BusinessCode::ValidationError,
                "Update validation failed",
                Some(self.format_validation_errors(e)),
            )
        })
    }

    /// 验证分页查询参数
    fn validate_paged_query(&self, query: &PagedQuery<F>) -> MijiResult<()> {
        query.validate().map_err(|e| {
            AppError::validation_failed(
                BusinessCode::ValidationError,
                "Query validation failed",
                Some(self.format_validation_errors(e)),
            )
        })
    }

    /// 格式化验证错误
    fn format_validation_errors(&self, errors: validator::ValidationErrors) -> serde_json::Value {
        let mut error_details = serde_json::Map::new();

        for (field, field_errors) in errors.field_errors() {
            let messages: Vec<String> = field_errors
                .iter()
                .filter_map(|e| e.message.as_ref().map(|m| m.to_string()))
                .collect();

            if !messages.is_empty() {
                error_details.insert(
                    field.to_string(),
                    serde_json::Value::Array(
                        messages
                            .into_iter()
                            .map(serde_json::Value::String)
                            .collect(),
                    ),
                );
            }
        }

        serde_json::Value::Object(error_details)
    }
}

/// 简化的转换器实现宏
#[macro_export]
macro_rules! impl_crud_converter {
    ($converter:ident, $entity:ty, $create:ty, $update:ty) => {
        pub struct $converter;

        impl CrudConverter<$entity, $create, $update> for $converter {
            fn create_to_active_model(
                &self,
                data: $create,
            ) -> MijiResult<<$entity as EntityTrait>::ActiveModel> {
                // 具体实现需要根据实际情况填写
                unimplemented!("需要实现 create_to_active_model 方法")
            }

            fn update_to_active_model(
                &self,
                model: <$entity as EntityTrait>::Model,
                data: $update,
            ) -> MijiResult<<$entity as EntityTrait>::ActiveModel> {
                // 具体实现需要根据实际情况填写
                unimplemented!("需要实现 update_to_active_model 方法")
            }
        }
    };
}

/// 事务支持的 CRUD 服务
#[async_trait]
pub trait TransactionalCrudService<E, F, C, U>: CrudService<E, F, C, U>
where
    E: EntityTrait,
    E::Model: FromQueryResult + Serialize + Send + Sync + Clone,
    E::ActiveModel: ActiveModelTrait<Entity = E> + Send,
    E::PrimaryKey: PrimaryKeyTrait,
    <E::PrimaryKey as PrimaryKeyTrait>::ValueType: Clone + Send + Sync + 'static,
    F: Filter<E> + Send + Sync,
    C: Validate + Send + Sync,
    U: Validate + Send + Sync,
{
    /// 在事务中创建
    async fn create_in_txn(&self, txn: &sea_orm::DbConn, data: C) -> MijiResult<E::Model>;

    /// 在事务中更新
    async fn update_in_txn(
        &self,
        txn: &sea_orm::DbConn,
        id: <E::PrimaryKey as PrimaryKeyTrait>::ValueType,
        data: U,
    ) -> MijiResult<E::Model>;

    /// 在事务中删除
    async fn delete_in_txn(
        &self,
        txn: &sea_orm::DbConn,
        id: <E::PrimaryKey as PrimaryKeyTrait>::ValueType,
    ) -> MijiResult<()>;
}

/// 通用更新函数
pub async fn update_entity_columns_simple<E, C>(
    db: &DbConn,
    filters: impl IntoIterator<Item = (C, impl IntoIterator<Item = impl Into<Value>>)>,
    updates: impl IntoIterator<Item = (C, SimpleExpr)>,
) -> MijiResult<u64>
where
    E: EntityTrait,
    C: Copy + ColumnTrait,
{
    // 处理过滤条件
    let mut filters_iter = filters.into_iter();
    let first_filter = match filters_iter.next() {
        Some((col, values)) => {
            let expr_values: Vec<Value> = values.into_iter().map(|v| v.into()).collect();
            if expr_values.is_empty() {
                return Err(AppError::simple(
                    BusinessCode::InvalidParameter,
                    "Filter values cannot be empty".to_string(),
                ));
            }
            col.is_in(expr_values)
        }
        None => {
            return Err(AppError::simple(
                BusinessCode::InvalidParameter,
                "Filters cannot be empty".to_string(),
            ));
        }
    };

    let mut filter_expr = first_filter;
    for (col, values) in filters_iter {
        let expr_values: Vec<Value> = values.into_iter().map(|v| v.into()).collect();
        if expr_values.is_empty() {
            return Err(AppError::simple(
                BusinessCode::InvalidParameter,
                "Filter values cannot be empty".to_string(),
            ));
        }
        filter_expr = filter_expr.and(col.is_in(expr_values));
    }

    update_table_columns::<E, C>(db, filter_expr, updates).await
}

/// 输入清理，防止 SQL 注入
pub fn sanitize_input(input: &str) -> String {
    input
        .trim()
        .replace(';', "")
        .replace("--", "")
        .replace("/*", "")
        .replace("*/", "")
}

// 枚举序列化辅助函数
pub fn serialize_enum<T>(value: &T) -> String
where
    T: serde::Serialize + fmt::Display,
{
    value.to_string()
}

pub fn parse_enum_filed<T>(value: &str, field_name: &str, default: T) -> T
where
    T: FromStr,
    <T as FromStr>::Err: std::fmt::Display,
{
    value.parse().unwrap_or_else(|e| {
        #[cfg(debug_assertions)]
        error!("Failed to parse {} '{}': {}", field_name, value, e);
        default
    })
}

pub fn parse_json_field<T: serde::de::DeserializeOwned>(
    value: &str,
    field_name: &str,
    default: T,
) -> T {
    serde_json::from_str(value).unwrap_or_else(|e| {
        #[cfg(debug_assertions)]
        error!("Failed to parse {} '{}': {}", field_name, value, e);
        default
    })
}

/// 统一解析 JSON 字段（高效版）
pub fn parse_json<T: DeserializeOwned, V>(value: V, field_name: &str, default: T) -> T
where
    V: JsonInput,
{
    value.parse_json(field_name, default)
}

/// Trait 用于抽象不同输入类型
pub trait JsonInput {
    fn parse_json<T: DeserializeOwned>(self, field_name: &str, default: T) -> T;
}

/// 实现针对 &str
impl JsonInput for &str {
    fn parse_json<T: DeserializeOwned>(self, field_name: &str, default: T) -> T {
        serde_json::from_str(self).unwrap_or_else(|e| {
            #[cfg(debug_assertions)]
            eprintln!("Failed to parse {field_name} '{self}': {e}");
            default
        })
    }
}

/// 实现针对 Option<JsonValue>，直接用 from_value 避免字符串中转
impl JsonInput for &Option<serde_json::Value> {
    fn parse_json<T: DeserializeOwned>(self, field_name: &str, default: T) -> T {
        match self {
            Some(json_val) => serde_json::from_value(json_val.clone()).unwrap_or_else(|e| {
                #[cfg(debug_assertions)]
                eprintln!("Failed to parse {field_name} '{json_val:?}': {e}");
                default
            }),
            None => default,
        }
    }
}

/// 通用批量更新函数：
/// - `E`: 表对应的 Entity
/// - `C`: 表对应的 Column 枚举
pub async fn update_table_columns<E, C>(
    db: &DbConn,
    filter: SimpleExpr,
    updates: impl IntoIterator<Item = (C, SimpleExpr)>,
) -> MijiResult<u64>
where
    E: EntityTrait,
    C: ColumnTrait,
{
    let mut updater = E::update_many().filter(filter);

    for (col, expr) in updates {
        updater = updater.col_expr(col, expr);
    }

    let result = updater.exec(db).await.map_err(AppError::from)?;
    if result.rows_affected == 0 {
        return Err(AppError::simple(
            BusinessCode::NotFound,
            "No rows matched filter".to_string(),
        ));
    }

    Ok(result.rows_affected)
}
