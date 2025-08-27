use common::{
    crud::service::{CrudConverter, CrudService, GenericCrudService},
    error::{AppError, MijiResult}, log::logger::{NoopLogger, OperationLogger},
    paginations::{DateRange, Filter, PagedQuery, PagedResult},
    utils::date::DateUtils, BusinessCode
};

use sea_orm::{
    prelude::{async_trait::async_trait, Decimal},
    sea_query::{Expr, Func, SimpleExpr }, ActiveModelTrait,
    ActiveValue::Set, ColumnTrait, Condition, DatabaseConnection,
    EntityTrait, IntoActiveModel, PaginatorTrait, QueryFilter,
    QueryOrder, QuerySelect, SelectTwo, TransactionTrait
};
use serde::{Deserialize, Serialize};

use std::sync::Arc;
use std::{collections::HashMap, str::FromStr};
use validator::Validate;
use tracing::info;

use crate::{
    dto::account::{AccountBalanceSummary, CreateAccountRequest, UpdateAccountRequest},
    services::account_hooks::AccountHooks,
};
use entity::{
    account::{Column as AccountColumn, Entity as AccountEntity, Model as AccountModel},
    currency::{Entity as CurrencyEntity, Model as CurrencyModel},
    family_member::{Column as FamilyMemberColumn, Entity as FamilyMemberEntity, Model as FamilyMemberModel}
};

/// 账户过滤器
#[derive(Debug, Validate, Deserialize)]
pub struct AccountFilter {
    pub name: Option<String>,
    pub r#type: Option<String>,
    pub currency: Option<String>,
    pub is_shared: Option<bool>,
    pub owner_id: Option<String>,
    pub is_active: Option<bool>,
    pub created_at_range: Option<DateRange>,
    pub updated_at_range: Option<DateRange>,
}

/// 包含完整关联信息的账户数据结构
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AccountWithRelations {
    pub account: entity::account::Model,
    pub currency: entity::currency::Model,
    pub owner: Option<entity::family_member::Model>,
}

impl Filter<entity::account::Entity> for AccountFilter {
    fn to_condition(&self) -> Condition {
        let mut condition = Condition::all();

        if let Some(name) = &self.name {
            condition = condition.add(entity::account::Column::Name.eq(name));
        }
        if let Some(r#type) = &self.r#type {
            condition = condition.add(entity::account::Column::Type.eq(r#type));
        }
        if let Some(currency) = &self.currency {
            condition = condition.add(entity::account::Column::Currency.eq(currency));
        }
        if let Some(is_shared) = self.is_shared {
            condition = condition.add(entity::account::Column::IsShared.eq(is_shared as i32));
        }
        if let Some(owner_id) = &self.owner_id {
            condition = condition.add(entity::account::Column::OwnerId.eq(owner_id));
        }
        if let Some(is_active) = self.is_active {
            condition = condition.add(entity::account::Column::IsActive.eq(is_active as i32));
        }
        if let Some(created_range) = &self.created_at_range {
            if let Some(start) = &created_range.start {
                condition = condition.add(entity::account::Column::CreatedAt.gte(start.clone()));
            }
            if let Some(end) = &created_range.end {
                condition = condition.add(entity::account::Column::CreatedAt.lte(end.clone()));
            }
        }
        if let Some(updated_range) = &self.updated_at_range {
            if let Some(start) = &updated_range.start {
                condition = condition.add(entity::account::Column::UpdatedAt.gte(start.clone()));
            }
            if let Some(end) = &updated_range.end {
                condition = condition.add(entity::account::Column::UpdatedAt.lte(end.clone()));
            }
        }
        condition
    }
}

/// 账户转换器
#[derive(Debug)]
pub struct AccountConverter;

impl CrudConverter<entity::account::Entity, CreateAccountRequest, UpdateAccountRequest>
    for AccountConverter
{
    fn create_to_active_model(
        &self,
        data: CreateAccountRequest,
    ) -> MijiResult<entity::account::ActiveModel> {
        entity::account::ActiveModel::try_from(data).map_err(AppError::from_validation_errors)
    }

    fn update_to_active_model(
        &self,
        model: entity::account::Model,
        data: UpdateAccountRequest,
    ) -> MijiResult<entity::account::ActiveModel> {
        entity::account::ActiveModel::try_from(data)
            .map(|mut active_model| {
                // 保留主键和创建时间等不可变字段
                active_model.serial_num = Set(model.serial_num.clone());
                active_model.created_at = Set(model.created_at.clone());

                // 设置更新时间
                active_model.updated_at = Set(Some(DateUtils::local_rfc3339()));

                active_model
            })
            .map_err(AppError::from_validation_errors)
    }

    fn primary_key_to_string(&self, model: &entity::account::Model) -> String {
        model.serial_num.clone()
    }

    fn table_name(&self) -> &'static str {
        "accounts"
    }
}

// 账户加载器(关联查询)
#[async_trait]
pub trait AccountLoader {
    /// Load account currency
    async fn load_currency(
        db: &DatabaseConnection,
        account: &AccountModel
    ) -> MijiResult<Option<CurrencyModel>>;

    /// Load account owner
    async fn load_owner(
        db: &DatabaseConnection,
        account: &AccountModel,
    ) -> MijiResult<Option<FamilyMemberModel>>;

    /// 批量获取所有者信息
    async fn batch_fetch_owners(
        db: &DatabaseConnection,
        owner_ids: &[String],
    ) -> MijiResult<HashMap<String, FamilyMemberModel>>;
}

/// Default Account Load
pub struct DefaultAccountLoader;

#[async_trait]
impl AccountLoader for DefaultAccountLoader {
    async fn load_currency(
        db: &DatabaseConnection,
        account: &AccountModel,
    ) -> MijiResult<Option<CurrencyModel>> {
        let currency_id = account.currency.clone();
        CurrencyEntity::find_by_id(currency_id.clone())
            .one(db)
            .await
            .map_err(Into::into)
    }

    async fn load_owner(
        db: &DatabaseConnection,
        account: &AccountModel,
    ) -> MijiResult<Option<FamilyMemberModel>> {
        let owner_id = account.owner_id.as_ref().ok_or_else(|| AppError::simple(BusinessCode::NotFound, "Owner ID missing"))?;
        FamilyMemberEntity::find_by_id(owner_id.clone())
            .one(db)
            .await
            .map_err(Into::into)
    }

    async fn batch_fetch_owners(
        db: &DatabaseConnection,
        owner_ids: &[String],
    ) -> MijiResult<HashMap<String, FamilyMemberModel>> {
        if owner_ids.is_empty() {
            return Ok(HashMap::new());
        }

        let owners = FamilyMemberEntity::find()
            .filter(FamilyMemberColumn::SerialNum.is_in(owner_ids))
            .all(db)
            .await?;

        Ok(owners.into_iter()
            .map(|owner| (owner.serial_num.clone(), owner))
            .collect())
    }
}

/// 账户服务类型别名
pub type BaseAccountService = GenericCrudService<
    entity::account::Entity,
    AccountFilter,
    CreateAccountRequest,
    UpdateAccountRequest,
    AccountConverter,
    AccountHooks,
>;

pub struct AccountService {
    inner: BaseAccountService,
    logger: Arc<dyn OperationLogger>,
}

/// 账户计算规则（用于总资产计算）
struct AccountCalculator {
    name_type: String,
    condition: Condition,
    balance_expr: SimpleExpr,
}

impl AccountService {
    pub fn get_service() -> Self {
        Self::new(None)
    }

    pub fn new(logger: Option<Arc<dyn OperationLogger>>) -> Self {
        let lg = logger.unwrap_or_else(|| Arc::new(NoopLogger));
        Self {
            inner: GenericCrudService::new(AccountConverter, AccountHooks, lg.clone()),
            logger: lg,
        }
    }
}

// 实现 CrudService 特性
#[async_trait]
impl CrudService<entity::account::Entity, AccountFilter, CreateAccountRequest, UpdateAccountRequest> for AccountService {
    async fn create(
        &self,
        db: &DatabaseConnection,
        data: CreateAccountRequest,
    ) -> MijiResult<entity::account::Model> {
        self.inner.create(db, data).await
    }

    async fn get_by_id(
        &self,
        db: &DatabaseConnection,
        id: String,
    ) -> MijiResult<entity::account::Model> {
        self.inner.get_by_id(db, id).await
    }

    async fn update(
        &self,
        db: &DatabaseConnection,
        serial_num: String,
        data: UpdateAccountRequest,
    ) -> MijiResult<entity::account::Model> {
        self.inner.update(db, serial_num, data).await
    }

    async fn delete(&self, db: &DatabaseConnection, serial_num: String) -> MijiResult<()> {
        self.inner.delete(db, serial_num).await
    }

    async fn list(&self, db: &DatabaseConnection) -> MijiResult<Vec<entity::account::Model>> {
        self.inner.list(db).await
    }

    async fn list_with_filter(
        &self,
        db: &DatabaseConnection,
        filter: AccountFilter,
    ) -> MijiResult<Vec<entity::account::Model>> {
        self.inner.list_with_filter(db, filter).await
    }

    async fn list_paged(
        &self,
        db: &DatabaseConnection,
        query: PagedQuery<AccountFilter>,
    ) -> MijiResult<PagedResult<entity::account::Model>> {
        self.inner.list_paged(db, query).await
    }

    async fn create_batch(
        &self,
        db: &DatabaseConnection,
        data: Vec<CreateAccountRequest>,
    ) -> MijiResult<Vec<entity::account::Model>> {
        self.inner.create_batch(db, data).await
    }

    async fn delete_batch(&self, db: &DatabaseConnection, ids: Vec<String>) -> MijiResult<u64> {
        self.inner.delete_batch(db, ids).await
    }

    async fn exists(&self, db: &DatabaseConnection, id: String) -> MijiResult<bool> {
        self.inner.exists(db, id).await
    }

    async fn count(&self, db: &DatabaseConnection) -> MijiResult<u64> {
        self.inner.count(db).await
    }

    async fn count_with_filter(
        &self,
        db: &DatabaseConnection,
        filter: AccountFilter,
    ) -> MijiResult<u64> {
        self.inner.count_with_filter(db, filter).await
    }

}

impl AccountService {

    pub async fn create_account(
        &self,
        db: &DatabaseConnection,
        data: CreateAccountRequest
    ) -> MijiResult<AccountWithRelations> {
        let tx = db.begin().await?;
        let account = self.inner.create(tx, data).await?;
        let account_with_relations = self.get_account_with_relations(tx, account.serial_num).await?;
        tx.commit().await?;
        Ok(account_with_relations)
    }
    /// 获取账户详情（带货币信息）
    pub async fn get_account_with_currency(
        &self,
        db: &DatabaseConnection,
        id: String,
    ) -> MijiResult<(entity::account::Model, entity::currency::Model)> {
        entity::account::Entity::find_by_id(id)
            .find_also_related(entity::currency::Entity)
            .one(db)
            .await
            .map_err(AppError::from)?
            .and_then(|(account, currency)| currency.map(|c| (account, c)))
            .ok_or_else(|| {
                AppError::simple(
                    BusinessCode::NotFound,
                    "Account not found or currency missing",
                )
            })
    }

    /// 获取账户详情（带完整关联信息：货币和所有者）
    pub async fn get_account_with_relations(
        &self,
        db: &DatabaseConnection,
        serial_num: String,
    ) -> MijiResult<AccountWithRelations> {
        // 首先获取账户和货币信息
        let (account, currency) = self
            .get_account_with_currency(db, serial_num.clone())
            .await?;

        // 如果有 owner_id，获取所有者信息
        let owner = DefaultAccountLoader::load_owner(db, &account).await?;

        Ok(AccountWithRelations { account, currency, owner })
    }

    /// 使用自定义查询获取账户和所有关联信息（更高效的方法）
    pub async fn get_account_with_relations_optimized(
        db: &DatabaseConnection,
        serial_num: String,
    ) -> MijiResult<AccountWithRelations> {
        let result = entity::account::Entity::find_by_id(serial_num)
            .find_also_related(entity::currency::Entity)
            .find_also_related(entity::family_member::Entity)
            .one(db)
            .await
            .map_err(AppError::from)?
            .ok_or_else(|| AppError::simple(BusinessCode::NotFound, "Account not found"))?;

        let (account, currency, owner) = result;
        let currency = currency.ok_or_else(|| {
            AppError::simple(BusinessCode::NotFound, "Currency information missing")
        })?;

        Ok(AccountWithRelations { account, currency, owner })
    }

    /// 分页查询账户列表（带完整关联信息）
    pub async fn list_accounts_paged_with_relations(
        &self,
        db: &DatabaseConnection,
        query: PagedQuery<AccountFilter>,
    ) -> MijiResult<
        PagedResult<AccountWithRelations>,
    > {
        // 验证查询参数
        query.validate().map_err(AppError::from_validation_errors)?;
        let base_query = entity::account::Entity::find()
            .find_also_related(entity::currency::Entity)
            .filter(query.filter.to_condition());

        Self::paginate_with_relations(
            db,
            base_query,
            query.page_size as u64,
            query.current_page as u64,
            |(account, currency)| currency.map(|c| (account, c)),
        ).await
    }

/// 通用分页查询处理器（带关联加载）
    async fn paginate_with_relations<F>(
        db: &DatabaseConnection,
        base_query: SelectTwo<AccountEntity, CurrencyEntity>,
        page_size: u64,
        current_page: u64,
        filter_fn: F,
    ) -> MijiResult<PagedResult<AccountWithRelations>>
    where
        F: Fn((AccountModel, Option<CurrencyModel>)) -> Option<(AccountModel, CurrencyModel)> + Clone,
    {
        // 计算总数和分页参数
        let total_count = base_query.clone().count(db).await?.max(0) as usize;
        let total_pages = (total_count + page_size as usize - 1) / page_size as usize;
        let offset = (current_page.saturating_sub(1)).saturating_mul(page_size as u64);

        // 执行分页查询
        let rows_with_currency = base_query
            .clone()
            .offset(offset as u64)
            .limit(page_size)
            .all(db)
            .await?;

        // 提取需要加载的owner_id并批量查询
        let owner_ids: Vec<String> = rows_with_currency
            .iter()
            .filter_map(|(account, _)| account.owner_id.clone())
            .collect();
        let owners_map = DefaultAccountLoader::batch_fetch_owners(db, &owner_ids).await?;

        // 组装最终结果
        let filtered_rows = rows_with_currency
            .into_iter()
            .filter_map(|row| filter_fn(row));

        let rows = filtered_rows
            .into_iter()
            .map(|(account, currency)| {
                let owner = account.owner_id.as_ref()
                    .and_then(|id| owners_map.get(id))
                    .cloned();
                AccountWithRelations { account, currency, owner }
            })
            .collect();

        Ok(PagedResult {
            rows,
            total_count,
            current_page: current_page as usize,
            page_size: page_size as usize,
            total_pages,
        })
    }

    /// 分页查询账户列表（带货币信息）
    pub async fn list_accounts_paged_with_currency(
        &self,
        db: &DatabaseConnection,
        query: PagedQuery<AccountFilter>,
    ) -> MijiResult<PagedResult<(entity::account::Model, entity::currency::Model)>> {
        // 验证查询参数
        query.validate().map_err(AppError::from_validation_errors)?;

        let mut query_builder = entity::account::Entity::find()
            .find_also_related(entity::currency::Entity)
            .filter(query.filter.to_condition());

        // 应用排序
        query_builder = Self::apply_sort_to_select_two(
            query_builder,
            &query.sort_options.sort_by,
            query.sort_options.desc,
        );

        let (rows_with_currency, total_count, total_pages) = Self::paginate_query(
            query_builder,
            db,
            query.page_size as u64,
            query.current_page as u64,
            // 强制过滤无货币的记录（核心差异点）
            |(account, currency)| currency.map(|c| (account, c)),
        )
        .await?;

        let rows: Vec<_> = rows_with_currency
            .into_iter()
            .map(|(a, c, _)| (a, c))
            .collect();

        Ok(PagedResult {
            rows,
            total_count,
            current_page: query.current_page,
            page_size: query.page_size,
            total_pages,
        })
    }

/// 批量获取所有者信息（优化版）
    async fn batch_fetch_owners(
        db: &DatabaseConnection,
        owner_ids: &[String],
    ) -> MijiResult<HashMap<String, entity::family_member::Model>> {
        if owner_ids.is_empty() {
            return Ok(HashMap::new());
        }

        let owners = entity::family_member::Entity::find()
            .filter(entity::family_member::Column::SerialNum.is_in(owner_ids))
            .all(db)
            .await?;

        Ok(owners.into_iter()
            .map(|owner| (owner.serial_num.clone(), owner))
            .collect())
    }

    pub async fn list_with_filter(
        &self,
        db: &DatabaseConnection,
        query: AccountFilter,
    ) -> MijiResult<
        PagedResult<(
            entity::account::Model,
            entity::currency::Model,
            Option<entity::family_member::Model>,
        )>,
    > {
        query.validate().map_err(AppError::from_validation_errors)?;

        let mut query_builder = entity::account::Entity::find()
            .find_also_related(entity::currency::Entity)
            .filter(query.to_condition());

        query_builder = Self::apply_sort_to_select_two(query_builder, &None, true);

        let rows_with_currency = query_builder.all(db).await.map_err(AppError::from)?;

        let owner_ids: Vec<String> = rows_with_currency
            .iter()
            .filter_map(|(account, _)| account.owner_id.as_ref())
            .cloned()
            .collect();
        let owners_map = Self::batch_fetch_owners(db, &owner_ids).await?;

        let assemble_row = Self::assemble_account_row(&owners_map);
        let rows: Vec<(
            entity::account::Model,
            entity::currency::Model,
            Option<entity::family_member::Model>,
        )> = rows_with_currency
            .into_iter()
            .filter_map(|row| row.1.map(|currency| assemble_row((row.0, currency))))
            .collect();

        let total_count = rows.len();
        // 构造 PagedResult（无分页时，当前页为 1，每页大小为总记录数，总页数为 1）
        Ok(PagedResult {
            rows,
            total_count,
            current_page: 1,
            page_size: total_count,
            total_pages: 1,
        })
    }

    pub async fn update_account_active(
        &self,
        db: &DatabaseConnection,
        serial_num: String,
        is_active: bool,
    ) -> MijiResult<AccountWithRelations> {
        let account = entity::account::Entity::find_by_id(serial_num.clone())
            .one(db)
            .await
            .map_err(AppError::from)?
            .ok_or_else(|| {
                AppError::simple(
                    BusinessCode::NotFound,
                    format!("Account with SerialNum {}", serial_num.clone()),
                )
            })?;

        let mut active_model = account.into_active_model();
        active_model.is_active = Set(is_active as i32);
        active_model.updated_at = Set(Some(DateUtils::local_rfc3339()));

        active_model.update(db).await.map_err(AppError::from)?;
        self.get_account_with_relations(db, serial_num).await

    }

    /// 结果组装闭包
    fn assemble_account_row(
        owners_map: &HashMap<String, entity::family_member::Model>,
    ) -> impl Fn(
        (entity::account::Model, entity::currency::Model),
    ) -> (
        entity::account::Model,
        entity::currency::Model,
        Option<entity::family_member::Model>,
    ) {
        move |(account, currency)| {
            let owner = account
                .owner_id
                .as_ref()
                .and_then(|id| owners_map.get(id))
                .cloned();
            (account, currency, owner)
        }
    }

    /// 通用分页查询处理器
    async fn paginate_query<F>(
        query_builder: SelectTwo<entity::account::Entity, entity::currency::Entity>,
        db: &DatabaseConnection,
        page_size: u64,
        current_page: u64,
        filter_fn: F,
    ) -> MijiResult<(
        Vec<(
            entity::account::Model,
            entity::currency::Model,
            Option<entity::family_member::Model>,
        )>,
        usize,
        usize,
    )>
    where
        F: Fn(
                (entity::account::Model, Option<entity::currency::Model>),
            ) -> Option<(entity::account::Model, entity::currency::Model)>
            + Clone,
    {
        let total_count = query_builder
            .clone()
            .count(db)
            .await
            .map_err(AppError::from)? as usize;
        let total_pages = total_count.div_ceil(page_size as usize);
        let offset = (current_page.saturating_sub(1)).saturating_mul(page_size);

        let rows_with_currency = query_builder
            .clone()
            .offset(offset)
            .limit(page_size)
            .all(db)
            .await
            .map_err(AppError::from)?;

        let owner_ids: Vec<String> = rows_with_currency
            .iter()
            .filter_map(|(account, _)| account.owner_id.clone())
            .collect();
        let owners_map = Self::batch_fetch_owners(db, &owner_ids).await?;

        let assemble_row = Self::assemble_account_row(&owners_map);
        let rows = rows_with_currency
            .into_iter()
            .filter_map(|row| filter_fn(row).map(&assemble_row))
            .collect();

        Ok((rows, total_count, total_pages))
    }

pub async fn total_assets(&self, db: &DatabaseConnection) -> MijiResult<AccountBalanceSummary> {
    let mut sum_columns = HashMap::new();

    // 辅助函数：构建类型条件表达式（确保与数据库值一致）
    let build_type_condition = |type_str: &str| {
        AccountColumn::Type.eq(type_str.to_string())
    };

    // 构建所有计算列的 Expr（使用官方推荐的 case 语法）
    let bank_savings_expr = Expr::case(
        build_type_condition("Savings"),
        Expr::col(AccountColumn::Balance),
    ).finally(Expr::val(Decimal::ZERO));

    let cash_expr = Expr::case(
        build_type_condition("Cash"),
        Expr::col(AccountColumn::Balance),
    ).finally(Expr::val(Decimal::ZERO));

    let credit_card_expr = Expr::case(
        build_type_condition("CreditCard"),
        Func::abs(Expr::col(AccountColumn::Balance)),
    ).finally(Expr::val(Decimal::ZERO));

    let alipay_expr = Expr::case(
        build_type_condition("Alipay"),
        Expr::col(AccountColumn::Balance),
    ).finally(Expr::val(Decimal::ZERO));

    let wechat_expr = Expr::case(
        build_type_condition("WeChat"),
        Expr::col(AccountColumn::Balance),
    ).finally(Expr::val(Decimal::ZERO));

    let cloud_quick_pass_expr = Expr::case(
        build_type_condition("CloudQuickPass"),
        Expr::col(AccountColumn::Balance),
    ).finally(Expr::val(Decimal::ZERO));

    let other_expr = Expr::case(
        build_type_condition("Other"),
        Expr::col(AccountColumn::Balance),
    ).finally(Expr::val(Decimal::ZERO));

    // 存储别名与 Expr 的映射（用于后续动态添加列）
    sum_columns.insert("bank_savings_balance".to_string(), bank_savings_expr);
    sum_columns.insert("cash_balance".to_string(), cash_expr);
    sum_columns.insert("credit_card_balance".to_string(), credit_card_expr);
    sum_columns.insert("alipay_balance".to_string(), alipay_expr);
    sum_columns.insert("wechat_balance".to_string(), wechat_expr);
    sum_columns.insert("cloud_quick_pass_balance".to_string(), cloud_quick_pass_expr);
    sum_columns.insert("other_balance".to_string(), other_expr);

    // 构建查询：动态添加计算列（关键修复点）
    let query = AccountEntity::find()
        .select_only() // 仅选择需要的列
        .filter(AccountColumn::IsActive.eq(1)) // 过滤活跃账户
        // 动态添加每个计算列（使用 expr_as 方法）
        .expr_as(sum_columns.remove("bank_savings_balance").unwrap(), "bank_savings_balance")
        .expr_as(sum_columns.remove("cash_balance").unwrap(), "cash_balance")
        .expr_as(sum_columns.remove("credit_card_balance").unwrap(), "credit_card_balance")
        .expr_as(sum_columns.remove("alipay_balance").unwrap(), "alipay_balance")
        .expr_as(sum_columns.remove("wechat_balance").unwrap(), "wechat_balance")
        .expr_as(sum_columns.remove("cloud_quick_pass_balance").unwrap(), "cloud_quick_pass_balance")
        .expr_as(sum_columns.remove("other_balance").unwrap(), "other_balance");

    // 执行聚合查询（确保 AccountBalanceSummary 字段与别名匹配）
    let result = query
        .into_model::<AccountBalanceSummary>()
        .one(db)
        .await?
        .unwrap_or_default();

    Ok(result)
}
    
    /// 自定义排序方法处理 SelectTwo 类型
    fn apply_sort_to_select_two(
        query_builder: SelectTwo<entity::account::Entity, entity::currency::Entity>,
        sort_by: &Option<String>,
        desc: bool,
    ) -> SelectTwo<entity::account::Entity, entity::currency::Entity> {
        if let Some(sort_by) = sort_by {
            // 尝试解析为账户字段
            if let Ok(column) = entity::account::Column::from_str(sort_by) {
                return if desc {
                    query_builder.order_by_desc(column)
                } else {
                    query_builder.order_by_asc(column)
                };
            }

            // 尝试解析为货币字段 (格式: currency.field)
            if let Some(("currency", field)) = sort_by.split_once('.') {
                if let Ok(column) = entity::currency::Column::from_str(field) {
                    return if desc {
                        query_builder.order_by_desc(column)
                    } else {
                        query_builder.order_by_asc(column)
                    };
                } else {
                    info!("currency query failed");
                }
            }
        }
        query_builder
    }
}

// ------------------------------ 服务实例获取 ------------------------------
/// 获取账户服务实例
pub fn get_account_service() -> AccountService {
    AccountService::get_service()
}
