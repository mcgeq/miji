use common::AppState as CommonAppState;

#[derive(Debug, Clone)]
pub struct ExtendedAppState {
    pub common: CommonAppState,
}
