class AppRoutes {
  const AppRoutes._();

  static const root = '/';
  static const auth = '/auth';
  static const app = '/app';
  static const home = '/app/home';
  static const gtd = '/app/gtd';
  static const bookkeeping = '/app/bookkeeping';

  /// 时薪：收入与工时（整屏表单）、到手明细、薪资历史。
  ///
  /// 想买清单**不在这里**：它是面板里的第二个段（换算 / 想买），不是子页面。
  /// 决定买不买发生在他正看着「我一小时值多少」的时候，拆成两个页面等于把
  /// 代价和决定分开放。
  ///
  /// 挂在记账模块下而不是新开一级模块：它读的是同一批流水、同一个账本，
  /// 只是换了一个看钱的视角（钱 = 时间）。
  /// 单笔流水详情。平时从列表点开用的是弹层；跨模块入口（时间线、通知）
  /// 只有一个 id，需要一条能直接用 id 打开的路由。
  static String bookkeepingTransaction(String transactionId) =>
      '/app/bookkeeping/transactions/$transactionId';

  static const bookkeepingLifeEnergyProfile =
      '/app/bookkeeping/life-energy/profile';
  static const bookkeepingLifeEnergyRaises =
      '/app/bookkeeping/life-energy/raises';
  static const bookkeepingLifeEnergyPayroll =
      '/app/bookkeeping/life-energy/payroll';

  /// 跨模块时间线。**必须登记进敏感路由**：它同时展示经期与金额。
  static const timeline = '/app/timeline';

  static const health = '/app/health';
  static const settings = '/app/settings';
  static const settingsSecurity = '/app/settings/security';
  static const settingsAppearance = '/app/settings/appearance';
  static const settingsBookkeeping = '/app/settings/bookkeeping';
  static const settingsSync = '/app/settings/sync';
  static const settingsAbout = '/app/settings/about';
  static const unlock = '/app/unlock';

  // GTD / 打卡子路由
  static const gtdPlans = '/app/gtd/plans';
  static const gtdPlansCreate = '/app/gtd/plans/create';
  static const gtdPlanDetail = '/app/gtd/plans/:planId';
  static const gtdCheckinPhoto = '/app/gtd/checkin/photo/:planId';

  // Todo 子路由
  static const gtdTaskDetail = '/app/gtd/tasks/:taskId';
  static const gtdTaskCreate = '/app/gtd/tasks/create';

  static const sensitiveRoutes = <String>{bookkeeping, health, gtd, timeline};

  static bool isSensitivePath(String path) {
    return sensitiveRoutes.any(
      (route) => path == route || path.startsWith('$route/'),
    );
  }
}
