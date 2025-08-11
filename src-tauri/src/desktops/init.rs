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

use chrono::{Datelike, Local, NaiveDate, SecondsFormat, TimeZone};
use common::utils::files::MijiFiles;
use log::{Level, LevelFilter};
use serde_json::json;
use std::{
    env,
    fs::{self, OpenOptions},
    path::{Path, PathBuf},
};
use tauri::{Manager, Runtime};
use tauri_plugin_log::{
    Target, TargetKind,
    fern::{
        self,
        colors::{Color, ColoredLevelConfig},
    },
};
use tracing::field::Field;
use tracing::{Event, Subscriber};
use tracing_subscriber::{
    EnvFilter,
    fmt::{self, FormatEvent, format::Writer},
    layer::SubscriberExt,
    prelude::*,
    registry::{LookupSpan, Registry},
};

pub trait MijiInit {
    fn init_plugin(self) -> Self;
}

impl<R: Runtime> MijiInit for tauri::Builder<R> {
    fn init_plugin(self) -> Self {
        let root_dir = MijiFiles::root_path().unwrap();
        eprintln!("🚀 Miji root directory: {root_dir}");
        init_tracing_subscriber();
        // 清理 30 天前日志
        let _ = cleanup_old_logs(Path::new(&root_dir), "logs/tracing", 30);

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
                    Target::new(TargetKind::Stdout),
                    Target::new(TargetKind::Webview),
                    Target::new(TargetKind::Folder {
                        path: MijiFiles::join(&[&root_dir, "logs", "app"]),
                        file_name: Some("miji-app".to_string()),
                    }),
                    Target::new(TargetKind::Folder {
                        path: MijiFiles::join(&[&root_dir, "logs", "errors"]),
                        file_name: Some("miji-errors".to_string()),
                    })
                    .filter(|metadata| metadata.level() <= Level::Warn),
                    Target::new(TargetKind::Folder {
                        path: MijiFiles::join(&[&root_dir, "logs", "performance"]),
                        file_name: Some("miji-perf".to_string()),
                    })
                    .filter(|metadata| metadata.target().starts_with("perf::")),
                ])
                .timezone_strategy(tauri_plugin_log::TimezoneStrategy::UseLocal)
                .level(log_level)
                .filter(|metadata| {
                    let target = metadata.target();
                    let level = metadata.level();

                    if target == "sea_orm::driver::sqlx_sqlite" && level == Level::Debug {
                        return false;
                    }
                    if target.starts_with("hyper::") && level == Level::Debug {
                        return false;
                    }
                    if target.starts_with("tokio::") && level == Level::Debug {
                        return false;
                    }
                    if target.starts_with("wry::") && level == Level::Debug {
                        return false;
                    }
                    true
                })
                .with_colors(create_custom_color_config())
                .format(enhanced_log_format)
                .skip_logger()
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

    if force_json {
        json_log_format_impl(out, message, record);
    } else if is_performance {
        perf_log_format_impl(out, message, record);
    } else if is_console_target {
        console_log_format_impl(out, message, record);
    } else {
        let is_terminal_output = env::var("MIJI_TERMINAL_OUTPUT").is_ok();
        if is_terminal_output {
            console_log_format_impl(out, message, record);
        } else {
            json_log_format_impl(out, message, record);
        }
    }
}

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

    let module = record
        .module_path()
        .unwrap_or("unknown")
        .split("::")
        .last()
        .unwrap_or("unknown");

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
    out.finish(format_args!("{log_obj}"));
}

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

// ==== tracing 部分 ====

struct JsonLogFormatter;

impl<S, N> FormatEvent<S, N> for JsonLogFormatter
where
    S: Subscriber + for<'a> LookupSpan<'a>,
    N: for<'a> fmt::FormatFields<'a> + 'static,
{
    fn format_event(
        &self,
        _ctx: &fmt::FmtContext<'_, S, N>,
        mut writer: Writer<'_>,
        event: &Event<'_>,
    ) -> std::fmt::Result {
        let mut fields_map = serde_json::Map::new();
        event.record(&mut |field: &Field, value: &dyn std::fmt::Debug| {
            fields_map.insert(field.name().to_string(), json!(format!("{:?}", value)));
        });

        let meta = event.metadata();
        let log_obj = json!({
            "timestamp": Local::now().to_rfc3339_opts(SecondsFormat::Millis, true),
            "level": meta.level().to_string(),
            "target": meta.target(),
            "module": meta.module_path().unwrap_or("unknown"),
            "file": meta.file().unwrap_or("unknown"),
            "line": meta.line().unwrap_or(0),
            "thread": std::thread::current().name().unwrap_or("main"),
            "thread_id": format!("{:?}", std::thread::current().id()),
            "message": fields_map.get("message").cloned().unwrap_or_else(|| json!("")),
            "app_version": env!("CARGO_PKG_VERSION"),
        });

        writeln!(writer, "{log_obj}")
    }
}

/// 生成当天日志文件路径并创建目录
fn today_log_path(root: &str, segments: &[&str], file_name: &str) -> PathBuf {
    let today = Local::now();
    let date_dir = format!(
        "{:04}-{:02}-{:02}",
        today.year(),
        today.month(),
        today.day()
    );
    let mut path = PathBuf::from(root);
    for seg in segments {
        path.push(seg);
    }
    path.push(date_dir);
    fs::create_dir_all(&path).expect("创建日志目录失败");
    path.push(file_name);
    path
}
fn should_remove_log_dir(name: &str, threshold: chrono::DateTime<Local>) -> bool {
    if let Ok(naive_date) = NaiveDate::parse_from_str(name, "%Y-%m-%d")
        && let Some(naive_datetime) = naive_date.and_hms_opt(0, 0, 0)
        && let Some(date_time) = Local.from_local_datetime(&naive_datetime).single()
    {
        return date_time < threshold;
    }
    false
}

fn cleanup_old_logs(root_dir: &Path, relative_path: &str, days: i64) -> std::io::Result<()> {
    let log_dir = root_dir.join(relative_path);
    let threshold = Local::now() - chrono::Duration::days(days);

    for entry in fs::read_dir(&log_dir)? {
        let entry = entry?;
        let path = entry.path();

        if path.is_dir()
            && path
                .file_name()
                .and_then(|os| os.to_str())
                .is_some_and(|name| should_remove_log_dir(name, threshold))
        {
            println!("Removing old log directory: {path:?}");
            let _ = fs::remove_dir_all(&path);
        }
    }

    Ok(())
}

pub fn init_tracing_subscriber() {
    let filter_layer = EnvFilter::try_from_default_env().unwrap_or_else(|_| EnvFilter::new("info"));

    // 彩色控制台输出
    let console_layer = fmt::layer()
        .with_target(true)
        .with_file(true)
        .with_line_number(true)
        .with_ansi(true)
        .with_writer(std::io::stdout);

    // JSON 文件输出，放在 logs/tracing/2025-08-11/app.log
    let root_dir = MijiFiles::root_path().unwrap_or_else(|_| ".".into());
    let log_file_path = today_log_path(&root_dir, &["logs", "tracing"], "app.log");
    let file = OpenOptions::new()
        .create(true)
        .append(true)
        .open(&log_file_path)
        .expect("无法打开日志文件");
    let file_layer = fmt::layer()
        .with_ansi(false)
        .event_format(JsonLogFormatter)
        .with_writer(move || file.try_clone().expect("无法克隆日志文件句柄"));

    Registry::default()
        .with(filter_layer)
        .with(console_layer)
        .with(file_layer)
        .try_init()
        .ok(); // 避免重复初始化冲突
}
