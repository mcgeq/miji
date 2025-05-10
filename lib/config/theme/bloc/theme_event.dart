import 'package:equatable/equatable.dart';
import 'package:miji/config/theme/models/custom_theme_config.dart';

abstract class ThemeEvent extends Equatable {
  const ThemeEvent();
  @override
  List<Object?> get props => [];
}

class ToggleTheme extends ThemeEvent {}

class UpdateCustomTheme extends ThemeEvent {
  final CustomThemeConfig config;
  const UpdateCustomTheme({required this.config});

  @override
  List<Object?> get props => [config];
}
