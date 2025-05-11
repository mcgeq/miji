import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:miji/app/routes/pages/home_page.dart';
import 'package:miji/app/routes/pages/profile_page.dart';
import 'package:miji/app/routes/pages/settings_page.dart';
import 'package:miji/config/environment/env_config.dart';
import 'package:miji/config/theme/app_colors.dart';
import 'package:miji/config/theme/bloc/theme_bloc.dart';
import 'package:miji/config/theme/bloc/theme_state.dart';
import 'package:miji/di/injector.dart';
import 'package:miji/features/home/bloc/home_bloc.dart';
import 'package:miji/features/home/bloc/home_event.dart';
import 'package:miji/features/home/data/home_repository.dart';
import 'package:miji/l10n/l10n.dart';
import 'package:miji/services/logging/miji_logging.dart';
import 'package:miji/shared/widgets/navigation/navigation_cubit.dart';
import 'package:miji/shared/widgets/navigation/responsive_navigation.dart';

class Miji extends StatelessWidget {
  const Miji({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<ThemeBloc>(create: (_) => ThemeBloc()),
        BlocProvider<NavigationCubit>(create: (_) => NavigationCubit()),
        BlocProvider<HomeBloc>(
          create:
              (_) => HomeBloc(getIt<HomeRepository>())..add(LoadTodos(page: 1)),
        ),
      ],
      child: const MijiApp(),
    );
  }
}

class MijiApp extends StatefulWidget {
  const MijiApp({super.key});

  @override
  State<MijiApp> createState() => _MijiAppState();
}

class _MijiAppState extends State<MijiApp> {
  String? todoResponse;

  @override
  Widget build(BuildContext context) {
    McgLogger.i('Miji', 'Current run baseUrl: ${env.baseUrl}');
    final Map<String, WidgetBuilder> routes = {
      HomePage.routeName:
          (context) => const ResponsiveNavigation(
            selectedIndex: 0,
            pages: [HomePage(), ProfilePage(), SettingsPage()],
          ),
      ProfilePage.routeName:
          (context) => const ResponsiveNavigation(
            selectedIndex: 1,
            pages: [HomePage(), ProfilePage(), SettingsPage()],
          ),
      SettingsPage.routeName:
          (context) => const ResponsiveNavigation(
            selectedIndex: 2,
            pages: [HomePage(), ProfilePage(), SettingsPage()],
          ),
    };
    return BlocBuilder<ThemeBloc, ThemeState>(
      builder: (context, state) {
        return MaterialApp(
          themeMode: _convertAppThemeMode(state.themeMode),
          darkTheme: ThemeData.dark().copyWith(
            primaryColor: AppColors.primaryColor,
          ),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('en', ''),
            Locale('zh', ''),
            Locale('es', ''),
          ],
          initialRoute: HomePage.routeName,
          routes: routes,
        );
      },
    );
  }

  ThemeMode _convertAppThemeMode(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }
}