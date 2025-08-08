use std::sync::Arc;

use common::AppState as CommonAppState;
use money::services::currency::CurrencyService;

#[derive(Clone)]
pub struct ExtendedAppState {
    pub common: CommonAppState,
    pub currency_service: Arc<CurrencyService>,
}
