import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mcge_pisces/providers/theme_controller.dart';

class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Provider.of<ThemeController>(context);

    return FloatingActionButton(
      onPressed: () {
        final isDark = themeController.themeMode == ThemeMode.dark;
        themeController.toggleTheme(!isDark);
      },
      backgroundColor: Theme.of(context).colorScheme.primary,
      child: Icon(
        themeController.themeMode == ThemeMode.dark
            ? Icons.light_mode
            : Icons.dark_mode,
        color: Colors.white,
      ),
    );
  }
}
