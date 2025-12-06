# 通知调度器配置 - 快速参考

## 📋 文档导航

- **[完整设计文档](./NOTIFICATION_SCHEDULER_CONFIG.md)** - 详细的架构设计和实现方案（52KB）
- **[实施总结](./NOTIFICATION_SCHEDULER_SUMMARY.md)** - 核心要点和实施步骤（18KB）
- **[本文档]** - 快速参考和常用代码（5KB）

---

## 🎯 核心概念（3分钟速览）

### 改进目标

**将硬编码的调度时间抽取为可配置项**

```rust
// ❌ 之前：硬编码
Duration::from_secs(60)  // 无法调整

// ✅ 之后：数据驱动
config.interval  // 用户可自定义
```

### 数据库表

**scheduler_config** - 调度器配置表

```sql
CREATE TABLE scheduler_config (
    serial_num VARCHAR(38) PRIMARY KEY,
    user_serial_num VARCHAR(38),        -- NULL=全局配置
    task_type VARCHAR(50) NOT NULL,     -- 任务类型
    enabled BOOLEAN NOT NULL,           -- 是否启用
    interval_seconds INTEGER NOT NULL,  -- 执行间隔
    platform VARCHAR(20),               -- desktop/mobile
    battery_threshold INTEGER,          -- 电量阈值
    active_hours_start TIME,            -- 活动时段
    active_hours_end TIME,
    -- ...更多字段
);
```

### 配置优先级

```
用户配置 → 平台配置 → 全局配置 → 默认配置
```

---

## 🔧 6种任务类型

| 任务类型 | 桌面端 | 移动端 | 说明 |
|---------|--------|--------|------|
| TransactionProcess | 2小时 | 2小时 | 交易处理 |
| TodoAutoCreate | 2小时 | 2小时 | 待办自动创建 |
| TodoReminderCheck | 1分钟 | 5分钟 | 待办提醒检查 |
| BillReminderCheck | 1分钟 | 5分钟 | 账单提醒检查 |
| PeriodReminderCheck | 1天 | 1天 | 经期提醒检查 |
| BudgetAutoCreate | 2小时 | 2小时 | 预算自动创建 |

---

## 💻 常用代码片段

### 后端：查询配置

```rust
use common::services::scheduler_config_service::SchedulerConfigService;

// 创建服务
let service = SchedulerConfigService::new();

// 获取配置（带缓存）
let config = service
    .get_config(&db, "TodoReminderCheck", Some(user_id))
    .await?;

// 使用配置
if config.enabled {
    let interval = config.interval;  // Duration
    // 启动任务...
}
```

### 后端：更新配置

```rust
use entity::scheduler_config;

// 更新配置
service.update_config(&db, config_model).await?;

// 清除缓存
service.clear_cache().await;
```

### 前端：获取配置列表

```typescript
import { schedulerApi } from '@/api/scheduler';

// 获取所有配置
const configs = await schedulerApi.list();

// 获取单个配置
const config = await schedulerApi.getConfig('TodoReminderCheck');
```

### 前端：更新配置

```typescript
// 更新配置
await schedulerApi.update({
  ...config,
  intervalSeconds: 120,  // 修改为2分钟
  enabled: true,
});
```

---

## 🗄️ 数据库操作

### 查询全局配置

```sql
SELECT * FROM scheduler_config
WHERE user_serial_num IS NULL
  AND task_type = 'TodoReminderCheck'
  AND platform = 'desktop';
```

### 查询用户配置

```sql
SELECT * FROM scheduler_config
WHERE user_serial_num = 'user-001'
  AND task_type = 'TodoReminderCheck';
```

### 插入默认配置

```sql
INSERT INTO scheduler_config (
    serial_num, task_type, platform, enabled,
    interval_seconds, battery_threshold,
    created_at, updated_at
) VALUES (
    'default-TodoReminderCheck-desktop',
    'TodoReminderCheck', 'desktop', true,
    60, 20,
    CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
)
ON CONFLICT (serial_num) DO NOTHING;
```

---

## 📱 移动端优化

### 电量检查

```rust
#[cfg(any(target_os = "android", target_os = "ios"))]
{
    if let Some(threshold) = config.battery_threshold {
        if battery_level() < threshold {
            continue;  // 跳过任务
        }
    }
}
```

### 网络检查

```rust
// 需要网络
if config.network_required && !has_network() {
    continue;
}

// 仅Wi-Fi
if config.wifi_only && !is_wifi() {
    continue;
}
```

### 活动时段检查

```rust
if let Some((start, end)) = config.active_hours {
    let now = chrono::Local::now().time();
    if now < start || now > end {
        continue;  // 不在活动时段
    }
}
```

---

## 🎨 前端界面代码

### 基本结构

```vue
<template>
  <div class="task-item">
    <!-- 标题 -->
    <div class="task-header">
      <Switch v-model="config.enabled" />
      <span>{{ taskLabel }}</span>
      <Badge>{{ config.platform }}</Badge>
    </div>

    <!-- 配置项 -->
    <div v-if="config.enabled">
      <!-- 间隔滑块 -->
      <Slider
        v-model="config.intervalSeconds"
        :min="60"
        :max="3600"
        @change="updateConfig"
      />
      
      <!-- 活动时段 -->
      <Input type="time" v-model="config.activeHoursStart" />
      <Input type="time" v-model="config.activeHoursEnd" />
      
      <!-- 移动端优化 -->
      <Input v-model="config.batteryThreshold" type="number" />
      <Checkbox v-model="config.networkRequired" />
    </div>
  </div>
</template>
```

### 更新配置

```typescript
async function updateConfig(config: SchedulerConfig) {
  try {
    await schedulerApi.update(config);
    toast.success('配置已更新');
  } catch (error) {
    toast.error('更新失败');
  }
}
```

---

## 🔍 调试技巧

### 查看当前配置

```bash
# SQLite 命令行
sqlite3 miji.db "SELECT * FROM scheduler_config WHERE task_type = 'TodoReminderCheck';"
```

### 后端日志

```rust
tracing::debug!("加载配置: task={}, user={}", task_type, user_id);
tracing::info!("任务启动: interval={:?}", config.interval);
```

### 前端日志

```typescript
console.log('配置列表:', configs);
console.log('当前间隔:', formatInterval(config.intervalSeconds));
```

---

## ⚡ 性能优化

### 配置缓存

```rust
// 缓存键格式: task_type:user_id
let cache_key = format!("{}:{}", task_type, user_id.unwrap_or("global"));

// 读取缓存
if let Some(config) = cache.get(&cache_key) {
    return Ok(config.clone());
}
```

### 缓存失效

```rust
// 配置更新后清除
pub async fn clear_cache(&self) {
    self.cache.write().await.clear();
}
```

---

## 🚨 常见问题

### Q1: 修改配置后没生效？

**A**: 需要清除缓存或重启调度器

```rust
service.clear_cache().await;
```

### Q2: 移动端如何检测电量？

**A**: 需要平台特定API（待实现）

```rust
#[cfg(target_os = "android")]
fn battery_level() -> i32 {
    // TODO: 调用Android API
    100
}
```

### Q3: 如何添加新任务类型？

**A**: 3步骤

1. 在 `SchedulerTask` 枚举中添加
2. 在默认配置中添加
3. 在调度器中实现执行逻辑

---

## 📚 相关命令

### Tauri Commands

```rust
// 获取配置
scheduler_config_get(task_type, user_id) -> SchedulerConfig

// 获取列表
scheduler_config_list(user_id) -> Vec<SchedulerConfig>

// 更新配置
scheduler_config_update(config) -> ()

// 重置默认
scheduler_config_reset(task_type, user_id) -> ()
```

### 前端API

```typescript
// src/api/scheduler.ts
export const schedulerApi = {
  getConfig(taskType, userId),
  list(userId),
  update(config),
  reset(taskType, userId),
}
```

---

## 🎯 默认值速查

| 配置项 | 桌面端 | 移动端 |
|--------|--------|--------|
| 提醒检查间隔 | 60秒 | 300秒 |
| 处理任务间隔 | 7200秒 | 7200秒 |
| 最大重试次数 | 3次 | 3次 |
| 重试延迟 | 60秒 | 60秒 |
| 电量阈值 | - | 20% |
| 优先级 | 5 | 5 |

---

## 🔗 文档链接

### 核心文档
- [完整设计文档](./NOTIFICATION_SCHEDULER_CONFIG.md) - 52KB
- [实施总结](./NOTIFICATION_SCHEDULER_SUMMARY.md) - 18KB

### 相关文档
- [统一通知服务](./UNIFIED_NOTIFICATION_SERVICE_DESIGN.md)
- [通知系统分析](./NOTIFICATION_SYSTEM_ANALYSIS.md)
- [Android配置](./ANDROID_NOTIFICATION_CONFIG.md)
- [iOS配置](./IOS_NOTIFICATION_CONFIG.md)

---

## 📝 实施检查清单

### 数据库层 ✅
- [x] 创建迁移文件
- [x] 添加到 lib.rs
- [x] 添加到 schema.rs
- [ ] 运行迁移测试

### 后端层 ⏳
- [ ] Entity 定义
- [ ] SchedulerConfigService
- [ ] 更新 SchedulerManager
- [ ] Tauri Commands

### 前端层 ⏳
- [ ] 类型定义
- [ ] API 封装
- [ ] 设置组件
- [ ] UI 集成

---

**快速参考版本**: v1.0  
**最后更新**: 2025-12-06
