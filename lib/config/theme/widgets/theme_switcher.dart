import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:miji/config/theme/bloc/theme_bloc.dart';
import 'package:miji/config/theme/bloc/theme_event.dart';
import 'package:miji/config/theme/bloc/theme_state.dart' as app_theme;

class ThemeSwitcher extends StatelessWidget {
  const ThemeSwitcher({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ThemeBloc, app_theme.ThemeState>(
      builder: (context, state) {
        return DropdownButton<ThemeMode>(
          value: state.themeMode as ThemeMode?,
          items:
              ThemeMode.values.map((mode) {
                return DropdownMenuItem<ThemeMode>(
                  value: mode,
                  child: Text(mode.name.capitalize()),
                );
              }).toList(),
          onChanged: (value) {
            if (value != null) {
              context.read<ThemeBloc>().add(ToggleTheme());
            }
          },
        );
      },
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}