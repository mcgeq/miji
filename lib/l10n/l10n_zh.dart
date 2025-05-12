// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'l10n.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get home => '首页';

  @override
  String get profile => '我的';

  @override
  String get settings => '设置';

  @override
  String get menu => '菜单';

  @override
  String get profileDescription => '这是您的个人页面。';

  @override
  String get themeSettings => '主题设置';

  @override
  String get toggleTheme => '切换主题';

  @override
  String get languageSettings => '语言设置';

  @override
  String error(Object message) {
    return '错误：$message';
  }

  @override
  String get addTodo => '添加待办';

  @override
  String get todoHint => '输入新的待办事项';

  @override
  String get deleteTodo => '删除';
}
