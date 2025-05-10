// -----------------------------------------------------------------------------
//    Copyright (C) 2025 mcge. All rights reserved.
// Author:         mcge
// Email:          <mcgeq@outlook.com>
// File:           main.dart
// Description:    About Flutter main
// Create   Date:  2025-03-29 16:27:14
// Last Modified:  2025-05-11 00:30:18
// Modified   By:  mcgeq <mcgeq@outlook.com>
// -----------------------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive/hive.dart';
import 'package:miji/app/app.dart';
import 'package:miji/config/environment/env.dart';
import 'package:miji/config/environment/env_config.dart';
import 'package:miji/config/theme/bloc/theme_bloc.dart';
import 'package:miji/config/theme/models/custom_theme_config.dart';
import 'package:miji/hive/adapters/text_theme_adapter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Hive.init('.');
  await Hive.openBox<CustomThemeConfig>('theme_box');
  final themeBox = Hive.box<CustomThemeConfig>('theme_box');
  if (themeBox.isEmpty) {
    final defaultTextTheme = ThemeData.light().textTheme;
    final config = CustomThemeConfig(
      primaryColor: Colors.blue,
      backgroundColor: Colors.white,
      textTheme: defaultTextTheme,
    );
    themeBox.put('current_theme', config);
  }
  Hive.registerAdapter(TextThemeAdapter());
  loadEnvironment(EnvironmentType.dev);
  final themeBloc = ThemeBloc();

  runApp(BlocProvider(create: (context) => themeBloc, child: const Miji()));
}
