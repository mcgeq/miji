use std::sync::Arc;

use common::{
    crud::service::{CrudConverter, GenericCrudService},
    error::MijiResult,
    paginations::Filter,
};
use sea_orm::{ColumnTrait, Condition, IntoActiveModel};
use serde::{Deserialize, Serialize};
use validator::Validate;

use crate::{
    dto::currency::{CreateCurrencyRequest, UpdateCurrencyRequest},
    services::currency_hooks::NoOpHooks,
};

// Filter struct
#[derive(Debug, Validate, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct CurrencyFilter {
    pub code: Option<String>,
    pub locale: Option<String>,
    pub symbol: Option<String>,
}

impl Filter<entity::currency::Entity> for CurrencyFilter {
    fn to_condition(&self) -> Condition {
        let mut condition = Condition::all();
        if let Some(code) = &self.code {
            condition = condition.add(entity::currency::Column::Code.eq(code));
        }
        if let Some(locale) = &self.locale {
            condition = condition.add(entity::currency::Column::Locale.eq(locale));
        }
        if let Some(symbol) = &self.symbol {
            condition = condition.add(entity::currency::Column::Symbol.eq(symbol));
        }
        condition
    }
}

// Converter struct
#[derive(Debug)]
pub struct CurrencyConverter;

impl CrudConverter<entity::currency::Entity, CreateCurrencyRequest, UpdateCurrencyRequest>
    for CurrencyConverter
{
    fn create_to_active_model(
        &self,
        data: CreateCurrencyRequest,
    ) -> MijiResult<entity::currency::ActiveModel> {
        Ok(data.into())
    }

    fn update_to_active_model(
        &self,
        model: entity::currency::Model,
        data: UpdateCurrencyRequest,
    ) -> MijiResult<entity::currency::ActiveModel> {
        let mut active_model = model.into_active_model();
        data.apply_to_model(&mut active_model);
        Ok(active_model)
    }

    fn primary_key_to_string(&self, model: &entity::currency::Model) -> String {
        model.code.clone()
    }

    fn table_name(&self) -> &'static str {
        "currency"
    }
}

// Service definition
pub type CurrencyService = GenericCrudService<
    entity::currency::Entity,
    CurrencyFilter,
    CreateCurrencyRequest,
    UpdateCurrencyRequest,
    CurrencyConverter,
    NoOpHooks,
>;

pub fn get_currency_service() -> CurrencyService {
    CurrencyService::new(
        CurrencyConverter,
        NoOpHooks,
        Arc::new(common::log::logger::NoopLogger),
    )
}
