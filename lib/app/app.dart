import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:miji/config/environment/env_config.dart';
import 'package:miji/config/theme/bloc/theme_bloc.dart';
import 'package:miji/config/theme/bloc/theme_event.dart';
import 'package:miji/config/theme/bloc/theme_state.dart' as app_theme;

class Miji extends StatelessWidget {
  const Miji({super.key});
  @override
  Widget build(BuildContext context) {
    debugPrint('Current run baseUrl: ${env.baseUrl}');
    return BlocBuilder<ThemeBloc, app_theme.ThemeState>(
      builder: (context, state) {
        return MaterialApp(
          themeMode: state.themeMode as ThemeMode?, // 动态绑定主题模式
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
}
