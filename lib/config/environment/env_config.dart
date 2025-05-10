// -----------------------------------------------------------------------------
//    Copyright (C) 2025 mcge. All rights reserved.
// Author:         mcge
// Email:          <mcgeq@outlook.com>
// File:           env_config.dart
// Description:    About Env config
// Create   Date:  2025-05-10 20:35:59
// Last Modified:  2025-05-10 20:57:35
// Modified   By:  mcgeq <mcgeq@outlook.com>
// -----------------------------------------------------------------------------

import 'package:miji/config/environment/env.dart';
import 'package:miji/config/environment/dev.dart';
import 'package:miji/config/environment/prod.dart';

late final EnvironmentConfig env;

void loadEnvironment(EnvironmentType type) {
  switch (type) {
    case EnvironmentType.dev:
      env = DevConfig();
      break;
    case EnvironmentType.prod:
      env = ProdConfig();
      break;
  }
}