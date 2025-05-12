import 'package:go_router/go_router.dart';
import 'package:miji/app/routes/pages/home_page.dart';
import 'package:miji/app/routes/pages/profile_page.dart';
import 'package:miji/app/routes/pages/settings_page.dart';
import 'package:miji/shared/widgets/navigation/responsive_navigation.dart';

class MijiRouter {
  MijiRouter._();
  static final GoRouter router = GoRouter(
    initialLocation: HomePage.routeName,
    routes: [
      GoRoute(
        path: HomePage.routeName,
        builder:
            (context, state) => const ResponsiveNavigation(
              selectedIndex: 0,
              pages: [HomePage(), ProfilePage(), SettingsPage()],
            ),
      ),
      GoRoute(
        path: ProfilePage.routeName,
        builder:
            (context, state) => const ResponsiveNavigation(
              selectedIndex: 1,
              pages: [HomePage(), ProfilePage(), SettingsPage()],
            ),
      ),
      GoRoute(
        path: SettingsPage.routeName,
        builder:
            (context, state) => const ResponsiveNavigation(
              selectedIndex: 2,
              pages: [HomePage(), ProfilePage(), SettingsPage()],
            ),
      ),
    ],
    debugLogDiagnostics: true,
  );
}