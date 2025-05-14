import 'package:miji/config/environment/env.dart';

class DevConfig implements EnvironmentConfig {
  @override
  String get baseUrl => 'http://192.168.31.119:9428';

  @override
  String get apiKey => 'mcgeq-dev';
}
