#![allow(dead_code)]
// -----------------------------------------------------------------------------
//    Copyright (C) 2025 mcge. All rights reserved.
// Author:         mcge
// Email:          <mcgeq@outlook.com>
// File:           response.rs
// Description:    About Response
// Create   Date:  2025-05-29 08:37:51
// Last Modified:  2025-08-06 18:02:34
// Modified   By:  mcgeq <mcgeq@outlook.com>
// -----------------------------------------------------------------------------

use crate::{business_code::BusinessCode, error::AppError};
use serde::Serialize;

/// 统一 API 响应结构
#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub struct ApiResponse<T: Serialize> {
    pub success: bool,
    pub code: String, // 6 位错误码字符串
    #[serde(skip_serializing_if = "Option::is_none")]
    pub data: Option<T>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub error: Option<ErrorPayload>,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub struct ErrorPayload {
    pub code: String, // 6 位错误码字符串
    pub message: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub details: Option<serde_json::Value>,
    pub description: String,
    pub category: String, // 错误分类字符串
    pub module: String,   // 错误模块字符串
}

impl<T: Serialize> ApiResponse<T> {
    /// 创建成功的响应
    pub fn success(data: T) -> Self {
        Self {
            success: true,
            code: BusinessCode::Success.as_str().to_string(),
            data: Some(data),
            error: None,
        }
    }

    /// 创建空成功的响应
    pub fn empty() -> Self {
        Self {
            success: true,
            code: BusinessCode::Success.as_str().to_string(),
            data: None,
            error: None,
        }
    }

    /// 从错误创建响应
    pub fn from_error(error: AppError) -> Self {
        let inner = error.inner();
        let code = inner.business_code();

        Self {
            success: false,
            code: code.as_str().to_string(),
            data: None,
            error: Some(ErrorPayload {
                code: code.as_str().to_string(),
                message: inner.to_string(),
                details: inner.extra_data(),
                description: code.description().to_string(),
                category: code.category().as_str().to_string(),
                module: code.module().as_str().to_string(),
            }),
        }
    }

    /// 从结果创建响应
    pub fn from_result(result: Result<T, AppError>) -> Self {
        match result {
            Ok(data) => ApiResponse::success(data),
            Err(error) => ApiResponse::from_error(error),
        }
    }
}
