#[macro_export]
macro_rules! set_active_value_t {
    // 基础版本：直接赋值 Some(value)
    ($model:expr, $self:expr, $field:ident) => {{
        if let Some(value) = $self.$field {
            $model.$field = ActiveValue::Set(value);
        }
    }};
}

#[macro_export]
macro_rules! set_active_value_opt {
    // 基础版本：直接赋值 Some(value)
    ($model:expr, $self:expr, $field:ident) => {{
        if let Some(value) = $self.$field {
            $model.$field = ActiveValue::Set(Some(value));
        }
    }};
}

// 扩展宏：支持操作符（Eq、Gt、Like 等）
#[macro_export]
macro_rules! add_filter_condition {
    // 参数说明：
    // - $condition: 当前累积的 Condition（可变引用，类型为 &mut Condition）
    // - $self: Filter 结构体实例（&self）
    // - $field: Filter 中的可选字段名（如 name，类型为 &Option<String>）
    // - $column: 对应的 Column 枚举值（如 Column::Name，类型为 Column）
    // - $op: 过滤操作符（FilterOp 枚举值，如 FilterOp::Eq）
    ($condition:expr, $self:expr, $field:ident, $column:expr, $op:expr) => {{
        // 解包 Option<T>，若有值则添加条件
        if let Some(value) = &$self.$field {
            // 根据操作符生成对应的条件表达式
            let expr = match $op {
                FilterOp::Eq => $column.eq(value.clone()),   // 等于操作符
                FilterOp::Gt => $column.gt(value.clone()),   // 大于操作符
                FilterOp::Gte => $column.gte(value.clone()), // 大于等于操作符
                FilterOp::Lt => $column.lt(value.clone()),
                FilterOp::Lte => $column.lte(value.clone()),
                FilterOp::Ne => $column.ne(value.clone()),
                // 其他操作符...
                _ => panic!("不支持的过滤操作符: {:?}", $op), // 处理未知操作符
            };
            // 将条件添加到当前条件集合
            $condition = $condition.add(expr);
        }
    }};
}
