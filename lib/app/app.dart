import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:miji/config/environment/env_config.dart';
import 'package:miji/config/theme/bloc/theme_bloc.dart';
import 'package:miji/config/theme/bloc/theme_event.dart';
import 'package:miji/config/theme/bloc/theme_state.dart';
import 'package:miji/services/logging/miji_logging.dart';

class Miji extends StatelessWidget {
  const Miji({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<ThemeBloc>(create: (_) => ThemeBloc()),
        // BlocProvider<TodoBloc>(create: (_) => TodoBloc()),
        // BlocProvider<AuthBloc>(create: (_) => AuthBloc()),
      ],
      child: const MijiApp(),
    );
  }
}

class MijiApp extends StatelessWidget {
  const MijiApp({super.key});
  @override
  Widget build(BuildContext context) {
    McgLogger.i('Miji', 'Current run baseUrl: ${env.baseUrl}');
    return BlocBuilder<ThemeBloc, ThemeState>(
      builder: (context, state) {
        return MaterialApp(
          themeMode: _convertAppThemeMode(state.themeMode), // 动态绑定主题模式
          darkTheme: ThemeData.dark(), // 可选：自定义暗色主题
          home: Scaffold(
            appBar: AppBar(title: const Text('Env Testing')),
            body: Center(child: Text('API Key: ${env.apiKey}')),
            floatingActionButton: FloatingActionButton(
              onPressed: () {
                // 切换主题
                context.read<ThemeBloc>().add(ToggleTheme());
              },
              child: const Icon(Icons.brightness_4), // 太阳/月亮图标
            ),
          ),
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