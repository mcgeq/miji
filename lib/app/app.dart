import 'package:flutter/material.dart';
import 'package:miji/config/environment/env_config.dart';

class Miji extends StatelessWidget {
  const Miji({super.key});
  @override
  Widget build(BuildContext context) {
    debugPrint('Current run baseUrl: ${env.baseUrl}');
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Env Testing')),
        body: Center(child: Text('API Key: ${env.apiKey}')),
      ),
    );
  }
}