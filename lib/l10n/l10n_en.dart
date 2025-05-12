// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'l10n.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get home => 'Home';

  @override
  String get profile => 'Profile';

  @override
  String get settings => 'Settings';

  @override
  String get menu => 'Menu';

  @override
  String get profileDescription => 'This is your profile page.';

  @override
  String get themeSettings => 'Theme Settings';

  @override
  String get toggleTheme => 'Toggle Theme';

  @override
  String get languageSettings => 'Language Settings';

  @override
  String error(Object message) {
    return 'Error: $message';
  }

  @override
  String get addTodo => 'Add Todo';

  @override
  String get todoHint => 'Enter a new todo';

  @override
  String get deleteTodo => 'Delete';
}
