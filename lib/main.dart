import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:miji/core/auth/application/auth_session_controller.dart';
import 'package:miji/core/database/seed/seed_providers.dart';
import 'package:miji/core/preferences/domain/user_preferences_entity.dart';
import 'package:miji/core/preferences/providers/preferences_providers.dart';
import 'package:miji/core/router/app_router.dart';
import 'package:miji/core/sync/webdav/webdav_providers.dart';
import 'package:miji/core/theme/app_theme.dart';
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
  runApp(const ProviderScope(child: MijiApp()));
}

class MijiApp extends ConsumerStatefulWidget {
  const MijiApp({super.key});

  @override
  ConsumerState<MijiApp> createState() => _MijiAppState();
}

class _MijiAppState extends ConsumerState<MijiApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
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

    ref.listen(authSessionControllerProvider, (_, next) {
      if (next.isUnlocked && next.userId != null) {
        _seedCurrentUserAfterFirstFrame();
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
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Miji',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      themeAnimationDuration: const Duration(milliseconds: 420),
      themeAnimationCurve: Curves.easeInOutCubic,
      builder: FToastBuilder(),
      routerConfig: router,
    );
  }
}
