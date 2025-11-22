# Period表字段修复

**问题**: `period_daily_records` 表缺少 `exercise_intensity` 等字段

---

## 🔧 已修复的问题

### 1. PeriodDailyRecords 表
添加了所有缺失的字段：
- ✅ `ExerciseIntensity` - 运动强度
- ✅ `SexualActivity` - 性生活
- ✅ `ContraceptionMethod` - 避孕方式
- ✅ `Diet` - 饮食记录
- ✅ `Mood` - 心情
- ✅ `WaterIntake` - 饮水量
- ✅ `SleepHours` - 睡眠时间
- ✅ `UpdatedAt` - 更新时间

### 2. PeriodSymptoms 表
- ✅ 修正外键指向 `PeriodDailyRecords`（之前错误指向 `PeriodRecords`）
- ✅ 添加 `UpdatedAt` 字段

### 3. PeriodPmsRecords 表
- ✅ 添加 `UpdatedAt` 字段

### 4. PeriodPmsSymptoms 表
- ✅ 添加 `UpdatedAt` 字段

### 5. i18n翻译
- ✅ `period.messages.periodDailyRecordSaveFailed` 已存在（第1116行）
- ✅ 其他相关翻译键完整

---

## 🚀 应用修复

### 1. 编译迁移
```bash
cd src-tauri/migration
cargo build
```

### 2. 删除旧数据库（**数据会丢失！**）
```bash
# Windows
Remove-Item "$env:APPDATA\com.miji.app\data.db" -Force
```

### 3. 重新运行应用
重启Tauri应用，会自动执行新的迁移创建表结构

---

## ⚠️ 重要提示

**这是全新的迁移文件，会创建全新的数据库结构。**

如果你有现有数据：
1. ❌ 直接删除数据库会丢失所有数据
2. ✅ 需要先导出数据备份
3. ✅ 应用迁移后重新导入

---

## 📊 修复前后对比

| 表 | 修复前字段数 | 修复后字段数 | 新增字段 |
|----|------------|------------|---------|
| PeriodDailyRecords | 6 | 14 | +8 |
| PeriodSymptoms | 5 | 6 | +1 |
| PeriodPmsRecords | 5 | 6 | +1 |
| PeriodPmsSymptoms | 5 | 6 | +1 |

---

**状态**: ✅ 迁移文件已修复，需要重新编译和应用迁移
