import 'package:equatable/equatable.dart';
import 'package:miji/config/theme/models/custom_theme_config.dart';

enum ThemeMode { light, dart, system }

class ThemeState extends Equatable {
  final ThemeMode themeMode;
  final CustomThemeConfig? customThemeConfig;

  const ThemeState({this.themeMode = ThemeMode.system, this.customThemeConfig});

  factory ThemeState.initial() => const ThemeState();

  ThemeState copyWith({
    ThemeMode? themeMode,
    CustomThemeConfig? customThemeConfig,
  }) {
    return ThemeState(
      themeMode: themeMode ?? this.themeMode,
      customThemeConfig: customThemeConfig ?? this.customThemeConfig,
    );
  }

  @override
  List<Object?> get props => [themeMode, customThemeConfig];
}
