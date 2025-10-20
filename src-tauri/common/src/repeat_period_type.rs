use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "PascalCase")]
pub enum RepeatPeriodType {
    None,
    Daily,
    Weekly,
    Monthly,
    Yearly,
    Custom,
}
