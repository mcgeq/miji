// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'l10n.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get home => 'Inicio';

  @override
  String get profile => 'Perfil';

  @override
  String get settings => 'Configuración';

  @override
  String get menu => 'Menú';

  @override
  String get profileDescription => 'Esta es tu página de perfil.';

  @override
  String get themeSettings => 'Configuración de Tema';

  @override
  String get toggleTheme => 'Cambiar Tema';

  @override
  String get languageSettings => 'Configuración de Idioma';

  @override
  String error(Object message) {
    return 'Error: $message';
  }

  @override
  String get addTodo => 'Agregar';

  @override
  String get todoHint => 'Ingresa una nueva tarea';

  @override
  String get deleteTodo => 'Eliminar';
}
