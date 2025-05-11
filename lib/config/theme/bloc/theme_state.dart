import 'package:equatable/equatable.dart';
import 'package:miji/config/theme/models/custom_theme_config.dart';

enum AppThemeMode { light, dark, system }

class ThemeState extends Equatable {
  final AppThemeMode themeMode;
  final CustomThemeConfig? customThemeConfig;

  const ThemeState({
    this.themeMode = AppThemeMode.system,
    this.customThemeConfig,
  });

  factory ThemeState.initial() => const ThemeState();

  ThemeState copyWith({
    AppThemeMode? themeMode,
    CustomThemeConfig? customThemeConfig,
  }) {
    return ThemeState(
      themeMode: themeMode ?? this.themeMode,
      customThemeConfig: customThemeConfig ?? this.customThemeConfig,
    );
  }

  factory ThemeState.fromJson(Map<String, dynamic> json) {
    return ThemeState(
      themeMode: AppThemeMode.values.firstWhere(
        (e) => e.toString() == json['themeMode'],
        orElse: () => AppThemeMode.system,
      ),
      customThemeConfig:
          json['customThemeConfig'] != null
              ? CustomThemeConfig.fromJson(json['customThemeConfig'])
              : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'themeMode': themeMode.toString(),
      'customThemeConfig': customThemeConfig?.toString(),
    };
  }

  @override
  List<Object?> get props => [themeMode, customThemeConfig];
}
