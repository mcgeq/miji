// -----------------------------------------------------------------------------
//    Copyright (C) 2025 mcge. All rights reserved.
// Author:         mcge
// Email:          <mcgeq@outlook.com>
// File:           init.rs
// Description:    About Desktop Initialize
// Create   Date:  2025-06-10 14:57:48
// Last Modified:  2025-06-28 10:41:33
// Modified   By:  mcgeq <mcgeq@outlook.com>
// -----------------------------------------------------------------------------

use chrono::{Local, SecondsFormat};
use common::utils::files::MijiFiles;
use log::{Level, LevelFilter};
use serde_json::json;
use std::env;
use tauri::{Manager, Runtime};
use tauri_plugin_log::{
    Target, TargetKind,
    fern::{
        self,
        colors::{Color, ColoredLevelConfig},
    },
};

pub trait MijiInit {
    fn init_plugin(self) -> Self;
}

impl<R: Runtime> MijiInit for tauri::Builder<R> {
    fn init_plugin(self) -> Self {
        let root_dir = MijiFiles::root_path().unwrap();
        eprintln!("🚀 Miji root directory: {root_dir}");

        // 根据构建配置调整日志级别
        let log_level = if cfg!(debug_assertions) {
            LevelFilter::Debug
        } else {
            env::var("MIJI_LOG_LEVEL")
                .ok()
                .and_then(|level| match level.to_uppercase().as_str() {
                    "TRACE" => Some(LevelFilter::Trace),
                    "DEBUG" => Some(LevelFilter::Debug),
                    "INFO" => Some(LevelFilter::Info),
                    "WARN" => Some(LevelFilter::Warn),
                    "ERROR" => Some(LevelFilter::Error),
                    _ => None,
                })
                .unwrap_or(LevelFilter::Info)
        };

        self.plugin(tauri_plugin_autostart::init(
            tauri_plugin_autostart::MacosLauncher::LaunchAgent,
            Some(vec!["--flag1", "--flag2"]),
        ))
        .plugin(tauri_plugin_vue::Builder::new().path(&root_dir).build())
        .plugin(tauri_plugin_single_instance::init(|app, _args, _cwd| {
            let _ = app
                .get_webview_window("main")
                .expect("no main window")
                .set_focus();
        }))
        .plugin(
            tauri_plugin_log::Builder::default()
                .max_file_size(50 * 1024 * 1024) // 50MB，更合理的文件大小
                .rotation_strategy(tauri_plugin_log::RotationStrategy::KeepAll)
                .targets([
                    // 控制台输出（开发环境）
                    Target::new(TargetKind::Stdout),
                    // Webview 输出
                    Target::new(TargetKind::Webview),
                    // 应用日志文件
                    Target::new(TargetKind::Folder {
                        path: MijiFiles::join(&[&root_dir, "logs", "app"]),
                        file_name: Some("miji-app".to_string()),
                    }),
                    // 错误日志文件（只记录 WARN 及以上级别）
                    Target::new(TargetKind::Folder {
                        path: MijiFiles::join(&[&root_dir, "logs", "errors"]),
                        file_name: Some("miji-errors".to_string()),
                    })
                    .filter(|metadata| metadata.level() <= Level::Warn),
                    // 性能日志文件
                    Target::new(TargetKind::Folder {
                        path: MijiFiles::join(&[&root_dir, "logs", "performance"]),
                        file_name: Some("miji-perf".to_string()),
                    })
                    .filter(|metadata| metadata.target().starts_with("perf::")),
                ])
                .timezone_strategy(tauri_plugin_log::TimezoneStrategy::UseLocal)
                .level(log_level)
                .filter(|metadata| {
                    // 过滤掉噪音日志
                    let target = metadata.target();
                    let level = metadata.level();

                    // 过滤数据库调试日志
                    if target == "sea_orm::driver::sqlx_sqlite" && level == Level::Debug {
                        return false;
                    }

                    // 过滤 hyper 的调试日志
                    if target.starts_with("hyper::") && level == Level::Debug {
                        return false;
                    }

                    // 过滤 tokio 的调试日志
                    if target.starts_with("tokio::") && level == Level::Debug {
                        return false;
                    }

                    // 过滤 wry 的调试日志
                    if target.starts_with("wry::") && level == Level::Debug {
                        return false;
                    }

                    true
                })
                .with_colors(create_custom_color_config())
                .format(enhanced_log_format)
                .build(),
        )
    }
}

/// 创建自定义颜色配置
fn create_custom_color_config() -> ColoredLevelConfig {
    ColoredLevelConfig::new()
        .error(Color::Red)
        .warn(Color::Yellow)
        .info(Color::Green)
        .debug(Color::Blue)
        .trace(Color::Magenta)
}

/// 增强的日志格式化函数
fn enhanced_log_format(
    out: fern::FormatCallback,
    message: &std::fmt::Arguments,
    record: &log::Record,
) {
    let force_json = env::var("MIJI_LOG_JSON")
        .map(|v| v == "1" || v.eq_ignore_ascii_case("true"))
        .unwrap_or(false);

    let is_console_target = record.target() == "console" || record.target() == "webview";
    let is_performance = record.target().starts_with("perf::");

    // 判断输出格式：
    // 1. 如果强制 JSON 模式，全部使用 JSON
    // 2. 如果是性能日志，使用特殊格式
    // 3. 如果是控制台目标，使用彩色格式
    // 4. 其他情况（主要是文件输出），使用 JSON 格式
    if force_json {
        json_log_format_impl(out, message, record);
    } else if is_performance {
        perf_log_format_impl(out, message, record);
    } else if is_console_target {
        console_log_format_impl(out, message, record);
    } else {
        // 通过环境变量来区分是否为终端输出
        let is_terminal_output = env::var("MIJI_TERMINAL_OUTPUT").is_ok();
        if is_terminal_output {
            console_log_format_impl(out, message, record);
        } else {
            json_log_format_impl(out, message, record);
        }
    }
}

/// 控制台日志格式化实现
fn console_log_format_impl(
    out: fern::FormatCallback,
    message: &std::fmt::Arguments,
    record: &log::Record,
) {
    let colors = create_custom_color_config();
    let level_icon = match record.level() {
        Level::Error => "❌",
        Level::Warn => "⚠️",
        Level::Info => "ℹ️",
        Level::Debug => "🐛",
        Level::Trace => "🔍",
    };

    // 简化模块路径显示
    let module = record
        .module_path()
        .unwrap_or("unknown")
        .split("::")
        .last()
        .unwrap_or("unknown");

    // 格式：[时间] 图标 级别 [模块:行号] 消息
    out.finish(format_args!(
        "[{}] {} {} [{}:{}] {}",
        Local::now().format("%H:%M:%S%.3f"),
        level_icon,
        colors.color(record.level()),
        module,
        record.line().unwrap_or(0),
        message
    ));
}

/// JSON 日志格式化实现
fn json_log_format_impl(
    out: fern::FormatCallback,
    message: &std::fmt::Arguments,
    record: &log::Record,
) {
    let log_obj = json!({
        "timestamp": Local::now().to_rfc3339_opts(SecondsFormat::Millis, true),
        "level": record.level().to_string(),
        "target": record.target(),
        "module": record.module_path().unwrap_or("unknown"),
        "file": record.file().unwrap_or("unknown"),
        "line": record.line().unwrap_or(0),
        "thread": std::thread::current().name().unwrap_or("main"),
        "thread_id": format!("{:?}", std::thread::current().id()),
        "message": format!("{}", message),
        "app_version": env!("CARGO_PKG_VERSION"),
    });
    out.finish(format_args!("{}", log_obj));
}

/// 性能日志格式化实现
fn perf_log_format_impl(
    out: fern::FormatCallback,
    message: &std::fmt::Arguments,
    record: &log::Record,
) {
    let colors = create_custom_color_config();
    out.finish(format_args!(
        "⚡ [{}] {} | {} | {}",
        Local::now().format("%H:%M:%S%.3f"),
        colors.color(record.level()),
        record.target().replace("perf::", ""),
        message
    ));
}

// 便利宏定义
#[macro_export]
macro_rules! perf_log {
    ($target:expr, $($arg:tt)*) => {
        log::info!(target: &format!("perf::{}", $target), $($arg)*);
    };
}

#[macro_export]
macro_rules! app_info {
    ($($arg:tt)*) => {
        log::info!(target: "app", $($arg)*);
    };
}

#[macro_export]
macro_rules! app_warn {
    ($($arg:tt)*) => {
        log::warn!(target: "app", $($arg)*);
    };
}

#[macro_export]
macro_rules! app_error {
    ($($arg:tt)*) => {
        log::error!(target: "app", $($arg)*);
    };
}
