use chrono::{
    DateTime, Datelike, Duration, FixedOffset, Local, NaiveDate, NaiveDateTime, Timelike, Utc,
    Weekday,
};
use chrono_tz::Tz;

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
        Local::now().fixed_offset()
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

    pub fn parse_datetime(
        datetime_str: &str,
        format: Option<&str>,
    ) -> Result<NaiveDateTime, chrono::ParseError> {
        let fmt = format.unwrap_or("%Y-%m-%d %H:%M:%S");
        NaiveDateTime::parse_from_str(datetime_str, fmt)
    }

    pub fn parse_datatime_utc(
        datetime_str: &str,
        format: Option<&str>,
    ) -> Result<DateTime<Utc>, chrono::ParseError> {
        let fmt = format.unwrap_or("%Y-%m-%d %H:%M:%S");
        DateTime::parse_from_str(datetime_str, fmt).map(|dt| dt.with_timezone(&Utc))
    }

    /// 获取本周开始时间（周一）
    pub fn start_of_week(zone: &str) -> NaiveDateTime {
        let now = match zone.to_uppercase().as_str() {
            "U" => Self::current_datetime_utc().naive_utc(),
            _ => Self::current_datetime().naive_local(),
        };

        let weekday = now.weekday();
        let days_from_monday = weekday.num_days_from_monday();
        (now.date() - Duration::days(days_from_monday as i64))
            .and_hms_opt(0, 0, 0)
            .unwrap()
    }

    /// 获取本周末时间（周日）
    pub fn end_of_week(zone: &str) -> NaiveDateTime {
        let start = Self::start_of_week(zone);
        start + Duration::days(6)
    }

    /// 获取月份开始时间
    pub fn start_of_month(zone: &str) -> NaiveDateTime {
        let now = match zone.to_uppercase().as_str() {
            "U" => Self::current_datetime_utc().naive_utc(),
            _ => Self::current_datetime().naive_local(),
        };

        NaiveDate::from_ymd_opt(now.year(), now.month(), 1)
            .unwrap()
            .and_hms_opt(0, 0, 0)
            .unwrap()
    }

    /// 获取月份结束时间
    pub fn end_of_month(zone: &str) -> NaiveDateTime {
        let start = Self::start_of_month(zone);
        let next_month = if start.month() == 12 {
            NaiveDate::from_ymd_opt(start.year() + 1, 1, 1).unwrap()
        } else {
            NaiveDate::from_ymd_opt(start.year(), start.month() + 1, 1).unwrap()
        };

        (next_month - Duration::days(1))
            .and_hms_opt(23, 59, 59)
            .unwrap()
    }

    /// 获取季度开始时间
    pub fn start_of_quarter(zone: &str) -> NaiveDateTime {
        let now = match zone.to_uppercase().as_str() {
            "U" => Self::current_datetime_utc().naive_utc(),
            _ => Self::current_datetime().naive_local(),
        };

        let quarter_start_month = match (now.month() - 1) / 3 {
            0 => 1,
            1 => 4,
            2 => 7,
            _ => 10,
        };

        NaiveDate::from_ymd_opt(now.year(), quarter_start_month, 1)
            .unwrap()
            .and_hms_opt(0, 0, 0)
            .unwrap()
    }

    /// 获取季度结束时间
    pub fn end_of_quarter(zone: &str) -> NaiveDateTime {
        let start = Self::start_of_quarter(zone);
        let next_quarter_start = if start.month() == 10 {
            NaiveDate::from_ymd_opt(start.year() + 1, 1, 1).unwrap()
        } else {
            NaiveDate::from_ymd_opt(start.year(), start.month() + 3, 1).unwrap()
        };

        (next_quarter_start - Duration::days(1))
            .and_hms_opt(23, 59, 59)
            .unwrap()
    }

    /// 获取年份开始时间
    pub fn start_of_year(zone: &str) -> NaiveDateTime {
        let now = match zone.to_uppercase().as_str() {
            "U" => Self::current_datetime_utc().naive_utc(),
            _ => Self::current_datetime().naive_local(),
        };

        NaiveDate::from_ymd_opt(now.year(), 1, 1)
            .unwrap()
            .and_hms_opt(0, 0, 0)
            .unwrap()
    }

    /// 获取年份结束时间
    pub fn end_of_year(zone: &str) -> NaiveDateTime {
        let start = Self::start_of_year(zone);
        NaiveDate::from_ymd_opt(start.year(), 12, 31)
            .unwrap()
            .and_hms_opt(23, 59, 59)
            .unwrap()
    }

    /// 添加天数
    pub fn add_days(dt: NaiveDateTime, days: i64) -> NaiveDateTime {
        dt + Duration::days(days)
    }

    /// 添加工作日（跳过周末）
    pub fn add_workdays(dt: NaiveDateTime, days: i64) -> NaiveDateTime {
        let mut result = dt;
        let mut days_added = 0;
        let direction = if days >= 0 { 1 } else { -1 };
        let abs_days = days.abs();

        while days_added < abs_days {
            result = result + Duration::days(direction);
            let weekday = result.weekday();
            if weekday != Weekday::Sat && weekday != Weekday::Sun {
                days_added += 1;
            }
        }

        result
    }

    /// 计算两个日期之间的天数差
    pub fn days_between(start: NaiveDateTime, end: NaiveDateTime) -> i64 {
        (end.date() - start.date()).num_days()
    }

    /// 计算两个日期之间的工作日差
    pub fn workdays_between(start: NaiveDateTime, end: NaiveDateTime) -> i64 {
        let mut count = 0;
        let mut current = start.date();
        let end_date = end.date();

        while current <= end_date {
            let weekday = current.weekday();
            if weekday != Weekday::Sat && weekday != Weekday::Sun {
                count += 1;
            }
            current = current.succ_opt().unwrap();
        }

        count
    }

    /// 转换时区
    pub fn convert_timezone(
        dt: DateTime<Utc>,
        timezone: &str,
    ) -> Result<DateTime<Tz>, chrono_tz::ParseError> {
        let tz: Tz = timezone.parse()?;
        Ok(dt.with_timezone(&tz))
    }

    /// 获取当前时间戳（毫秒）
    pub fn current_timestamp_millis() -> i64 {
        Utc::now().timestamp_millis()
    }

    /// 获取当前时间戳（秒）
    pub fn current_timestamp() -> i64 {
        Utc::now().timestamp()
    }

    /// 格式化时间戳为日期时间
    pub fn format_timestamp(timestamp: i64, format: Option<&str>) -> String {
        let fmt = Self::get_format(format);

        // 使用推荐的新方法
        let dt_utc = DateTime::from_timestamp(timestamp, 0).unwrap_or_else(|| {
            DateTime::from_timestamp(0, 0).expect("Fallback timestamp should be valid")
        });

        // 如果需要 NaiveDateTime 格式可以使用 dt_utc.naive_utc()
        let naive_dt = dt_utc.naive_utc();

        naive_dt.format(fmt).to_string()
    }

    /// 获取月份名称
    pub fn month_name(month: u32) -> &'static str {
        match month {
            1 => "January",
            2 => "February",
            3 => "March",
            4 => "April",
            5 => "May",
            6 => "June",
            7 => "July",
            8 => "August",
            9 => "September",
            10 => "October",
            11 => "November",
            12 => "December",
            _ => "Invalid Month",
        }
    }

    /// 获取星期名称
    pub fn weekday_name(weekday: Weekday) -> &'static str {
        match weekday {
            Weekday::Mon => "Monday",
            Weekday::Tue => "Tuesday",
            Weekday::Wed => "Wednesday",
            Weekday::Thu => "Thursday",
            Weekday::Fri => "Friday",
            Weekday::Sat => "Saturday",
            Weekday::Sun => "Sunday",
        }
    }

    /// 判断是否为闰年
    pub fn is_leap_year(year: i32) -> bool {
        year % 4 == 0 && (year % 100 != 0 || year % 400 == 0)
    }

    /// 获取月份天数
    pub fn days_in_month(year: i32, month: u32) -> u32 {
        match month {
            1 | 3 | 5 | 7 | 8 | 10 | 12 => 31,
            4 | 6 | 9 | 11 => 30,
            2 => {
                if Self::is_leap_year(year) {
                    29
                } else {
                    28
                }
            }
            _ => 0,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use chrono::NaiveDate;

    #[test]
    fn test_format_date() {
        let dt = NaiveDate::from_ymd_opt(2024, 5, 15)
            .unwrap()
            .and_hms_opt(14, 30, 0)
            .unwrap();
        let formatted = DateUtils::format_date(&dt, Some("%Y-%m-%d %H:%M:%S"));
        assert_eq!("2024-05-15 14:30:00", formatted);
    }

    #[test]
    fn test_parse_datetime() {
        let dt_str = "2024-05-15 14:30:00";
        let dt = DateUtils::parse_datetime(dt_str, None).unwrap();
        assert_eq!(2024, dt.year());
        assert_eq!(5, dt.month());
        assert_eq!(15, dt.day());
        assert_eq!(14, dt.hour());
        assert_eq!(30, dt.minute());
    }

    #[test]
    fn test_start_of_week() {
        let start = DateUtils::start_of_week("L");
        assert_eq!(Weekday::Mon, start.weekday());
        assert_eq!(0, start.hour());
        assert_eq!(0, start.minute());
        assert_eq!(0, start.second());
    }

    #[test]
    fn test_end_of_month() {
        let end = DateUtils::end_of_month("L");
        // 对于 5 月，结束日期应该是 31 日
        assert_eq!(31, end.day());
        assert_eq!(23, end.hour());
        assert_eq!(59, end.minute());
        assert_eq!(59, end.second());
    }

    #[test]
    fn test_add_workdays() {
        let friday = NaiveDate::from_ymd_opt(2024, 5, 17)
            .unwrap()
            .and_hms_opt(9, 0, 0)
            .unwrap();

        // 添加 1 个工作日（跳过周末）
        let next_monday = DateUtils::add_workdays(friday, 1);
        assert_eq!(19, next_monday.day()); // 5 月 19 日是周日，但 19+1=20 日周一

        // 添加 3 个工作日（跳过周末）
        let next_thursday = DateUtils::add_workdays(friday, 3);
        assert_eq!(22, next_thursday.day()); // 5 月 22 日周三
    }

    #[test]
    fn test_workdays_between() {
        let start = NaiveDate::from_ymd_opt(2024, 5, 13) // 周一
            .unwrap()
            .and_hms_opt(9, 0, 0)
            .unwrap();

        let end = NaiveDate::from_ymd_opt(2024, 5, 17) // 周五
            .unwrap()
            .and_hms_opt(17, 0, 0)
            .unwrap();

        let workdays = DateUtils::workdays_between(start, end);
        assert_eq!(5, workdays); // 周一到周五共 5 个工作日
    }

    #[test]
    fn test_days_in_month() {
        // 非闰年 2 月
        assert_eq!(28, DateUtils::days_in_month(2023, 2));
        // 闰年 2 月
        assert_eq!(29, DateUtils::days_in_month(2024, 2));
        // 4 月
        assert_eq!(30, DateUtils::days_in_month(2024, 4));
        // 1 月
        assert_eq!(31, DateUtils::days_in_month(2024, 1));
    }
}
