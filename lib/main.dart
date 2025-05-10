// -----------------------------------------------------------------------------
//    Copyright (C) 2025 mcge. All rights reserved.
// Author:         mcge
// Email:          <mcgeq@outlook.com>
// File:           main.dart
// Description:    About Flutter main
// Create   Date:  2025-03-29 16:27:14
// Last Modified:  2025-05-10 21:20:46
// Modified   By:  mcgeq <mcgeq@outlook.com>
// -----------------------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:miji/app/app.dart';
import 'package:miji/config/environment/env.dart';
import 'package:miji/config/environment/env_config.dart';

void main() {
  loadEnvironment(EnvironmentType.dev);
  runApp(const Miji());
}