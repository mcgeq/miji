// -----------------------------------------------------------------------------
//    Copyright (C) 2025 mcge. All rights reserved.
// Author:         mcge
// Email:          <mcgeq@outlook.com>
// File:           main.dart
// Description:    About Flutter main
// Create   Date:  2025-03-29 16:27:14
// Last Modified:  2025-05-11 12:55:18
// Modified   By:  mcgeq <mcgeq@outlook.com>
// -----------------------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:miji/app/app.dart';
import 'package:miji/config/environment/env.dart';
import 'package:miji/config/environment/env_config.dart';
import 'package:miji/di/injector.dart';
import 'package:miji/services/logging/miji_logging.dart';
import 'package:path_provider/path_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: 'assets/.env');
  McgLogger.init(enableFileLogging: true, minLevel: LogLevel.verbose);
  loadEnvironment(EnvironmentType.dev);
  setupDependencies();
  final storageDirectory = await getApplicationDocumentsDirectory();
  HydratedBloc.storage = await HydratedStorage.build(
    storageDirectory: HydratedStorageDirectory(storageDirectory.path),
  );
  runApp(const Miji());
}
