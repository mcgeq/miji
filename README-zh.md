<p align="center">
  <strong>中文</strong> · <a href="README.md">English</a>
</p>

<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-yellow.svg" alt="License: MIT"></a>
  <img src="https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter" alt="Flutter">
  <img src="https://img.shields.io/badge/Dart-3.12-0175C2?logo=dart" alt="Dart">
  <img src="https://img.shields.io/badge/platform-Android%20%7C%20iOS%20%7C%20Web%20%7C%20Windows%20%7C%20macOS-lightgrey" alt="Platforms">
</p>

# 米记 Miji

本地优先的跨平台个人记账与健康追踪应用，使用 Flutter 构建。

## 功能

### 记账

- 多账户管理（现金、银行卡、支付宝、微信、花呗、白条、投资、借贷等 17+ 类型）
- 收支转账记录，支持二级分类、标签、商户、退款、分期关联
- 统计图表：分类占比、趋势、账户分布、预算执行、异常检测
- 预算管理：按日/周/月/账单周期/年设置预算，支持子分配和超支预警
- 分期管理：记录分期计划，自动生成每期账单
- 账单提醒：信用卡还款、周期性账单的待办提醒
- 自动记账：定时模板，按计划自动生成交易
- 多人分摊：支持等额、固定金额、比例、权重、自定义分摊规则
- 账本系统：个人账本与家庭账本，支持家庭成员管理

### 健康追踪

- 经期记录与预测：周期长度、经期长度、排卵期、PMS 预测
- 每日健康日志：流量、症状（12 种）、情绪（6 种）、运动、性生活、避孕、排卵测试、药物、饮食、饮水、睡眠、体重、体温、压力、卡路里
- 日历视图与趋势图表
- 怀孕模式：记录孕周、预产期
- 周期设置：个性化调整追踪参数

### 首页仪表盘

- 今日收支概览
- 本月预算进度
- 资产总览与净资产
- 最近交易与紧急提醒
- 支出热力图
- 快捷记账入口

### 安全

- 本地账号密码登录（PBKDF2 哈希）
- 应用锁（PIN / 手势密码）
- 敏感数据二次验证（记账、健康页）
- 凭据密钥加密存储

### 同步

- WebDAV 协议备份同步
- 增量同步与冲突处理
- 本地加密快照备份

## 技术栈

| 层       | 技术                                                      |
| -------- | --------------------------------------------------------- |
| 框架     | Flutter + Dart 3.12                                       |
| 状态管理 | Riverpod 3.x + riverpod_annotation                        |
| 路由     | GoRouter 17.x                                             |
| 数据库   | Drift (SQLite ORM) + sqlite3                              |
| 代码生成 | freezed, json_serializable, riverpod_generator, drift_dev |
| 图表     | fl_chart                                                  |
| 日历     | table_calendar                                            |
| 主题     | flex_color_scheme (Material 3)                            |
| 通知     | flutter_local_notifications                               |
| 安全     | flutter_secure_storage, local_auth, cryptography          |
| 图标     | flutter_svg + vector_graphics_compiler                    |
| 字体     | Google Fonts                                              |

## 开始使用

```bash
git clone <repo-url>
cd miji
flutter pub get
dart run build_runner build
flutter run
```

### 平台支持

Android、iOS、Web、Windows、macOS

## 项目结构

```
lib/
├── core/
│   ├── auth/            # 认证与会话管理
│   ├── database/        # Drift 数据库定义与迁移
│   ├── notifications/   # 本地通知服务
│   ├── preferences/     # 用户偏好设置
│   ├── presentation/    # 共享 UI 组件
│   ├── router/          # 路由配置
│   ├── security/        # 密码哈希与安全
│   ├── sync/            # WebDAV 同步与快照
│   ├── theme/           # 主题系统
│   └── user/            # 用户实体与仓储
├── features/
│   ├── auth/            # 注册 / 登录 / 解锁
│   ├── bookkeeping/     # 记账模块
│   ├── gtd/             # GTD 任务管理（待实现）
│   ├── health/          # 健康追踪模块
│   ├── home/            # 首页仪表盘
│   ├── settings/        # 设置页面
│   └── shell/           # 应用外壳与导航
└── shared/
    └── widgets/         # 可复用表单组件
```

## 许可证

MIT
