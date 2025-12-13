/// 定时任务执行器
///
/// 负责：
/// - 定时扫描待执行提醒
/// - 批量执行任务
/// - 错误处理和重试
use std::sync::Arc;
use std::time::Duration;
use tokio::time;
use tracing::{error, info};

use super::reminder_scheduler::ReminderScheduler;

/// 执行器配置
#[derive(Debug, Clone)]
pub struct ExecutorConfig {
    /// 扫描间隔（秒）
    pub scan_interval_secs: u64,

    /// 每次扫描的最大任务数
    pub max_tasks_per_scan: usize,

    /// 任务执行超时（秒）
    pub task_timeout_secs: u64,

    /// 失败重试次数
    pub max_retries: u32,
}

impl Default for ExecutorConfig {
    fn default() -> Self {
        Self {
            scan_interval_secs: 60, // 每分钟扫描一次
            max_tasks_per_scan: 50, // 一次最多处理50个任务
            task_timeout_secs: 30,  // 任务执行超时30秒
            max_retries: 3,         // 最多重试3次
        }
    }
}

/// 定时任务执行器
pub struct ReminderExecutor {
    scheduler: Arc<ReminderScheduler>,
    config: ExecutorConfig,
}

impl ReminderExecutor {
    /// 创建新的执行器
    pub fn new(scheduler: Arc<ReminderScheduler>, config: ExecutorConfig) -> Self {
        Self { scheduler, config }
    }

    /// 启动执行器（阻塞运行）
    pub async fn run(&self) {
        info!(
            "🚀 提醒执行器已启动，扫描间隔: {}秒",
            self.config.scan_interval_secs
        );

        let mut interval = time::interval(Duration::from_secs(self.config.scan_interval_secs));

        loop {
            interval.tick().await;

            // 检查调度器是否运行
            let state = self.scheduler.get_state().await;
            if !state.is_running {
                continue;
            }

            // 执行一轮扫描和处理
            if let Err(e) = self.process_round().await {
                error!("❌ 执行器处理失败: {}", e);
            }
        }
    }

    /// 处理一轮任务
    async fn process_round(&self) -> Result<(), String> {
        // 1. 扫描待执行任务
        let tasks = self.scheduler.scan_pending_reminders().await?;

        if tasks.is_empty() {
            return Ok(());
        }

        info!("📋 本轮处理 {} 个任务", tasks.len());

        // 2. 限制任务数量
        let tasks_to_process = tasks
            .into_iter()
            .take(self.config.max_tasks_per_scan)
            .collect::<Vec<_>>();

        // 3. 并发执行任务
        let mut handles = Vec::new();

        for task in tasks_to_process {
            let scheduler = Arc::clone(&self.scheduler);
            let timeout = Duration::from_secs(self.config.task_timeout_secs);

            let handle = tokio::spawn(async move {
                // 带超时的任务执行
                match time::timeout(timeout, scheduler.execute_task(&task)).await {
                    Ok(result) => result,
                    Err(_) => {
                        error!("⏱️ 任务执行超时: {}", task.id);
                        Err(format!("Task execution timeout: {}", task.id))
                    }
                }
            });

            handles.push(handle);
        }

        // 4. 等待所有任务完成
        let results = futures::future::join_all(handles).await;

        // 5. 统计结果
        let mut success_count = 0;
        let mut failure_count = 0;

        for result in results {
            match result {
                Ok(Ok(execution_result)) => {
                    if execution_result.success {
                        success_count += 1;
                    } else {
                        failure_count += 1;
                    }
                }
                Ok(Err(e)) => {
                    error!("任务执行错误: {}", e);
                    failure_count += 1;
                }
                Err(e) => {
                    error!("任务 panic: {:?}", e);
                    failure_count += 1;
                }
            }
        }

        info!(
            "✅ 本轮完成: 成功 {}, 失败 {}",
            success_count, failure_count
        );

        Ok(())
    }

    /// 启动后台执行器（非阻塞）
    pub fn spawn(self) -> tokio::task::JoinHandle<()> {
        tokio::spawn(async move {
            self.run().await;
        })
    }
}

/// 创建并启动执行器
pub fn start_reminder_executor(
    scheduler: Arc<ReminderScheduler>,
    config: Option<ExecutorConfig>,
) -> tokio::task::JoinHandle<()> {
    let executor = ReminderExecutor::new(scheduler, config.unwrap_or_default());
    executor.spawn()
}
