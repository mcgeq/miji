import 'package:miji/config/environment/env.dart';

class DevConfig implements EnvironmentConfig {
  @override
  String get baseUrl => 'https://127.0.0.1:9428';

  @override
  String get apiKey => 'mcgeq-dev';
}
