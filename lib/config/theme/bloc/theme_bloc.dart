import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:miji/config/theme/bloc/theme_event.dart';
import 'package:miji/config/theme/bloc/theme_state.dart';

class ThemeBloc extends HydratedBloc<ThemeEvent, ThemeState> {
  ThemeBloc() : super(ThemeState.initial()) {
    on<ToggleTheme>(_onToggleTheme);
    on<UpdateCustomTheme>(_onUpdateCustomTheme);
  }

  void _onToggleTheme(ToggleTheme event, Emitter<ThemeState> emit) {
    final newMode = _nextThemeMode(state.themeMode);
    emit(state.copyWith(themeMode: newMode));
  }

  void _onUpdateCustomTheme(UpdateCustomTheme event, Emitter<ThemeState> emit) {
    emit(state.copyWith(customThemeConfig: event.config));
  }

  AppThemeMode _nextThemeMode(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.light:
        return AppThemeMode.dark;
      case AppThemeMode.dark:
        return AppThemeMode.system;
      case AppThemeMode.system:
        return AppThemeMode.light;
    }
  }

  @override
  ThemeState? fromJson(Map<String, dynamic> json) {
    return ThemeState.fromJson(json);
  }

  @override
  Map<String, dynamic>? toJson(ThemeState state) {
    return state.toJson();
  }
}