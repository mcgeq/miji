use chrono::NaiveDate;

pub fn validate_date_time(date: &str) -> Result<(), validator::ValidationError> {
    NaiveDate::parse_from_str(date, "%Y-%m-%dT%H:%M:%S%.f%:z")
        .map(|_| ())
        .map_err(|_| validator::ValidationError::new("invalid_date_format"))
}

pub fn validate_color(color: &str) -> Result<(), validator::ValidationError> {
    if !color.starts_with("0x") || color.len() != 5 && color.len() != 8 {
        return Err(validator::ValidationError::new(
            "颜色格式应为0xRGB或0xRRGGBB",
        ));
    }
    color[2..]
        .chars()
        .all(|c| c.is_ascii_hexdigit())
        .then_some(())
        .ok_or(validator::ValidationError::new("颜色包含非法字符"))
}
