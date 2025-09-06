use chrono_tz::Tz;

pub trait LocalizeModel {
    type Output;

    /// 转换到指定时区
    fn to_local_in(&self, tz: Tz) -> Self::Output;

    /// 默认转成本地时区
    fn to_local(&self) -> Self::Output
    where
        Self: Sized,
    {
        let local_tz: Tz = chrono_tz::Asia::Shanghai; // 失败时默认使用 UTC
        self.to_local_in(local_tz)
    }
}
