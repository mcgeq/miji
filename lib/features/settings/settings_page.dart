import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:miji/config/theme/app_colors.dart';
import 'package:miji/config/theme/bloc/theme_bloc.dart';
import 'package:miji/config/theme/bloc/theme_event.dart';
import 'package:miji/l10n/l10n.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.of(context)!.themeSettings,
                style: AppColors.headerText,
              ),
              const SizedBox(height: 8),
              ListTile(
                title: Text(
                  AppLocalizations.of(context)!.toggleTheme,
                  style: AppColors.bodyText,
                ),
                trailing: const Icon(Icons.brightness_4),
                onTap: () {
                  context.read<ThemeBloc>().add(ToggleTheme());
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}