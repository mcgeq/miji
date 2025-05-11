import 'package:flutter/material.dart';
import 'package:miji/features/settings/settings_page.dart' as settings_view;

class SettingsPage extends StatelessWidget {
  static const String routeName = '/settings';

  const SettingsPage({super.key});

  static Route<void> route() {
    return MaterialPageRoute(
      builder: (_) => const SettingsPage(),
      settings: const RouteSettings(name: routeName),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const settings_view.SettingsPage();
  }
}