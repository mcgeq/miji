# iOS 通知配置指南

**目标平台**: iOS 10.0+  
**推荐版本**: iOS 15.0+  
**更新时间**: 2024-12-06

---

## 📋 配置清单

### 1. Info.plist 权限配置 ✅

**文件位置**: `src-tauri/gen/apple/Info.plist`

**必需配置**:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- ==================== 应用基本信息 ==================== -->
    
    <key>CFBundleName</key>
    <string>MiJi</string>
    
    <key>CFBundleDisplayName</key>
    <string>觅记</string>
    
    <key>CFBundleIdentifier</key>
    <string>com.mcgeq.miji</string>
    
    <key>CFBundleVersion</key>
    <string>1.0.0</string>
    
    <!-- ==================== 通知权限描述 ==================== -->
    
    <!-- 用户通知使用说明（必需） -->
    <key>NSUserNotificationsUsageDescription</key>
    <string>我们需要通知权限来及时提醒您的待办事项、账单到期和健康事项，帮助您更好地管理生活</string>
    
    <!-- ==================== 后台模式 ==================== -->
    
    <!-- 后台模式配置 -->
    <key>UIBackgroundModes</key>
    <array>
        <!-- 远程通知（如果使用 Push Notification） -->
        <string>remote-notification</string>
        
        <!-- 后台获取（定期检查） -->
        <string>fetch</string>
        
        <!-- 后台处理（长时间任务） -->
        <string>processing</string>
    </array>
    
    <!-- ==================== 通知配置 ==================== -->
    
    <!-- 支持的通知类型 -->
    <key>UIUserNotificationSettings</key>
    <dict>
        <key>UIUserNotificationTypes</key>
        <integer>7</integer> <!-- 1=Badge, 2=Sound, 4=Alert, 7=All -->
    </dict>
    
    <!-- ==================== 其他配置 ==================== -->
    
    <!-- 应用传输安全（如果需要HTTP请求） -->
    <key>NSAppTransportSecurity</key>
    <dict>
        <key>NSAllowsArbitraryLoads</key>
        <false/>
    </dict>
    
</dict>
</plist>
```

---

## 🔔 通知配置

### UNUserNotificationCenter 配置

iOS 使用 User Notifications framework 管理通知。

**权限说明文案建议**:
```
中文版：
"我们需要通知权限来及时提醒您的待办事项、账单到期和健康事项，帮助您更好地管理生活"

英文版：
"We need notification permission to remind you of your to-dos, bill due dates, and health matters in a timely manner"
```

### 通知类型

iOS 支持三种通知类型（通过位掩码组合）:

| 类型 | 值 | 说明 |
|------|-----|------|
| **Badge** | 1 | 应用图标角标 |
| **Sound** | 2 | 声音提示 |
| **Alert** | 4 | 横幅或警报 |
| **All** | 7 | 所有类型 (1+2+4) |

---

## 🔐 权限请求流程

### 权限请求时机

1. **首次启动时** (推荐)
   - 在引导页说明通知的价值
   - 用户理解后再请求权限

2. **功能使用前**
   - 当用户首次设置提醒时
   - 更自然的权限请求时机

3. **设置中手动请求**
   - 提供"开启通知"按钮
   - 引导用户到系统设置

### 权限请求代码（Swift 原生）

```swift
import UserNotifications

class NotificationManager {
    
    static let shared = NotificationManager()
    
    // MARK: - 请求权限
    
    func requestAuthorization(completion: @escaping (Bool, Error?) -> Void) {
        let center = UNUserNotificationCenter.current()
        
        // 请求授权：横幅、声音、角标
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                if granted {
                    print("✅ 通知权限已授予")
                    self.registerNotificationCategories()
                } else {
                    print("❌ 通知权限被拒绝")
                }
                completion(granted, error)
            }
        }
    }
    
    // MARK: - 检查权限状态
    
    func checkAuthorizationStatus(completion: @escaping (UNAuthorizationStatus) -> Void) {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            DispatchQueue.main.async {
                completion(settings.authorizationStatus)
            }
        }
    }
    
    // MARK: - 注册通知分类
    
    private func registerNotificationCategories() {
        let center = UNUserNotificationCenter.current()
        
        // 待办提醒分类
        let todoCategory = UNNotificationCategory(
            identifier: "TODO_REMINDER",
            actions: [
                UNNotificationAction(
                    identifier: "MARK_DONE",
                    title: "标记完成",
                    options: .foreground
                ),
                UNNotificationAction(
                    identifier: "SNOOZE",
                    title: "稍后提醒",
                    options: []
                )
            ],
            intentIdentifiers: [],
            options: .customDismissAction
        )
        
        // 账单提醒分类
        let billCategory = UNNotificationCategory(
            identifier: "BILL_REMINDER",
            actions: [
                UNNotificationAction(
                    identifier: "PAY_NOW",
                    title: "去支付",
                    options: .foreground
                ),
                UNNotificationAction(
                    identifier: "REMIND_LATER",
                    title: "稍后提醒",
                    options: []
                )
            ],
            intentIdentifiers: [],
            options: .customDismissAction
        )
        
        // 健康提醒分类
        let healthCategory = UNNotificationCategory(
            identifier: "HEALTH_REMINDER",
            actions: [
                UNNotificationAction(
                    identifier: "RECORD",
                    title: "记录",
                    options: .foreground
                )
            ],
            intentIdentifiers: [],
            options: .customDismissAction
        )
        
        // 注册所有分类
        center.setNotificationCategories([
            todoCategory,
            billCategory,
            healthCategory
        ])
    }
    
    // MARK: - 打开系统设置
    
    func openAppSettings() {
        guard let settingsUrl = URL(string: UIApplication.openSettingsURLString) else {
            return
        }
        
        if UIApplication.shared.canOpenURL(settingsUrl) {
            UIApplication.shared.open(settingsUrl)
        }
    }
}
```

### 权限状态说明

```swift
enum UNAuthorizationStatus {
    case notDetermined  // 未询问
    case denied         // 用户拒绝
    case authorized     // 已授权
    case provisional    // 临时授权（iOS 12+，静默通知）
    case ephemeral      // 短期授权（iOS 14+，App Clips）
}
```

---

## 🎨 通知样式配置

### 本地通知示例

```swift
func scheduleLocalNotification(
    title: String,
    body: String,
    identifier: String,
    categoryIdentifier: String,
    timeInterval: TimeInterval,
    repeats: Bool = false
) {
    let content = UNMutableNotificationContent()
    content.title = title
    content.body = body
    content.sound = .default
    content.badge = NSNumber(value: 1)
    content.categoryIdentifier = categoryIdentifier
    
    // 自定义数据
    content.userInfo = [
        "type": categoryIdentifier,
        "id": identifier,
        "timestamp": Date().timeIntervalSince1970
    ]
    
    // 触发器
    let trigger = UNTimeIntervalNotificationTrigger(
        timeInterval: timeInterval,
        repeats: repeats
    )
    
    // 创建请求
    let request = UNNotificationRequest(
        identifier: identifier,
        content: content,
        trigger: trigger
    )
    
    // 添加通知
    UNUserNotificationCenter.current().add(request) { error in
        if let error = error {
            print("❌ 添加通知失败: \(error)")
        } else {
            print("✅ 通知已计划: \(identifier)")
        }
    }
}
```

### 通知优先级

iOS 通过 `interruptionLevel` (iOS 15+) 控制优先级：

```swift
if #available(iOS 15.0, *) {
    content.interruptionLevel = .timeSensitive // 时间敏感
    // 或
    content.interruptionLevel = .critical      // 紧急（需特殊权限）
}
```

| 级别 | 说明 | 使用场景 |
|------|------|---------|
| **passive** | 被动 | 不重要的通知 |
| **active** | 活跃（默认） | 一般通知 |
| **timeSensitive** | 时间敏感 | 重要通知，可穿透勿扰模式 |
| **critical** | 紧急 | 需特殊权限，必定显示和发声 |

---

## 🔕 勿扰模式处理

### Focus 模式（iOS 15+）

iOS 15 引入了 Focus 模式，用户可以自定义通知过滤规则。

**时间敏感通知**:
```swift
// 设置为时间敏感，可穿透部分 Focus 模式
content.interruptionLevel = .timeSensitive
```

**紧急通知**（需特殊权限）:
```swift
// Info.plist 中添加
<key>UIBackgroundModes</key>
<array>
    <string>remote-notification</string>
</array>

// 并在 Capabilities 中启用 Critical Alerts

// 代码中设置
content.interruptionLevel = .critical
content.sound = .defaultCritical // 特殊声音
```

---

## 🔋 后台执行配置

### Background Modes

**配置方法**:
1. Xcode → Target → Capabilities → Background Modes
2. 或在 Info.plist 中添加（见上文）

**支持的后台模式**:

| 模式 | 说明 | 使用场景 |
|------|------|---------|
| **remote-notification** | 远程通知 | Push Notification |
| **fetch** | 后台获取 | 定期检查数据 |
| **processing** | 后台处理 | 长时间任务 |

### Background Fetch 配置

```swift
// AppDelegate.swift
func application(
    _ application: UIApplication,
    performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
) {
    // 执行后台数据获取
    checkForDueReminders { hasNewData in
        if hasNewData {
            completionHandler(.newData)
        } else {
            completionHandler(.noData)
        }
    }
}

// 设置后台获取间隔
func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
) -> Bool {
    UIApplication.shared.setMinimumBackgroundFetchInterval(
        UIApplication.backgroundFetchIntervalMinimum // 系统决定
    )
    return true
}
```

---

## 📱 通知分组

### 线程标识符

iOS 支持通知分组显示：

```swift
content.threadIdentifier = "todo_group"  // 相同标识符的通知会分组
```

### 摘要格式

```swift
// iOS 15+ 支持自定义摘要
if #available(iOS 15.0, *) {
    content.targetContentIdentifier = "todo_list" // 点击后跳转的标识
}
```

---

## 🎵 声音配置

### 使用系统声音

```swift
content.sound = .default // 默认通知声音
```

### 使用自定义声音

1. 添加音频文件到项目（支持格式：`.aiff`, `.wav`, `.caf`）
2. 文件长度 ≤ 30 秒
3. 设置声音：

```swift
content.sound = UNNotificationSound(named: UNNotificationSoundName("notification.caf"))
```

### 紧急声音（需特殊权限）

```swift
if #available(iOS 12.0, *) {
    content.sound = .defaultCritical
}
```

---

## 🧪 测试清单

### 基础功能测试

- [ ] **权限请求**
  - 首次启动显示权限对话框
  - 文案清晰易懂
  - 授予/拒绝权限后的行为正确

- [ ] **通知显示**
  - 横幅通知正常显示
  - 锁屏通知正常显示
  - 通知中心可查看历史通知

- [ ] **通知声音**
  - 声音正常播放
  - 静音模式下尊重用户设置
  - 勿扰模式下按规则过滤

- [ ] **角标**
  - 未读通知数正确显示
  - 查看通知后角标更新

### 交互测试

- [ ] **通知操作**
  - 点击通知打开应用
  - 跳转到正确页面
  - 传递正确的数据

- [ ] **操作按钮**（如果实现）
  - 快速操作按钮显示
  - 点击按钮执行正确操作
  - 前台/后台操作都正常

### 后台测试

- [ ] **应用在后台**
  - 通知仍然正常触发
  - 声音和角标正常

- [ ] **应用被杀死**
  - 本地通知仍然触发
  - 用户数据保留

- [ ] **长时间后台**
  - 系统未杀死应用时通知正常
  - Background Fetch 工作正常

### Focus 模式测试

- [ ] **勿扰模式**
  - 普通通知被过滤
  - 时间敏感通知可穿透（如已配置）

- [ ] **睡眠模式**
  - 按用户设置过滤通知

---

## 🐛 常见问题

### 1. 通知不显示

**可能原因**:
- ✅ 权限未授予
- ✅ Focus 模式过滤
- ✅ 通知设置被用户禁用
- ✅ 触发时间已过

**解决方案**:
```swift
// 检查权限状态
UNUserNotificationCenter.current().getNotificationSettings { settings in
    print("Authorization status: \(settings.authorizationStatus)")
    print("Alert setting: \(settings.alertSetting)")
    print("Sound setting: \(settings.soundSetting)")
    print("Badge setting: \(settings.badgeSetting)")
}

// 检查待处理的通知
UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
    print("Pending notifications: \(requests.count)")
}

// 检查已发送的通知
UNUserNotificationCenter.current().getDeliveredNotifications { notifications in
    print("Delivered notifications: \(notifications.count)")
}
```

### 2. 角标不更新

**原因**: 需要手动更新角标

**解决**:
```swift
// 设置角标
UIApplication.shared.applicationIconBadgeNumber = newCount

// 或在通知中设置
content.badge = NSNumber(value: badgeCount)
```

### 3. 时间敏感通知不工作

**要求**:
- iOS 15+
- 用户在 Focus 设置中允许时间敏感通知
- 应用有 Time Sensitive Notifications 权限

**检查**:
```swift
if #available(iOS 15.0, *) {
    UNUserNotificationCenter.current().getNotificationSettings { settings in
        print("Time sensitive: \(settings.timeSensitiveSetting)")
    }
}
```

---

## 📚 参考资源

### 官方文档
- [User Notifications Framework](https://developer.apple.com/documentation/usernotifications)
- [Notification Management](https://developer.apple.com/documentation/usernotifications/managing_notification-related_behaviors)
- [Focus Modes](https://developer.apple.com/documentation/usernotifications/unnotificationinterruptionlevel)

### WWDC 视频
- [What's New in Notifications (WWDC 2021)](https://developer.apple.com/videos/play/wwdc2021/10091/)
- [Local and Remote Notifications (WWDC 2018)](https://developer.apple.com/videos/play/wwdc2018/710/)

### Tauri 相关
- [Tauri Plugin Notification](https://v2.tauri.app/plugin/notification/)
- [Tauri iOS Configuration](https://v2.tauri.app/develop/mobile/ios/)

---

## ✅ 配置验证

完成配置后，运行以下检查：

```bash
# 1. 检查 Info.plist
plutil -lint Info.plist

# 2. 构建项目
bun tauri ios build

# 3. 运行模拟器
open -a Simulator

# 4. 安装应用
# 在 Xcode 中运行或使用命令行

# 5. 查看日志
# Xcode → Window → Devices and Simulators → View Device Logs

# 6. 测试通知
# 在应用中触发通知
```

---

## 🎯 最佳实践

### 1. 权限请求时机

❌ **不好的做法**:
- 应用启动立即请求权限
- 没有说明为什么需要权限

✅ **好的做法**:
- 在引导页说明通知的价值
- 当用户准备使用功能时请求
- 提供"稍后设置"选项

### 2. 通知频率

❌ **不好的做法**:
- 频繁发送不重要的通知
- 没有分组相似通知

✅ **好的做法**:
- 只发送有价值的通知
- 相似通知使用分组
- 尊重用户的通知设置

### 3. 通知内容

❌ **不好的做法**:
- 内容模糊不清
- 过长的文字

✅ **好的做法**:
- 标题简洁明了
- 内容直接有用
- 提供快捷操作

---

**文档版本**: v1.0  
**最后更新**: 2024-12-06  
**维护者**: Cascade AI
