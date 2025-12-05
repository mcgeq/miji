# Android 通知配置指南

**目标平台**: Android 8.0+ (API 26+)  
**特别注意**: Android 13+ (API 33+) 需要运行时权限  
**更新时间**: 2024-12-06

---

## 📋 配置清单

### 1. AndroidManifest.xml 权限配置 ✅

**文件位置**: `src-tauri/gen/android/app/src/main/AndroidManifest.xml`

**必需权限**:
```xml
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    
    <!-- ==================== 通知权限 ==================== -->
    
    <!-- Android 13 (API 33) 及以上必需 -->
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
    
    <!-- 震动权限（可选） -->
    <uses-permission android:name="android.permission.VIBRATE"/>
    
    <!-- ==================== 后台运行权限 ==================== -->
    
    <!-- 前台服务权限 -->
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
    
    <!-- 电池优化豁免（可选，建议） -->
    <uses-permission android:name="android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS"/>
    
    <!-- Wake Lock（保持唤醒） -->
    <uses-permission android:name="android.permission.WAKE_LOCK"/>
    
    <!-- ==================== 应用配置 ==================== -->
    
    <application
        android:name=".MainApplication"
        android:label="@string/app_name"
        android:icon="@mipmap/ic_launcher"
        android:roundIcon="@mipmap/ic_launcher_round"
        android:allowBackup="true"
        android:theme="@style/AppTheme">
        
        <!-- Main Activity -->
        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:launchMode="singleTask">
            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
        </activity>
        
        <!-- ==================== 通知服务配置 ==================== -->
        
        <!-- 可选：前台服务（用于后台通知） -->
        <service
            android:name=".NotificationService"
            android:enabled="true"
            android:exported="false"
            android:foregroundServiceType="dataSync"/>
        
        <!-- 可选：广播接收器（用于通知操作） -->
        <receiver
            android:name=".NotificationReceiver"
            android:enabled="true"
            android:exported="false">
            <intent-filter>
                <action android:name="com.mcgeq.miji.NOTIFICATION_ACTION"/>
            </intent-filter>
        </receiver>
        
    </application>
</manifest>
```

---

## 🔔 通知渠道配置

### 渠道定义（已在 Rust 代码中实现）

我们的应用定义了 4 个通知渠道：

| 渠道 ID | 名称 | 重要性 | 描述 |
|---------|------|--------|------|
| `todo_reminders` | 待办提醒 | HIGH | 待办事项到期提醒通知 |
| `bill_reminders` | 账单提醒 | HIGH | 账单到期和逾期提醒通知 |
| `period_reminders` | 健康提醒 | DEFAULT | 经期、排卵期和PMS提醒通知 |
| `system_alerts` | 系统警报 | MAX | 重要的系统级别通知 |

### 重要性级别说明

```kotlin
// Android NotificationManager 重要性常量
IMPORTANCE_MIN = 1     // 最小：不显示，不发声
IMPORTANCE_LOW = 2     // 低：显示，不发声
IMPORTANCE_DEFAULT = 3 // 默认：显示，发声
IMPORTANCE_HIGH = 4    // 高：显示，发声，弹出
IMPORTANCE_MAX = 5     // 最高：显示，发声，弹出，全屏
```

**我们的映射**:
- `"high"` → `IMPORTANCE_HIGH` (4)
- `"default"` → `IMPORTANCE_DEFAULT` (3)
- `"max"` → `IMPORTANCE_MAX` (5)

---

## 🔐 权限请求流程

### Android 13+ (API 33+) 权限请求

**时机选择**:

1. **首次启动时请求** (推荐)
   - 在欢迎页或设置向导中
   - 说明为什么需要通知权限

2. **功能使用前请求**
   - 当用户首次使用需要通知的功能时
   - 更自然的权限请求时机

3. **设置中手动请求**
   - 提供"开启通知"按钮
   - 引导用户到系统设置

### 权限请求代码（Kotlin 原生）

```kotlin
// MainActivity.kt
import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat

class MainActivity : AppCompatActivity() {
    
    companion object {
        private const val REQUEST_CODE_NOTIFICATION = 1001
    }
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // 检查并请求通知权限
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            checkAndRequestNotificationPermission()
        }
    }
    
    private fun checkAndRequestNotificationPermission() {
        when {
            ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.POST_NOTIFICATIONS
            ) == PackageManager.PERMISSION_GRANTED -> {
                // 已有权限
                onNotificationPermissionGranted()
            }
            shouldShowRequestPermissionRationale(Manifest.permission.POST_NOTIFICATIONS) -> {
                // 显示权限说明对话框
                showNotificationPermissionRationale()
            }
            else -> {
                // 请求权限
                ActivityCompat.requestPermissions(
                    this,
                    arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                    REQUEST_CODE_NOTIFICATION
                )
            }
        }
    }
    
    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        
        when (requestCode) {
            REQUEST_CODE_NOTIFICATION -> {
                if (grantResults.isNotEmpty() && 
                    grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                    onNotificationPermissionGranted()
                } else {
                    onNotificationPermissionDenied()
                }
            }
        }
    }
    
    private fun onNotificationPermissionGranted() {
        Log.d("Notification", "Permission granted")
        // 通知 Rust 代码权限已授予
    }
    
    private fun onNotificationPermissionDenied() {
        Log.d("Notification", "Permission denied")
        // 显示引导用户到设置的提示
        showPermissionDeniedDialog()
    }
    
    private fun showPermissionDeniedDialog() {
        AlertDialog.Builder(this)
            .setTitle("需要通知权限")
            .setMessage("为了及时提醒您的待办、账单和健康事项，请在设置中开启通知权限。")
            .setPositiveButton("去设置") { _, _ ->
                openAppSettings()
            }
            .setNegativeButton("取消", null)
            .show()
    }
    
    private fun openAppSettings() {
        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
        intent.data = Uri.fromParts("package", packageName, null)
        startActivity(intent)
    }
}
```

---

## 🔋 电池优化

### 为什么需要电池优化豁免？

Android 系统为了省电，会限制后台应用：
- **Doze 模式**: 设备静止时限制网络和任务
- **App Standby**: 不常用的应用被限制
- **后台限制**: Android 9+ 更严格的后台限制

**影响**: 后台通知可能延迟或不发送

### 请求电池优化豁免

```kotlin
import android.content.Intent
import android.net.Uri
import android.os.PowerManager
import android.provider.Settings

fun requestBatteryOptimizationExemption(activity: Activity) {
    val powerManager = activity.getSystemService(Context.POWER_SERVICE) as PowerManager
    
    if (!powerManager.isIgnoringBatteryOptimizations(activity.packageName)) {
        val intent = Intent().apply {
            action = Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS
            data = Uri.parse("package:${activity.packageName}")
        }
        activity.startActivity(intent)
    }
}
```

**注意**: 
- ⚠️ 不要滥用此权限
- 💡 只在用户明确需要后台通知时请求
- 📝 Google Play 政策要求说明使用原因

---

## 🎨 通知样式配置

### 自定义通知图标

**小图标** (状态栏显示):
- 路径: `res/drawable/ic_notification.xml`
- 要求: 白色图标，透明背景
- 尺寸: 24x24 dp

```xml
<!-- res/drawable/ic_notification.xml -->
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="24dp"
    android:height="24dp"
    android:viewportWidth="24"
    android:viewportHeight="24">
    <path
        android:fillColor="#FFFFFF"
        android:pathData="M12,2C6.48,2 2,6.48 2,12s4.48,10 10,10 10,-4.48 10,-10S17.52,2 12,2zM12,18.5c-0.83,0 -1.5,-0.67 -1.5,-1.5h3c0,0.83 -0.67,1.5 -1.5,1.5zM17,16L7,16v-1l1,-1v-2.61C8,9.27 9.03,7.47 11,7v-0.5c0,-0.57 0.43,-1 1,-1s1,0.43 1,1L13,7c1.97,0.47 3,2.27 3,4.39L16,14l1,1v1z"/>
</vector>
```

**大图标** (通知中显示):
- 路径: `res/mipmap-*/ic_launcher.png`
- 格式: PNG，彩色
- 尺寸: 
  - mdpi: 48x48
  - hdpi: 72x72
  - xhdpi: 96x96
  - xxhdpi: 144x144
  - xxxhdpi: 192x192

### 通知颜色

```kotlin
// 在通知构建时设置
.setColor(ContextCompat.getColor(context, R.color.notification_color))
```

```xml
<!-- res/values/colors.xml -->
<resources>
    <color name="notification_color">#FF6200EE</color>
</resources>
```

---

## 📱 通知行为配置

### 震动模式

```rust
// 在 notification_service.rs 中配置
#[cfg(target_os = "android")]
{
    builder = builder.sound(Some("default".to_string()));
    
    // 震动模式：短震-停-长震
    if priority == NotificationPriority::High || priority == NotificationPriority::Urgent {
        // 需要 VIBRATE 权限
        // Tauri 插件当前可能不支持，需要原生实现
    }
}
```

### 声音配置

**使用系统默认声音**:
```kotlin
.setSound(RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION))
```

**使用自定义声音**:
1. 放置音频文件到 `res/raw/notification_sound.mp3`
2. 设置: `.setSound(Uri.parse("android.resource://${packageName}/raw/notification_sound"))`

### LED 灯效

```kotlin
.setLights(Color.BLUE, 1000, 1000) // 颜色，亮时间(ms)，暗时间(ms)
```

---

## 🧪 测试清单

### 基础功能测试

- [ ] **通知渠道创建**
  - 打开系统设置 → 应用 → Miji → 通知
  - 检查是否有 4 个渠道
  - 每个渠道名称和描述正确

- [ ] **权限请求** (Android 13+)
  - 首次启动显示权限对话框
  - 授予权限后通知正常
  - 拒绝权限后显示引导提示

- [ ] **通知显示**
  - 发送不同渠道的通知
  - 检查通知样式和图标
  - 检查声音和震动

### 后台测试

- [ ] **应用在后台**
  - 按 Home 键
  - 等待通知触发
  - 检查通知是否正常显示

- [ ] **应用被杀死**
  - 从最近任务中滑走应用
  - 等待通知触发时间
  - 检查通知是否仍然工作

- [ ] **Doze 模式测试**
  - 启用 Doze 模式: `adb shell dumpsys deviceidle force-idle`
  - 检查通知是否延迟
  - 退出 Doze: `adb shell dumpsys deviceidle unforce`

### 电池优化测试

- [ ] **电池优化开启**
  - 系统设置中开启电池优化
  - 检查后台通知行为

- [ ] **电池优化关闭**
  - 请求豁免
  - 检查后台通知是否改善

---

## 🐛 常见问题

### 1. 通知不显示

**可能原因**:
- ✅ 权限未授予（Android 13+）
- ✅ 通知渠道被禁用
- ✅ 电池优化限制
- ✅ 通知被系统过滤

**解决方案**:
```bash
# 检查权限状态
adb shell dumpsys package com.mcgeq | grep "POST_NOTIFICATIONS"

# 检查通知渠道
adb shell dumpsys notification

# 检查电池优化
adb shell dumpsys deviceidle whitelist
```

### 2. 通知延迟

**原因**: Doze 模式或电池优化

**解决**:
1. 请求电池优化豁免
2. 使用高优先级通知
3. 使用前台服务（适用于持续任务）

### 3. 图标显示异常

**原因**: 小图标不符合规范

**要求**:
- 必须是白色图标
- 背景透明
- 矢量格式 (XML)

---

## 📚 参考资源

### 官方文档
- [Android Notifications Overview](https://developer.android.com/develop/ui/views/notifications)
- [Notification Channels](https://developer.android.com/develop/ui/views/notifications/channels)
- [Runtime Permissions](https://developer.android.com/training/permissions/requesting)
- [Background Restrictions](https://developer.android.com/topic/performance/power)

### Tauri 相关
- [Tauri Plugin Notification](https://v2.tauri.app/plugin/notification/)
- [Tauri Android Configuration](https://v2.tauri.app/develop/mobile/android/)

---

## ✅ 配置验证

完成配置后，运行以下检查：

```bash
# 1. 检查 AndroidManifest.xml
adb shell dumpsys package com.mcgeq | grep permission

# 2. 安装应用
bun tauri android build
adb install target/android/app/build/outputs/apk/debug/app-debug.apk

# 3. 查看日志
adb logcat | grep -i notification

# 4. 测试通知
# 在应用中触发通知

# 5. 检查通知渠道
adb shell dumpsys notification | grep -A 10 "com.mcgeq"
```

---

**文档版本**: v1.0  
**最后更新**: 2024-12-06  
**维护者**: Cascade AI
