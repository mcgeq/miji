import 'package:flutter/material.dart';
import 'package:miji/features/home/view/home_page.dart' as home_view;

class HomePage extends StatelessWidget {
  static const String routeName = '/home';

  const HomePage({super.key});

  static Route<void> route() {
    return MaterialPageRoute(
      builder: (_) => const HomePage(),
      settings: const RouteSettings(name: routeName),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const home_view.HomePage();
  }
}