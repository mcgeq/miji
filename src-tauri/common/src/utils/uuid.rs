use chrono::Utc;
use rand::{Rng, rng};

use super::date::DateUtils;

pub struct McgUuid;

impl McgUuid {
    pub fn uuid(len: usize) -> String {
        let mut fmt = DateUtils::format_date(&Utc::now().naive_utc(), Some("%Y%m%d%H%M%S%.9f"));
        fmt = fmt.replace(".", "");
        if fmt.len() < len {
            for _ in 0..len {
                let rand_str: String = rng().random_range(0..10).to_string();
                fmt.push_str(&rand_str);
            }
        }
        let _ = fmt.split_off(len);
        fmt
    }
}
