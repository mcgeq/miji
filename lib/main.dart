import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:home_widget/home_widget.dart';
import 'package:miji/core/auth/application/auth_session_controller.dart';
import 'package:miji/core/database/seed/seed_providers.dart';
import 'package:miji/core/notifications/notification_providers.dart';
import 'package:miji/core/presentation/components/money_text.dart';
import 'package:miji/core/preferences/domain/user_preferences_entity.dart';
import 'package:miji/core/preferences/providers/preferences_providers.dart';
import 'package:miji/core/router/app_router.dart';
import 'package:miji/core/router/app_routes.dart';
import 'package:miji/core/sync/webdav/webdav_providers.dart';
import 'package:miji/core/theme/app_palette_providers.dart';
import 'package:miji/core/theme/app_theme.dart';
import 'package:miji/features/bookkeeping/application/money_home_widget.dart';
import 'package:miji/features/bookkeeping/providers/bookkeeping_providers.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

Future<void> _initTimeZone() async {
  tz_data.initializeTimeZones();
  try {
    final timezoneInfo = await FlutterTimezone.getLocalTimezone();
    final name = timezoneInfo.identifier;
    if (name.isNotEmpty) {
      tz.setLocalLocation(tz.getLocation(name));
    }
  } catch (_) {
    // 时区获取失败时保持 tz.local 默认值（UTC），不阻塞启动；
    // 定时通知按设备本地时间错时的场景由用户在下次启动自动修复。
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 定时通知（打卡提醒、每日汇总、纪念日）全部基于 timezone 包按
  // tz.local 计算；不初始化时 tz.local 是 UTC，非 UTC 设备会错时。
  await _initTimeZone();
  // 强制开启语义树：语义信息默认只在有无障碍服务连接时收集，
  // 而厂商系统（如 MIUI）的滚动截屏服务依赖无障碍节点判断页面
  // 是否存在可滚动内容；没有语义树时「截长屏」按钮会置灰。
  // 返回的 SemanticsHandle 无需释放：引用计数始终 >0，语义常开。
  SemanticsBinding.instance.ensureSemantics();
  runApp(
    const ProviderScope(
      // 两套遮罩都挂在 ProviderScope 正下方，而不是 Shell 里：
      // 记账表单 / 预算分配 / 流水详情等对话框挂在根导航器上，拿不到 Shell
      // 内的作用域，读不到就会退回「不遮」的兜底值 —— 表现为卡面是 ••••，
      // 点开任何一层弹窗金额全露。
      child: IncomePrivacyScope(child: MoneyPrivacyScope(child: MijiApp())),
    ),
  );
}

class MijiApp extends ConsumerStatefulWidget {
  const MijiApp({super.key});

  @override
  ConsumerState<MijiApp> createState() => _MijiAppState();
}

class _MijiAppState extends ConsumerState<MijiApp> with WidgetsBindingObserver {
  StreamSubscription<String>? _tapSubscription;
  StreamSubscription<Uri?>? _homeWidgetTapSubscription;

  /// 小组件点击时应用还锁着，就把目标存下来，等解锁后再跳。
  ///
  /// 不存这份「待办跳转」的话：`go()` 会被 router 的 redirect 送去 `/auth`，
  /// 用户解锁后落回首页 —— 「点小组件直达记一笔」这一步就白点了。
  String? _pendingHomeWidgetLocation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tapSubscription = ref
        .read(notificationTapBusProvider)
        .taps
        .listen(_handleNotificationPayload);
    if (MoneyWidgetSnapshot.isSupported) {
      _homeWidgetTapSubscription = HomeWidget.widgetClicked.listen(
        _handleHomeWidgetUri,
      );
      unawaited(_consumeInitialHomeWidgetLaunch());
    }
  }

  @override
  void dispose() {
    unawaited(_tapSubscription?.cancel());
    _tapSubscription = null;
    unawaited(_homeWidgetTapSubscription?.cancel());
    _homeWidgetTapSubscription = null;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// 冷启动：进程是被小组件点起来的，这一下点击不在 stream 里。
  Future<void> _consumeInitialHomeWidgetLaunch() async {
    try {
      _handleHomeWidgetUri(await HomeWidget.initiallyLaunchedFromHomeWidget());
    } catch (error) {
      // 没有小组件实例 / 系统没给 intent，都是正常情况。
      debugPrint('HomeWidget initial launch unavailable: $error');
    }
  }

  /// 小组件点击 → 路由。
  ///
  /// 小组件那边给的是 `miji:///app/bookkeeping?action=expense`（三斜线，
  /// 避免 host 吃掉路径的一段）。这里只取 path + query 交给 go_router，
  /// 不重新拼业务参数：`action=expense` 的语义在 BookkeepingPage 里。
  void _handleHomeWidgetUri(Uri? uri) {
    if (uri == null) {
      return;
    }
    final path = uri.host.isEmpty ? uri.path : '/${uri.host}${uri.path}';
    if (path.isEmpty || path == '/') {
      return;
    }
    final location = uri.hasQuery ? '$path?${uri.query}' : path;

    final session = ref.read(authSessionControllerProvider);
    if (!session.isUnlocked || session.userId == null) {
      _pendingHomeWidgetLocation = location;
      return;
    }
    _goDeferred(location);
  }

  void _goDeferred(String location) {
    // 冷启动时这一下可能早于 MaterialApp 把 Router 挂上，推到下一帧更稳。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      ref.read(appRouterProvider).go(location);
    });
  }

  void _flushPendingHomeWidgetLocation() {
    final location = _pendingHomeWidgetLocation;
    if (location == null) {
      return;
    }
    _pendingHomeWidgetLocation = null;
    _goDeferred(location);
  }

  /// 通知点击 → 路由。
  ///
  /// payload 统一 `miji://money/<target>`，这里只做一层映射，不解析实体 id：
  /// 提醒的处理入口本来就集中在提醒面板，跳过去比跳某个具体实体更有用。
  void _handleNotificationPayload(String payload) {
    final router = ref.read(appRouterProvider);
    final target = Uri.tryParse(payload)?.pathSegments;
    final section = switch (target != null && target.length >= 2
        ? target[1]
        : '') {
      'budgets' => 'budgets',
      'log' => 'transactions',
      _ => 'reminders',
    };
    final uri = Uri(
      path: AppRoutes.bookkeeping,
      queryParameters: <String, String>{
        'section': section,
        if (section == 'transactions') 'action': 'expense',
      },
    );
    router.go(uri.toString());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      return;
    }

    Future<void>.microtask(() {
      if (!mounted) {
        return;
      }
      ref.read(webDavAutoSyncControllerProvider.notifier).refresh();
      // 桌面小组件只在 app 活着时才被推送，回到前台是最可靠的一次对齐。
      unawaited(ref.read(moneyWidgetPusherProvider).push());
      unawaited(
        ref.read(currentUserBudgetAlertNotificationActionsProvider).scanNow(),
      );
      unawaited(
        ref.read(currentUserBillReminderNotificationActionsProvider).scanNow(),
      );
    });
  }

  void _seedCurrentUserAfterFirstFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(
        Future<void>.delayed(const Duration(milliseconds: 160), () async {
          if (!mounted) {
            return;
          }
          await ref.read(currentUserDatabaseSeedProvider.future);
        }),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(globalDatabaseSeedProvider);
    ref.watch(webDavAutoSyncControllerProvider);
    // 长期 watch：提醒中心的待处理项 / 提醒设置 / 当天流水任一变化都会
    // 自动重排系统级预约通知，不打开记账模块也能按时收到账单项。
    ref.watch(moneyReminderScheduleSyncProvider);
    // 记账数据一变就重推小组件（内部 500ms 防抖），见 money_home_widget.dart。
    ref.watch(moneyWidgetAutoSyncProvider);

    ref.listen(authSessionControllerProvider, (_, next) {
      if (next.isUnlocked && next.userId != null) {
        _seedCurrentUserAfterFirstFrame();
        _flushPendingHomeWidgetLocation();
        unawaited(
          ref.read(currentUserBudgetAlertNotificationActionsProvider).scanNow(),
        );
        unawaited(
          ref
              .read(currentUserBillReminderNotificationActionsProvider)
              .scanNow(),
        );
      }
    });

    final themeMode = ref.watch(effectiveThemeModePreferenceProvider).themeMode;
    // 配色是设备级偏好（见 ThemePaletteController）：改了它，浅/深两套
    // ThemeData 一起换，`MaterialApp` 播一次 420ms 过渡就完成切换。
    final paletteId = ref.watch(themePaletteIdProvider);
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Miji',
      theme: AppTheme.light(paletteId),
      darkTheme: AppTheme.dark(paletteId),
      themeMode: themeMode,
      themeAnimationDuration: const Duration(milliseconds: 420),
      themeAnimationCurve: Curves.easeInOutCubic,
      builder: FToastBuilder(),
      routerConfig: router,
    );
  }
}
