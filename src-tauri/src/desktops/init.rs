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
use serde_json::json;
use std::{
    env,
    fs::{self, OpenOptions},
    path::{Path, PathBuf},
};
use tauri::{Manager, Runtime};
use tracing::field::Field;
use tracing::{Event, Subscriber};
use tracing_subscriber::{
    EnvFilter,
    fmt::{self, FormatEvent, format::Writer, time::ChronoLocal},
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
        // 配置 pinia store 路径
        let pinia_store_path = format!("{}/stores", root_dir);

        init_tracing_subscriber();
        // 清理 30 天前日志
        let _ = cleanup_old_logs(Path::new(&root_dir), "logs/tracing", 30);

        // 系统托盘将在setup阶段创建

        // 根据构建配置调整日志级别

        self.plugin(tauri_plugin_autostart::init(
            tauri_plugin_autostart::MacosLauncher::LaunchAgent,
            Some(vec!["--flag1", "--flag2"]),
        ))
        .plugin(tauri_plugin_single_instance::init(|app, _args, _cwd| {
            let _ = app
                .get_webview_window("main")
                .expect("no main window")
                .set_focus();
        }))
        .plugin(
            tauri_plugin_pinia::Builder::new()
                .path(&pinia_store_path)
                .build(),
        )
        .plugin(tauri_plugin_log::Builder::default().skip_logger().build())
    }
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
            "timestamp": Local::now().to_rfc3339_opts(SecondsFormat::Nanos, false),
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
    let filter_layer =
        EnvFilter::try_from_default_env().unwrap_or_else(|_| EnvFilter::new("info,sqlx=warn"));

    // 彩色控制台输出
    let console_layer = fmt::layer()
        .with_target(true)
        .with_file(true)
        .with_line_number(true)
        .with_ansi(true)
        .with_writer(std::io::stdout)
        .with_timer(ChronoLocal::rfc_3339());

    // JSON 文件输出，放在 logs/tracing/2025-08-11/app.log
    let root_dir = MijiFiles::root_path().unwrap_or_else(|_| ".".into());

    // 普通日志文件
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

    // 错误日志单独文件
    let error_log_path = today_log_path(&root_dir, &["logs", "tracing"], "error.log");
    let error_file = OpenOptions::new()
        .create(true)
        .append(true)
        .open(&error_log_path)
        .expect("无法打开错误日志文件");
    let error_layer = fmt::layer()
        .with_ansi(false)
        .event_format(JsonLogFormatter)
        .with_writer(move || error_file.try_clone().expect("无法克隆错误日志文件句柄"))
        .with_filter(EnvFilter::new("error"));

    Registry::default()
        .with(filter_layer)
        .with(console_layer)
        .with(file_layer)
        .with(error_layer)
        .try_init()
        .ok(); // 避免重复初始化冲突
}
