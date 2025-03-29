import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'dart:developer' as developer;
import 'package:path_provider/path_provider.dart';

enum LogLevel { verbose, debug, info, warning, error }

class McgLogger {
  // 单例
  static final McgLogger _instance = McgLogger._internal();
  factory McgLogger() => _instance;
  McgLogger._internal();

  // config
  static LogLevel minLevel = LogLevel.debug;
  static bool enableFileLogging = false;
  static bool enableConsoleColors = true;
  static bool enableFileColors = false;
  static int levelWidth = 7;
  static int tagWidth = 10;
  static int functionWidth = 15;
  static int lineNumberWidth = 4;
  static bool enableColors = kDebugMode; // 默认在调试模式启用颜色

  // 上下文收集器
  static final List<ContextCollector> _contextCollectors = [];
  static late final String _logFilePath;

  // ANSI颜色代码
  static const _ansiReset = '\x1B[0m';
  static const _colorCodes = {
    LogLevel.verbose: '\x1B[37m', // 白色
    LogLevel.debug: '\x1B[34m', // 蓝色
    LogLevel.info: '\x1B[32m', // 绿色
    LogLevel.warning: '\x1B[33m', // 黄色
    LogLevel.error: '\x1B[31m', // 红色
  };

  // 初始化
  static Future<void> init({
    bool enableFileLogging = false,
    LogLevel minLevel = LogLevel.debug,
  }) async {
    McgLogger.minLevel = minLevel;
    McgLogger.enableFileLogging = enableFileLogging;
    if (enableFileLogging) {
      final directory = await getApplicationDocumentsDirectory();
      _logFilePath = '${directory.path}/app_log.txt';
      final file = File(_logFilePath);
      if (!await file.exists()) {
        await file.create();
      }
      _log(
        'Logger',
        LogLevel.info,
        'Logger initialized with file logging at $_logFilePath',
      );
    } else {
      _logFilePath = '';
      _log('Logger', LogLevel.info, 'Logger initialized without file logging');
    }
  }

  // 注册上下文收集器
  static void registerContextCollector(ContextCollector collector) {
    _contextCollectors.add(collector);
  }

  // 日志快捷方法
  static void v(String tag, String message) {
    _log(tag, LogLevel.verbose, message);
  }

  static void d(String tag, String message) {
    _log(tag, LogLevel.debug, message);
  }

  static void i(String tag, String message) {
    _log(tag, LogLevel.info, message);
  }

  static void w(String tag, String message) {
    _log(tag, LogLevel.warning, message);
  }

  // 内部日志处理
  static void _log(String tag, LogLevel level, String message) {
    _logInternal(tag, level, message, StackTrace.current);
  }

  // 通用日志方法
  static void _logInternal(
    String tag,
    LogLevel level,
    String message,
    StackTrace stackTrace, {
    Object? error,
    StackTrace? errorStackTrace,
  }) {
    if (level.index < minLevel.index) return;

    final callerInfo = _getCallerInfo(stackTrace);
    final timestamp = _formatDateTime(DateTime.now());
    // 原始级别文本
    final rawLevelName = level.toString().split('.').last.toUpperCase();
    // 着色后的级别文本
    final coloredLevel = _colorize(
      _alignCenter(rawLevelName, levelWidth), // 先居中，后着色
      level,
    );

    final alignedTag = _alignCenter(tag, tagWidth);
    final alignedFunc = _alignCenter(callerInfo.function, functionWidth);
    final lineNumber = callerInfo.line.toString().padLeft(
      lineNumberWidth,
    ); // 行号4字符右对齐
    // 日志消息（控制台用带颜色版本，文件用原始版本）
    final coloredLogMessage =
        '[$timestamp] '
        '[$coloredLevel] ' // 使用着色后的级别
        '[$alignedTag] '
        '[${callerInfo.file}:$lineNumber] '
        '[$alignedFunc] $message';

    final logMessage =
        '[$timestamp] '
        '[${_alignCenter(rawLevelName, levelWidth)}] ' // 文件日志用原始文本
        '[$alignedTag] '
        '[${callerInfo.file}:$lineNumber] '
        '[$alignedFunc] $message';
    // 控制台输出
    if (kDebugMode) {
      developer.log(
        enableConsoleColors ? coloredLogMessage : logMessage,
        name: tag,
        level: level.index,
        error: error,
        stackTrace: errorStackTrace,
      );
    }

    // 文件记录
    if (enableFileLogging && _logFilePath.isNotEmpty) {
      _writeToFile(logMessage, error, errorStackTrace);
    }
  }

  // 上下文处理
  static Future<Map<String, dynamic>> _collectContext([
    Map<String, dynamic>? extra,
  ]) async {
    final context = <String, dynamic>{};
    try {
      for (final collector in _contextCollectors) {
        context.addAll(
          await collector().timeout(
            const Duration(seconds: 1),
            onTimeout: () => {'timeout': 'Context collection timeout'},
          ),
        );
      }
      if (extra != null) context.addAll(extra);
    } catch (e) {
      context['context_error'] = e.toString();
    }
    return context;
  }

  static String _buildContextMessage(
    String message,
    Map<String, dynamic> context,
  ) {
    if (context.isEmpty) return message;

    final buffer = StringBuffer(message)..writeln('\n╔════[ Context ]════');
    context.forEach((k, v) => buffer.writeln('║ $k: ${_formatValue(v)}'));
    buffer.write('╚══════════════════');
    return buffer.toString();
  }

  // 获取调用者信息
  static _CallerInfo _getCallerInfo(StackTrace stackTrace) {
    final lines = stackTrace.toString().split('\n');
    for (final line in lines) {
      final match = RegExp(
        r'^#\d+\s+(.+?)\s+\((.*?):(\d+):\d+\)$',
      ).firstMatch(line.trim());

      if (match != null) {
        final function = match.group(1)!;
        final filePath = match.group(2)!;
        final lineNumber = int.parse(match.group(3)!);

        if (!function.startsWith('McgLogger.')) {
          final fileName = filePath.split('/').last.split('?').first;
          return _CallerInfo(fileName, lineNumber, function);
        }
      }
    }
    return _CallerInfo('unknown', 0, 'unknown');
  }

  // 文件写入
  static Future<void> _writeToFile(
    String message, [
    Object? error,
    StackTrace? stackTrace,
  ]) async {
    try {
      final file = File(_logFilePath);
      final sink = file.openWrite(mode: FileMode.append);
      sink.writeln(message);
      if (error != null) sink.writeln('Error: $error');
      if (stackTrace != null) sink.writeln('StackTrace: $stackTrace');
      await sink.flush();
      await sink.close();
    } catch (e) {
      developer.log(
        'Failed to write log to file: $e',
        name: 'Logger',
        level: LogLevel.error.index,
      );
    }
  }

  static Future<void> e(
    String tag,
    String message, [
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? extraContext,
  ]) async {
    final context = await _collectContext(extraContext);
    final fullMessage = _buildContextMessage(message, context);
    _logInternal(
      tag,
      LogLevel.error,
      fullMessage,
      StackTrace.current,
      error: error,
      errorStackTrace: stackTrace,
    );
  }

  static String _colorize(String text, LogLevel level) =>
      enableConsoleColors ? '${_colorCodes[level]}$text$_ansiReset' : text;

  // 新增时间格式工具方法
  static String _formatDateTime(DateTime dt) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final String microseconds = dt.microsecond.toString().padLeft(6, '0');

    return '${dt.year}-'
        '${twoDigits(dt.month)}-'
        '${twoDigits(dt.day)} '
        '${twoDigits(dt.hour)}:'
        '${twoDigits(dt.minute)}:'
        '${twoDigits(dt.second)}.$microseconds';
  }

  // 新增字符串居中对齐方法
  static String _alignCenter(String str, int width) {
    if (str.length >= width) return str;
    final padding = width - str.length;
    final leftPadding = padding ~/ 2;
    final rightPadding = padding - leftPadding;
    return ' ' * leftPadding + str + ' ' * rightPadding;
  }

  static String _formatValue(dynamic value) {
    if (value is Map || value is Iterable) {
      return const JsonEncoder.withIndent('  ').convert(value);
    }
    return value.toString();
  }
}

class _CallerInfo {
  final String file;
  final int line;
  final String function;

  _CallerInfo(this.file, this.line, this.function);
}

typedef ContextCollector = Future<Map<String, dynamic>> Function();
