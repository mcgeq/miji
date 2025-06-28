use chrono::{DateTime, Duration, FixedOffset, Local, NaiveDateTime, Timelike, Utc};

#[derive(Debug, Clone)]
pub struct DateUtils;

#[allow(dead_code)]
impl DateUtils {
    // 获取当前 UTC 时间
    pub fn current_datetime() -> DateTime<Local> {
        Local::now()
    }

    pub fn current_datetime_utc() -> DateTime<Utc> {
        Utc::now()
    }

    pub fn current_datetime_local_fixed() -> DateTime<FixedOffset> {
        Utc::now().fixed_offset()
    }

    pub fn datetime_local_fixed(datetime: Option<NaiveDateTime>) -> DateTime<FixedOffset> {
        if let Some(n) = datetime {
            n.and_utc().fixed_offset()
        } else {
            Self::end_of_today("L").and_utc().fixed_offset()
        }
    }

    pub fn local_to_utc(local_time: DateTime<Local>) -> DateTime<Utc> {
        local_time.with_timezone(&Utc)
    }

    pub fn utc_to_local(utc_time: DateTime<Utc>) -> DateTime<Local> {
        utc_time.with_timezone(&Local)
    }

    pub fn end_of_today(zone: &str) -> NaiveDateTime {
        match zone.to_uppercase().as_str() {
            "U" => {
                let today = DateUtils::current_datetime_utc().naive_utc().date();
                today.and_hms_opt(23, 59, 59).unwrap()
            }
            _ => {
                let today = DateUtils::current_datetime().naive_local().date();
                today.and_hms_opt(23, 59, 59).unwrap()
            }
        }
    }

    pub fn end_of_today_precise(zone: &str) -> NaiveDateTime {
        match zone.to_uppercase().as_str() {
            "U" => {
                let today = DateUtils::current_datetime_utc().naive_utc().date();
                today.and_hms_micro_opt(23, 59, 59, 999_999).unwrap()
            }
            _ => {
                let today = DateUtils::current_datetime().naive_local().date();
                today.and_hms_micro_opt(23, 59, 59, 999_999).unwrap()
            }
        }
    }

    fn get_format(format: Option<&str>) -> &str {
        format.unwrap_or("%Y-%m-%d")
    }
    // 将字符串转换为日期
    // pub fn parse_date(date_str: &str, format: Option<&str>) -> MijiResult<NaiveDate> {
    //     let fmt = Self::get_format(format);
    //     NaiveDate::parse_from_str(date_str, fmt).map_err(|e| {
    //         ReqParamSnafu {
    //             code: BusinessCode::InvalidParameter,
    //             message: format!("{e}"),
    //         }
    //         .build()
    //     })
    // }

    // 格式日期为字符串
    pub fn format_date(date: &NaiveDateTime, format: Option<&str>) -> String {
        let fmt = Self::get_format(format);
        date.format(fmt).to_string()
    }

    // 当前日期 - 1
    pub fn min_one_day(format: Option<&str>) -> String {
        let t = Self::current_datetime();
        let hour = t.hour();
        let result_date: DateTime<Local> = if hour <= 9 {
            t - Duration::days(1)
        } else if hour >= 15 {
            t
        } else {
            t - Duration::days(1)
        };
        Self::format_date(&result_date.naive_local(), format)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_format_date() {
        let m = DateUtils::format_date(&Local::now().naive_local(), Some("%Y-%m-%d %H:%M:%S%.6f"));
        assert_eq!("2024-11-12 18:10:23".to_string(), m);
    }
}
