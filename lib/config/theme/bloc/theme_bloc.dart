import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive/hive.dart';
import 'package:miji/config/theme/bloc/theme_event.dart';
import 'package:miji/config/theme/bloc/theme_state.dart';
import 'package:miji/config/theme/models/custom_theme_config.dart';

class ThemeBloc extends Bloc<ThemeEvent, ThemeState> {
  ThemeBloc() : super(ThemeState.initial()) {
    _loadSavedTheme();
    on<ToggleTheme>(_onToggleTheme);
    on<UpdateCustomTheme>(_onUpdateCustomTheme);
  }

  Future<void> _loadSavedTheme() async {
    final themeModeBox = Hive.box<String>('theme_mode_box');
    final customThemeBox = Hive.box<CustomThemeConfig>('custom_theme_box');

    final savedMode = themeModeBox.get('theme_mode');
    final customConfig = customThemeBox.get('custom_theme_config');

    if (savedMode != null) {
      add(ToggleTheme());
    }
    if (customConfig != null) {
      add(UpdateCustomTheme(config: customConfig));
    }
  }

  Future<void> _onToggleTheme(
    ToggleTheme event,
    Emitter<ThemeState> emit,
  ) async {
    final currentMode = state.themeMode;
    final newMode = ThemeMode.values[(currentMode.index + 1) % 3];
    emit(state.copyWith(themeMode: newMode));
    final box = Hive.box<String>('theme_mode_box');
    await box.put('theme_mode', newMode.toString().split('.').last);
  }

  Future<void> _onUpdateCustomTheme(
    UpdateCustomTheme event,
    Emitter<ThemeState> emit,
  ) async {
    emit(state.copyWith(customThemeConfig: event.config));
    final box = Hive.box<CustomThemeConfig>('theme_box');
    await box.put('custom_theme_config', event.config);
  }
}