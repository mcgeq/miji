import 'package:flutter/material.dart';
import 'package:miji/features/mine/profile_page.dart' as mine_view;

class ProfilePage extends StatelessWidget {
  static const String routeName = '/mine';

  const ProfilePage({super.key});

  static Route<void> route() {
    return MaterialPageRoute(
      builder: (_) => const ProfilePage(),
      settings: const RouteSettings(name: routeName),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const mine_view.ProfilePage();
  }
}