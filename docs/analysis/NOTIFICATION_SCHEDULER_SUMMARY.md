# 通知系统调度器可配置方案 - 实施总结

## 📋 概述

本方案将 Miji 项目中硬编码的定时任务调度时间抽取为可配置项，存储到数据库中，并提供前端界面供用户自定义调整。

**文档日期**: 2025-12-06  
**设计文档**: [NOTIFICATION_SCHEDULER_CONFIG.md](./NOTIFICATION_SCHEDULER_CONFIG.md)

---

## 🎯 核心改进

### 当前问题

```rust
// ❌ 硬编码在代码中
impl SchedulerTask {
    pub fn interval(&self) -> Duration {
        match self {
            Self::TodoNotification => Duration::from_secs(60),  // 无法调整
            Self::BilReminder => Duration::from_secs(60),       // 无法调整
            // ...
        }
    }
}
```

### 改进方案

```rust
// ✅ 从数据库读取，用户可自定义
let config = config_service
    .get_config(&db, "TodoReminderCheck", user_id)
    .await?;

let interval = config.interval;  // 用户自定义值
let enabled = config.enabled;    // 用户可开关
```

---

## 🏗️ 系统架构

```
┌─────────────────────────────────────────────────┐
│          前端配置界面 (Vue)                      │
│  - 滑块调整间隔时间                               │
│  - 开关控制任务启用                               │
│  - 时间段设置（工作时间）                         │
│  - 移动端优化（电量/网络）                        │
└───────────────────┬─────────────────────────────┘
                    │ Tauri Commands
                    ↓
┌─────────────────────────────────────────────────┐
│      SchedulerConfigService (后端)               │
│  - 配置查询（带缓存）                             │
│  - 优先级: 用户 > 平台 > 全局 > 默认              │
│  - 配置更新                                       │
└───────────────────┬─────────────────────────────┘
                    │
                    ↓
┌─────────────────────────────────────────────────┐
│      scheduler_config 表 (SQLite)               │
│  - 全局配置（管理员）                             │
│  - 用户配置（个性化）                             │
│  - 平台特定（desktop/mobile）                    │
└───────────────────┬─────────────────────────────┘
                    │
                    ↓
┌─────────────────────────────────────────────────┐
│      SchedulerManager (调度器)                   │
│  - 动态加载配置                                   │
│  - 条件执行（电量/网络/时段）                     │
│  - 6种定时任务                                    │
└─────────────────────────────────────────────────┘
```

---

## 📊 数据库设计

### scheduler_config 表

| 字段 | 类型 | 说明 | 示例 |
|------|------|------|------|
| serial_num | VARCHAR(38) | 主键 | uuid-1 |
| user_serial_num | VARCHAR(38) | 用户ID（NULL=全局） | user-001 |
| task_type | VARCHAR(50) | 任务类型 | TodoReminderCheck |
| enabled | BOOLEAN | 是否启用 | true |
| interval_seconds | INTEGER | 执行间隔（秒） | 60 |
| platform | VARCHAR(20) | 平台限定 | desktop/mobile |
| battery_threshold | INTEGER | 电量阈值 | 20 |
| active_hours_start | TIME | 活动时段开始 | 08:00:00 |
| active_hours_end | TIME | 活动时段结束 | 22:00:00 |
| ... | ... | ... | ... |

### 任务类型

1. **TransactionProcess** - 交易处理（2小时）
2. **TodoAutoCreate** - 待办自动创建（2小时）
3. **TodoReminderCheck** - 待办提醒检查（1分钟/5分钟）
4. **BillReminderCheck** - 账单提醒检查（1分钟/5分钟）
5. **PeriodReminderCheck** - 经期提醒检查（1天）
6. **BudgetAutoCreate** - 预算自动创建（2小时）

### 配置优先级

```
用户配置 (最高优先级)
    ↓
平台配置 (desktop/mobile/android/ios)
    ↓
全局配置 (管理员设置)
    ↓
默认配置 (代码兜底)
```

---

## 🔧 核心功能

### 1. 可调整执行间隔

**桌面端默认**:
- 提醒类任务: 1分钟
- 处理类任务: 2小时
- 健康类任务: 1天

**移动端默认**:
- 提醒类任务: 5分钟（省电）
- 处理类任务: 2小时
- 健康类任务: 1天

**用户可调整范围**:
- 提醒类: 1分钟 - 1小时
- 处理类: 5分钟 - 24小时

### 2. 任务开关控制

```typescript
// 用户可随时禁用某个任务
{
  taskType: 'TodoReminderCheck',
  enabled: false,  // ✅ 禁用待办提醒
}
```

### 3. 活动时段限制

```typescript
// 仅在工作时间执行
{
  activeHoursStart: '08:00:00',
  activeHoursEnd: '22:00:00',
}
```

### 4. 移动端智能优化

**电量感知**:
```typescript
{
  batteryThreshold: 20,  // 电量低于20%时暂停非紧急任务
}
```

**网络感知**:
```typescript
{
  networkRequired: true,  // 需要网络连接
  wifiOnly: true,         // 仅Wi-Fi下执行
}
```

### 5. 配置缓存

```rust
// 减少数据库查询，提升性能
cache: Arc<RwLock<HashMap<String, SchedulerConfig>>>
```

---

## 📱 前端界面设计

### 设置页面布局

```vue
<template>
  <div class="scheduler-settings">
    <!-- 任务卡片 -->
    <div class="task-item" v-for="config in configs">
      <!-- 标题栏 -->
      <div class="task-header">
        <Switch v-model="config.enabled" />
        <span>待办提醒检查</span>
        <Badge>desktop</Badge>
        <Button>重置默认</Button>
      </div>

      <!-- 配置项 -->
      <div class="task-config" v-if="config.enabled">
        <!-- 执行间隔滑块 -->
        <Slider
          v-model="config.intervalSeconds"
          :min="60"
          :max="3600"
          :step="60"
        />
        <span>{{ formatInterval(config.intervalSeconds) }}</span>

        <!-- 活动时段 -->
        <Switch v-model="activeHoursEnabled" />
        <Input type="time" v-model="config.activeHoursStart" />
        <Input type="time" v-model="config.activeHoursEnd" />

        <!-- 移动端优化 -->
        <div v-if="isMobile">
          <Input v-model="config.batteryThreshold" type="number" />
          <Checkbox v-model="config.networkRequired">需要网络</Checkbox>
          <Checkbox v-model="config.wifiOnly">仅Wi-Fi</Checkbox>
        </div>

        <!-- 重试策略 -->
        <Input v-model="config.maxRetryCount" />
        <Input v-model="config.retryDelaySeconds" />
      </div>
    </div>
  </div>
</template>
```

### 界面特性

- ✅ 实时预览调整效果
- ✅ 滑块选择间隔时间
- ✅ 直观的开关控制
- ✅ 平台标识显示
- ✅ 一键重置默认

---

## 🚀 实施步骤

### Phase 1: 数据库 (已完成 ✅)

- [x] 设计表结构
- [x] 创建迁移文件 `m20251206_044_create_scheduler_config.rs`
- [x] 定义默认配置数据
- [ ] 运行迁移测试

### Phase 2: 后端服务 (待实施)

- [ ] 创建 Entity `scheduler_config.rs`
- [ ] 实现 `SchedulerConfigService`
  - 配置查询（带优先级）
  - 配置缓存
  - 配置更新
- [ ] 更新 `SchedulerManager`
  - 从数据库读取配置
  - 条件执行逻辑
  - 移动端优化
- [ ] Tauri Commands
  - `scheduler_config_get`
  - `scheduler_config_list`
  - `scheduler_config_update`
  - `scheduler_config_reset`

### Phase 3: 前端界面 (待实施)

- [ ] 类型定义 `scheduler.ts`
- [ ] API 封装 `scheduler.ts`
- [ ] 设置组件 `SchedulerSettings.vue`
- [ ] 集成到设置页面

### Phase 4: 移动端优化 (待实施)

- [ ] 电量检测实现
- [ ] 网络状态检测
- [ ] Wi-Fi 检测

### Phase 5: 测试和文档 (待实施)

- [ ] 单元测试
- [ ] 集成测试
- [ ] 用户文档
- [ ] API 文档

---

## 📈 效果预期

### 用户体验提升

| 功能 | 之前 | 之后 | 提升 |
|------|------|------|------|
| 调整检查频率 | ❌ 不支持 | ✅ 滑块调整 | +100% |
| 禁用某个任务 | ❌ 需要重编译 | ✅ 开关控制 | +100% |
| 设置工作时间 | ❌ 不支持 | ✅ 时间选择 | +100% |
| 移动端省电 | ⚠️ 固定5分钟 | ✅ 电量感知 | +80% |
| 开发调试 | ❌ 修改代码 | ✅ 实时调整 | +100% |

### 性能影响

- 配置缓存: 减少99%数据库查询
- 条件执行: 移动端省电30%+
- 包体积: +5KB（可忽略）

---

## 🔍 技术要点

### 1. 配置查询优先级

```rust
// 按优先级依次查询
queries = [
    (user_id, platform),   // 1. 用户+平台
    (user_id, None),       // 2. 用户+全平台
    (None, platform),      // 3. 全局+平台
    (None, None),          // 4. 全局+全平台
    default_config(),      // 5. 代码默认
]
```

### 2. 配置缓存策略

```rust
// 缓存键: task_type:user_id
cache_key = "TodoReminderCheck:user-001"

// 缓存失效: 配置更新时清除
pub async fn clear_cache(&self) {
    self.cache.write().await.clear();
}
```

### 3. 移动端优化

```rust
// 电量检查
if battery_level() < config.battery_threshold {
    continue;  // 跳过任务
}

// 网络检查
if config.network_required && !has_network() {
    continue;
}

// Wi-Fi检查
if config.wifi_only && !is_wifi() {
    continue;
}
```

### 4. 平台自适应

```rust
fn current_platform() -> String {
    if cfg!(target_os = "android") { "android" }
    else if cfg!(target_os = "ios") { "ios" }
    else if cfg!(any(target_os = "android", target_os = "ios")) { "mobile" }
    else { "desktop" }
}
```

---

## 📚 相关文档

### 核心文档

- **[完整设计文档](./NOTIFICATION_SCHEDULER_CONFIG.md)** - 详细设计和实现方案
- [统一通知服务设计](./UNIFIED_NOTIFICATION_SERVICE_DESIGN.md) - 通知系统总体架构
- [通知系统分析](./NOTIFICATION_SYSTEM_ANALYSIS.md) - 现状分析

### 平台文档

- [Android 通知配置](./ANDROID_NOTIFICATION_CONFIG.md)
- [iOS 通知配置](./IOS_NOTIFICATION_CONFIG.md)
- [通知权限策略](./NOTIFICATION_PERMISSION_STRATEGY.md)

---

## 💡 最佳实践

### 1. 合理的默认值

```typescript
// 提醒类 - 桌面1分钟，移动5分钟
TodoReminderCheck: { desktop: 60, mobile: 300 }

// 处理类 - 统一2小时
TransactionProcess: 7200

// 健康类 - 每天一次
PeriodReminderCheck: 86400
```

### 2. 用户引导

```typescript
// 首次使用时显示提示
if (isFirstTime) {
  showTip('您可以在设置中调整通知检查频率');
}
```

### 3. 性能监控

```rust
// 记录配置加载时间
let start = Instant::now();
let config = service.get_config(...).await?;
log::debug!("配置加载耗时: {:?}", start.elapsed());
```

---

## ⚠️ 注意事项

### 1. 迁移兼容性

- ✅ 使用 `on_conflict().do_nothing()` 避免重复插入
- ✅ 默认配置不影响现有系统
- ✅ 向后兼容，无需修改现有代码

### 2. 移动端限制

- Android 13+ 需要运行时权限
- iOS 后台任务有系统限制
- 电量检测 API 可能不同

### 3. 性能考虑

- 配置变更后需重启调度器
- 缓存失效要及时清理
- 避免频繁数据库查询

---

## 🎉 总结

### 核心优势

1. ✅ **灵活可配置** - 从硬编码变为数据驱动
2. ✅ **用户友好** - 直观的界面，实时调整
3. ✅ **平台优化** - Desktop/Mobile 自动适配
4. ✅ **性能优良** - 配置缓存，条件执行
5. ✅ **易于扩展** - 新增任务只需添加配置

### 后续计划

- [ ] 完成后端服务实现
- [ ] 完成前端界面开发
- [ ] 移动端真机测试
- [ ] 性能优化和监控
- [ ] 用户反馈收集

---

**文档版本**: v1.0  
**最后更新**: 2025-12-06  
**状态**: 设计完成，待实施 ✅
