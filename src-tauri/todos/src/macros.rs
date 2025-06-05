// -----------------------------------------------------------------------------
//    Copyright (C) 2025 mcge. All rights reserved.
// Author:         mcge
// Email:          <mcgeq@outlook.com>
// File:           macros.rs
// Description:    About Macro
// Create   Date:  2025-06-05 12:14:12
// Last Modified:  2025-06-05 22:42:12
// Modified   By:  mcgeq <mcgeq@outlook.com>
// -----------------------------------------------------------------------------

#[macro_export]
macro_rules! p_set_fields {
    ($active:expr, $param:expr, $should_update:expr, $($field:ident : $type:ty => $set:expr),* $(,)?) => {
        $(
            if let Some(value) = $param.$field.as_ref() {
                $active.$field = Set($set(value.to_string()));
                $should_update = true;
            }
        )*
    };
}

#[macro_export]
macro_rules! set_fields {
    ($active:expr, $param:expr, $should_update:expr, $($field:ident : $type:ty => $set:expr),* $(,)?) => {
        $(
            if let Some(value) = $param.$field {
                $active.$field = Set($set(value));
                $should_update = true;
            }
        )*
    };
}
