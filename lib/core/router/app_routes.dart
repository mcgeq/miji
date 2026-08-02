class AppRoutes {
  const AppRoutes._();

  static const root = '/';
  static const auth = '/auth';
  static const app = '/app';
  static const home = '/app/home';
  static const gtd = '/app/gtd';
  static const bookkeeping = '/app/bookkeeping';
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

  static const sensitiveRoutes = <String>{bookkeeping, health, gtd};

  static bool isSensitivePath(String path) {
    return sensitiveRoutes.any(
      (route) => path == route || path.startsWith('$route/'),
    );
  }
}
