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

  // 配置
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
  static String _logFilePath = ''; // 默认初始化为空字符串

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
      try {
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
      } catch (e) {
        McgLogger.enableFileLogging = false;
        _logFilePath = '';
        _log('Logger', LogLevel.error, 'Failed to initialize file logging: $e');
      }
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
    final rawLevelName = level.toString().split('.').last.toUpperCase();
    final coloredLevel = _colorize(
      _alignCenter(rawLevelName, levelWidth),
      level,
    );

    final alignedTag = _alignCenter(tag, tagWidth);
    final alignedFunc = _alignCenter(callerInfo.function, functionWidth);
    final lineNumber = callerInfo.line.toString().padLeft(lineNumberWidth);

    final coloredLogMessage =
        '[$timestamp] '
        '[$coloredLevel] '
        '[$alignedTag] '
        '[${callerInfo.file}:$lineNumber] '
        '[$alignedFunc] $message';

    final logMessage =
        '[$timestamp] '
        '[${_alignCenter(rawLevelName, levelWidth)}] '
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
      debugPrint(enableConsoleColors ? coloredLogMessage : logMessage);
    }

    // 文件记录
    if (enableFileLogging && _logFilePath.isNotEmpty) {
      _writeToFile(logMessage, error, errorStackTrace);
    }
  }

  // 优化后的上下文收集（并行执行）
  static Future<Map<String, dynamic>> _collectContext([
    Map<String, dynamic>? extra,
  ]) async {
    final context = <String, dynamic>{};
    try {
      if (_contextCollectors.isNotEmpty) {
        final futures = _contextCollectors.map(
          (collector) => collector().timeout(
            const Duration(seconds: 1),
            onTimeout: () => {'timeout': 'Context collection timeout'},
          ),
        );
        final results = await Future.wait(futures); // 并行执行
        for (final result in results) {
          context.addAll(result);
        }
      }
      if (extra != null) context.addAll(extra);
    } catch (e) {
      context['context_error'] = e.toString();
    }
    return context;
  }

  // 构建上下文消息
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

  // 错误日志与上下文
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

  // 着色文本
  static String _colorize(String text, LogLevel level) =>
      enableConsoleColors ? '${_colorCodes[level]}$text$_ansiReset' : text;

  // 格式化日期和时间
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

  // 字符串居中对齐
  static String _alignCenter(String str, int width) {
    if (str.length >= width) return str;
    final padding = width - str.length;
    final leftPadding = padding ~/ 2;
    final rightPadding = padding - leftPadding;
    return ' ' * leftPadding + str + ' ' * rightPadding;
  }

  // 格式化上下文值
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