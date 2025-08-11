use chrono::{Local, SecondsFormat};
use log::{Level, Record};
use serde::Serialize;
use std::thread;
use tauri_plugin_log::fern;

/// 日志格式化 trait
pub trait LogFormatter {
    /// 格式化日志记录到输出回调
    fn format(&self, record: &Record, out: fern::FormatCallback);
}

/// 控制台格式化（带图标和颜色）
#[derive(Default)]
pub struct ConsoleFormatter;

impl LogFormatter for ConsoleFormatter {
    fn format(&self, record: &Record, out: fern::FormatCallback) {
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

        let color = match record.level() {
            Level::Error => ansi_term::Colour::Red,
            Level::Warn => ansi_term::Colour::Yellow,
            Level::Info => ansi_term::Colour::Green,
            Level::Debug => ansi_term::Colour::Blue,
            Level::Trace => ansi_term::Colour::Purple,
        };

        out.finish(format_args!(
            "[{}] {} {} [{}:{}] {}",
            Local::now().format("%H:%M:%S%.3f"),
            color.paint(level_icon),
            color.paint(record.level().to_string()),
            module,
            record.line().unwrap_or(0),
            record.args()
        ));
    }
}

/// 性能日志格式化（简化版）
#[derive(Default)]
pub struct PerfFormatter;

impl LogFormatter for PerfFormatter {
    fn format(&self, record: &Record, out: fern::FormatCallback) {
        let level_color = match record.level() {
            Level::Error => ansi_term::Colour::Red,
            Level::Warn => ansi_term::Colour::Yellow,
            Level::Info => ansi_term::Colour::Green,
            Level::Debug => ansi_term::Colour::Blue,
            Level::Trace => ansi_term::Colour::Purple,
        };

        out.finish(format_args!(
            "⚡ [{}] {} | {} | {}",
            Local::now().format("%H:%M:%S%.3f"),
            level_color.paint(record.level().to_string()),
            record
                .module_path()
                .unwrap_or("unknown")
                .replace("perf::", ""),
            record.args()
        ));
    }
}

/// JSON 格式化（结构化输出）
#[derive(Default)]
pub struct JsonFormatter;

impl LogFormatter for JsonFormatter {
    fn format(&self, record: &Record, out: fern::FormatCallback) {
        #[derive(Serialize)]
        struct LogEntry {
            timestamp: String,
            level: String,
            target: String,
            module: String,
            file: String,
            line: u32,
            thread: String,
            thread_id: String,
            message: String,
            app_version: String,
        }

        let entry = LogEntry {
            timestamp: Local::now().to_rfc3339_opts(SecondsFormat::Millis, true),
            level: record.level().to_string(),
            target: record.target().to_string(),
            module: record.module_path().unwrap_or("unknown").to_string(),
            file: record.file().unwrap_or("unknown").to_string(),
            line: record.line().unwrap_or(0),
            thread: thread::current().name().unwrap_or("main").to_string(),
            thread_id: format!("{:?}", thread::current().id()),
            message: record.args().to_string(),
            app_version: env!("CARGO_PKG_VERSION").to_string(),
        };

        let json_str = serde_json::to_string_pretty(&entry).unwrap();
        out.finish(format_args!("{json_str}"));
    }
}
