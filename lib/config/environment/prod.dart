import 'package:miji/config/environment/env.dart';

class ProdConfig implements EnvironmentConfig {
  @override
  String get baseUrl => 'https://api.mcgeq.com';

  @override
  String get apiKey => 'mcgeq-prod';
}
