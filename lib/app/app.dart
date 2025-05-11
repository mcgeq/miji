import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:miji/config/environment/env_config.dart';
import 'package:miji/config/theme/bloc/theme_bloc.dart';
import 'package:miji/config/theme/bloc/theme_event.dart';
import 'package:miji/config/theme/bloc/theme_state.dart';
import 'package:miji/data/repositories/todo_repository.dart';
import 'package:miji/di/injector.dart';
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

class MijiApp extends StatefulWidget {
  const MijiApp({super.key});

  @override
  State<MijiApp> createState() => _MijiAppState();
}

class _MijiAppState extends State<MijiApp> {
  String? todoResponse; // State variable to hold the API response
  Future<void> _fetchTodo(String todoId) async {
    try {
      final repository = getIt<TodoRepository>();
      final todo = await repository.fetchTodo(todoId);
      if (mounted) {
        setState(() {
          todoResponse =
              'Title: ${todo.title}\n'
              'Projects: ${todo.projects.map((p) => p.name).join(", ")}';
        });
      }
    } catch (e) {
      McgLogger.e('Miji', 'Error fetching todo: $e');
      if (mounted) {
        setState(() {
          todoResponse = 'Error: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    McgLogger.i('Miji', 'Current run baseUrl: ${env.baseUrl}');
    return BlocBuilder<ThemeBloc, ThemeState>(
      builder: (context, state) {
        return MaterialApp(
          themeMode: _convertAppThemeMode(state.themeMode),
          darkTheme: ThemeData.dark(),
          home: Scaffold(
            appBar: AppBar(title: const Text('Env Testing')),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('API Key: ${env.apiKey}'),
                  if (todoResponse != null)
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(todoResponse!),
                    ),
                  ElevatedButton(
                    onPressed:
                        () => _fetchTodo('20250426091357948402500786969162'),
                    child: const Text('Fetch Todo'),
                  ),
                ],
              ),
            ),
            floatingActionButton: FloatingActionButton(
              onPressed: () {
                context.read<ThemeBloc>().add(ToggleTheme());
              },
              child: const Icon(Icons.brightness_4),
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