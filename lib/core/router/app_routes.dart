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

  static const sensitiveRoutes = <String>{bookkeeping, health};

  static bool isSensitivePath(String path) {
    return sensitiveRoutes.any(
      (route) => path == route || path.startsWith('$route/'),
    );
  }
}
