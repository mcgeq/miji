// -----------------------------------------------------------------------------
//    Copyright (C) 2025 mcge. All rights reserved.
// Author:         mcge
// Email:          <mcgeq@outlook.com>
// File:           env.dart
// Description:    About environment
// Create   Date:  2025-05-10 20:34:09
// Last Modified:  2025-05-10 20:51:50
// Modified   By:  mcgeq <mcgeq@outlook.com>
// -----------------------------------------------------------------------------

enum EnvironmentType { dev, prod }

abstract class EnvironmentConfig {
  String get baseUrl;
  String get apiKey;
}
