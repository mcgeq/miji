import 'package:dio/dio.dart' as dio;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';

/// A singleton class for managing HTTP requests using Dio with smart dialog
/// notifications.
class XHttp {
  static const String get = 'GET';
  // ignore: unused_field
  static const String post = 'POST';
  // ignore: unused_field
  static const String put = 'PUT';
  // ignore: unused_field
  static const String patch = 'PATCH';
  // ignore: unused_field
  static const String delete = 'DELETE';

  static const String customErrorCode = 'DIO_CUSTOM_ERROR';
  static const String requestType = 'REQUEST';
  static const String responseType = 'RESPONSE';
  static const String errorType = 'RESPONSE_ERROR';
  static const String defaultLoadMsg = 'Loading...';

  static const int connectTimeout = 60000;
  static const int receiveTimeout = 60000;
  static const int sendTimeout = 60000;

  static const String dialogTypeOthers = 'OTHERS';
  static const String dialogTypeToast = 'TOAST';
  static const String dialogTypeAlert = 'ALERT';
  static const String dialogTypeCustom = 'CUSTOM';

  static String loadMsg = defaultLoadMsg;
  static String errorShowTitle = 'An error occurred';
  static String errorShowMsg = '';

  static dio.CancelToken cancelToken = dio.CancelToken();
  static dio.CancelToken whiteListCancelToken = dio.CancelToken();

  final Map<String, dio.CancelToken> _pendingRequests = {};
  static final dio.Dio _dio = dio.Dio();
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  /// Private constructor for singleton pattern.
  XHttp._internal() {
    if (_dio.options.baseUrl.isEmpty) {
      _dio.options = dio.BaseOptions(
        baseUrl: _getBaseUrl(),
        headers: {'Content-Type': 'application/json'},
        connectTimeout: const Duration(milliseconds: connectTimeout),
        receiveTimeout: const Duration(milliseconds: receiveTimeout),
        sendTimeout: const Duration(milliseconds: sendTimeout),
        extra: {'cancelDuplicatedRequest': true},
      );
      _init();
    }
  }

  static final XHttp _instance = XHttp._internal();

  /// Loads baseUrl from .env or returns a fallback.
  String _getBaseUrl() {
    return dotenv.env['API_BASE_URL'] ?? 'https://api.example.com';
  }

  /// Initializes Dio with interceptors.
  void _init() {
    _dio.interceptors.add(
      dio.InterceptorsWrapper(
        onRequest: (options, handler) async {
          if (kDebugMode) debugPrint('Request: ${options.uri}');

          // Add token from secure storage
          final String? token = await _secureStorage.read(key: 'auth_token');
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }

          if (_dio.options.extra['cancelDuplicatedRequest'] == true &&
              options.cancelToken == null) {
            final String tokenKey = _generateRequestKey(options);
            _removePendingRequest(tokenKey);
            options.cancelToken = dio.CancelToken();
            options.extra['tokenKey'] = tokenKey;
            _pendingRequests[tokenKey] = options.cancelToken!;
          }
          _handleRequest(options, handler);
          return handler.next(options);
        },
        onResponse: (response, handler) {
          if (kDebugMode) debugPrint('Response: ${response.statusCode}');
          _handleResponse(response, handler);
          if (_dio.options.extra['cancelDuplicatedRequest'] == true) {
            _removePendingRequest(response.requestOptions.extra['tokenKey']);
          }
          final bool isSuccess =
              response.statusCode == 200 || response.statusCode == 201;
          final String? message =
              response.data is Map
                  ? response.data['message']?.toString()
                  : response.statusMessage;
          response.data = Result(
            data: response.data,
            success: isSuccess,
            code: response.statusCode ?? 500,
            message: message ?? 'Unknown error',
            headers: response.headers,
          );
          return handler.next(response);
        },
        onError: (error, handler) {
          if (kDebugMode) debugPrint('Error: ${error.message}');
          _handleError(error);
          if (!dio.CancelToken.isCancel(error) &&
              _dio.options.extra['cancelDuplicatedRequest'] == true) {
            _pendingRequests.clear();
          }
          if (error.response != null && error.response?.data != null) {
            error.response!.data = Result(
              data: error.response?.data,
              success: false,
              code: error.response!.statusCode ?? 500,
              message:
                  errorShowMsg.isNotEmpty
                      ? errorShowMsg
                      : error.response!.statusMessage ?? 'Unknown error',
              headers: error.response?.headers,
            );
          }
          return handler.next(error);
        },
      ),
    );
  }

  /// Generates a unique key for request deduplication.
  String _generateRequestKey(dio.RequestOptions options) {
    return [
      options.method,
      options.uri.toString(),
      options.data?.toString() ?? '',
      options.queryParameters.toString(),
    ].join('&');
  }

  /// Cancels a pending request by token key.
  void _removePendingRequest(String tokenKey) {
    if (_pendingRequests.containsKey(tokenKey)) {
      _pendingRequests[tokenKey]?.cancel(tokenKey);
      _pendingRequests.remove(tokenKey);
    }
  }

  /// Handles request logging and shows loading dialog.
  void _handleRequest(
    dio.RequestOptions options,
    dio.RequestInterceptorHandler handler,
  ) {
    Toast.instance.hide();
    Toast.instance.loading(loadMsg);
    _logRequest({
      'url': options.uri.toString(),
      'method': options.method,
      'headers': options.headers,
      'data': options.data ?? options.queryParameters,
    }, requestType);
  }

  /// Handles response logging and hides loading dialog.
  void _handleResponse(
    dio.Response response,
    dio.ResponseInterceptorHandler handler,
  ) {
    _logRequest({
      'url': response.requestOptions.uri.toString(),
      'method': response.requestOptions.method,
      'headers': response.headers,
      'data': response.data,
      'statusCode': response.statusCode,
      'statusMessage': response.statusMessage,
    }, responseType);
    Toast.instance.hide();
  }

  /// Handles error logging and shows error notification.
  void _handleError(dio.DioException error) {
    String errorTypeInfo;
    switch (error.type) {
      case dio.DioExceptionType.connectionTimeout:
        errorTypeInfo = 'Connection timeout';
        break;
      case dio.DioExceptionType.sendTimeout:
        errorTypeInfo = 'Request timeout';
        break;
      case dio.DioExceptionType.receiveTimeout:
        errorTypeInfo = 'Response timeout';
        break;
      case dio.DioExceptionType.badResponse:
        errorTypeInfo = _handleStatusCode(error.response?.statusCode);
        break;
      case dio.DioExceptionType.cancel:
        errorTypeInfo = 'Request cancelled';
        break;
      default:
        errorTypeInfo = 'Network error';
    }
    _logRequest({
      'url': error.requestOptions.uri.toString(),
      'method': error.requestOptions.method,
      'headers': error.response?.headers,
      'data': error.response?.data,
      'statusCode': error.response?.statusCode,
      'statusMessage': error.response?.statusMessage,
      'errorType': error.type,
      'errorMessage': error.message,
      'errorTypeInfo': errorTypeInfo,
    }, errorType);
    Toast.instance.hide();
    errorShowMsg =
        '$errorShowTitle ${error.response?.statusCode ?? 'unknown'} '
        '$errorTypeInfo\n'
        '${error.response?.statusMessage ?? error.message ?? ''}';
  }

  /// Maps HTTP status codes to user-friendly messages.
  String _handleStatusCode(int? statusCode) {
    switch (statusCode) {
      case 401:
        return 'Unauthorized: Please log in again';
      case 403:
        return 'Forbidden: Access denied';
      case 404:
        return 'Resource not found';
      case 500:
        return 'Server error';
      default:
        return 'Service error';
    }
  }

  /// Logs request/response/error details.
  String _logRequest(Map logData, String logType) {
    final StringBuffer logStr =
        StringBuffer()
          ..writeln(
            '======================== $logType START ========================',
          )
          ..writeln('- URL: ${logData['url']}')
          ..writeln('- METHOD: ${logData['method']}');
    if (logData['data'] != null) {
      logStr.writeln('- ${logType}_BODY:\n${parseData(logData['data'])}');
    }
    if (logType.contains(responseType) || logType.contains(errorType)) {
      logStr
        ..writeln('- STATUS_CODE: ${logData['statusCode']}')
        ..writeln('- STATUS_MESSAGE: ${logData['statusMessage']}');
    }
    if (logType == errorType) {
      logStr
        ..writeln('- ERROR_TYPE: ${logData['errorType']}')
        ..writeln('- ERROR_MESSAGE: ${logData['errorMessage']}')
        ..writeln('- ERROR_TYPE_INFO: ${logData['errorTypeInfo']}');
    }
    logStr.writeln(
      '======================== $logType END ========================',
    );
    logWrapped(logStr.toString());
    return logStr.toString();
  }

  /// Displays result dialogs or notifications based on configuration.
  Future<void> _showResultDialog(
    dio.Response? response,
    Map<String, dynamic>? config,
  ) async {
    if (response == null) return;
    final Map<String, dynamic> configMap = config ?? {};
    final String dialogType = configMap['type'] ?? dialogTypeOthers;
    if (dialogType == dialogTypeOthers) return;

    final bool isSuccess = response.data.success;
    final String msg = response.data.message ?? 'Unknown error';

    if (dialogType == dialogTypeToast) {
      Toast.instance.show(
        isSuccess
            ? configMap['successMsg'] ?? msg
            : configMap['errorMsg'] ?? msg,
        type: isSuccess ? Toast.success : Toast.error,
      );
    } else if (dialogType == dialogTypeAlert) {
      // Implement alert dialog (e.g., using showDialog)
    } else if (dialogType == dialogTypeCustom) {
      if (isSuccess && configMap['onSuccess'] != null) {
        configMap['onSuccess'](response.data);
      } else if (!isSuccess && configMap['onError'] != null) {
        configMap['onError'](response.data);
      }
    }
  }

  /// Handles non-Dio exceptions and displays notifications.
  void _catchOthersError(dynamic e) {
    final String errMsg =
        '${errorShowMsg.isEmpty ? e.toString() : errorShowMsg}$customErrorCode'
            .split(customErrorCode)[0];
    final String truncatedMsg =
        errMsg.length > 300 ? errMsg.substring(0, 150) : errMsg;
    if (e is dio.DioException && dio.CancelToken.isCancel(e)) {
      Toast.instance.show('Request cancelled successfully', type: Toast.info);
    } else {
      Toast.instance.show(truncatedMsg, type: Toast.error);
    }
  }

  /// Gets instance with optional baseUrl and loading message.
  static XHttp getInstance({String? baseUrl, String? msg}) {
    if (baseUrl != null && baseUrl.isNotEmpty) {
      _dio.options.baseUrl = baseUrl;
    }
    loadMsg = msg ?? defaultLoadMsg;
    return _instance;
  }

  /// Cancels all non-whitelisted requests.
  static XHttp cancelRequest() {
    Toast.instance.hide();
    if (_dio.options.extra['cancelDuplicatedRequest'] == true) {
      _instance._pendingRequests.forEach((key, token) => token.cancel(key));
      _instance._pendingRequests.clear();
    } else {
      cancelToken.cancel('Cancel request');
      cancelToken = dio.CancelToken();
    }
    return _instance;
  }

  /// Cancels all whitelisted requests.
  static XHttp cancelWhiteListRequest() {
    Toast.instance.hide();
    whiteListCancelToken.cancel('Cancel whitelist request');
    whiteListCancelToken = dio.CancelToken();
    return _instance;
  }

  /// Unified request method for all HTTP methods.
  Future<Result> request(
    String url, {
    String method = get,
    Map<String, dynamic>? queryParameters,
    dynamic data,
    bool isCancelWhiteList = false,
    Map<String, dynamic>? resultDialogConfig,
    dio.Options? options,
    void Function(int, int)? onSendProgress,
    void Function(int, int)? onReceiveProgress,
    String? msg,
    String? baseUrl,
  }) async {
    XHttp.getInstance(baseUrl: baseUrl, msg: msg);
    final dio.CancelToken requestToken =
        isCancelWhiteList ? whiteListCancelToken : cancelToken;

    try {
      final response = await _dio.request(
        url,
        options: options ?? dio.Options(method: method),
        queryParameters: queryParameters,
        data: data,
        cancelToken: requestToken,
        onReceiveProgress: onReceiveProgress,
        onSendProgress: onSendProgress,
      );
      await _showResultDialog(response, resultDialogConfig);
      return response.data as Result;
    } catch (e) {
      _catchOthersError(e);
      rethrow;
    }
  }

  /// Downloads a file and saves it to the specified path.
  Future<Result> downloadFile(
    String urlPath,
    dynamic savePath, {
    Map<String, dynamic>? resultDialogConfig,
    bool isCancelWhiteList = false,
    void Function(int, int)? onReceiveProgress,
  }) async {
    final dio.CancelToken requestToken =
        isCancelWhiteList ? whiteListCancelToken : cancelToken;
    try {
      final response = await _dio.download(
        urlPath,
        savePath,
        onReceiveProgress: onReceiveProgress,
        cancelToken: requestToken,
      );
      await _showResultDialog(response, resultDialogConfig);
      return response.data as Result;
    } catch (e) {
      _catchOthersError(e);
      rethrow;
    }
  }

  /// Sets the authorization token securely.
  static XHttp setAuthToken(String? token) {
    if (token == null) {
      _secureStorage.delete(key: 'auth_token');
      _dio.options.headers.remove('Authorization');
    } else {
      _secureStorage.write(key: 'auth_token', value: token);
      _dio.options.headers['Authorization'] = 'Bearer $token';
    }
    return _instance;
  }

  /// Gets the current baseUrl.
  static String getBaseUrl() => _dio.options.baseUrl;

  /// Sets the baseUrl.
  static XHttp setBaseUrl(String baseUrl) {
    _dio.options.baseUrl = baseUrl;
    return _instance;
  }

  /// Sets a header.
  static XHttp setHeader(String key, String value) {
    _dio.options.headers[key] = value;
    return _instance;
  }

  /// Removes a header.
  static XHttp removeHeader(String key) {
    _dio.options.headers.remove(key);
    return _instance;
  }

  /// Sets error title for notifications.
  static XHttp setErrorTitle(String msg) {
    errorShowTitle = msg;
    return _instance;
  }
}

/// Result class for standardized response handling.
class Result {
  final dynamic data;
  final bool success;
  final int code;
  final String message;
  final dio.Headers? headers;

  Result({
    required this.data,
    required this.success,
    required this.code,
    required this.message,
    this.headers,
  });
}

/// Toast utility for displaying notifications and loading dialogs using
/// flutter_smart_dialog.
/// Implemented as a singleton to provide instance behavior
/// and allow future extensibility (e.g., configurable toast settings).
class Toast {
  static const String success = 'SUCCESS';
  static const String error = 'ERROR';
  static const String warning = 'WARNING';
  static const String info = 'INFO';

  /// Singleton instance.
  static final Toast _instance = Toast._internal();

  /// Factory constructor to return the singleton instance.
  factory Toast() => _instance;

  /// Private constructor for singleton pattern.
  Toast._internal();

  /// Provides access to the singleton instance.
  static Toast get instance => _instance;

  /// Shows a loading dialog with a message.
  void loading(String msg) {
    SmartDialog.showLoading(msg: msg);
  }

  /// Shows a toast notification with custom styling based on type.
  void show(String msg, {String? type}) {
    Color backgroundColor;
    switch (type) {
      case success:
        backgroundColor = Colors.green;
        break;
      case error:
        backgroundColor = Colors.red;
        break;
      case warning:
        backgroundColor = Colors.orange;
        break;
      case info:
      default:
        backgroundColor = Colors.blue;
    }
    SmartDialog.showToast(
      '',
      builder:
          (_) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(msg, style: const TextStyle(color: Colors.white)),
          ),
    );
  }

  /// Hides the loading dialog.
  void hide() {
    SmartDialog.dismiss();
  }
}

/// Utility methods for parsing and logging.
String parseData(dynamic data) {
  if (data is Map) return data.mapToStructureString();
  if (data is dio.FormData) {
    final map = Map.fromEntries([...data.fields, ...data.files]);
    return map.mapToStructureString();
  }
  if (data is List) return data.listToStructureString();
  return data.toString();
}

void logWrapped(String text) {
  final RegExp pattern = RegExp(r'.{1,800}');
  pattern.allMatches(text).forEach((match) => debugPrint(match.group(0)));
}

extension Map2StringEx on Map {
  String mapToStructureString({int indentation = 0, String space = '  '}) {
    if (isEmpty) return '{}';
    final StringBuffer result = StringBuffer('{\n');
    final String indent = space * (indentation + 1);
    for (final entry in entries) {
      final value = entry.value;
      if (value is Map) {
        result.write(
          '$indent"${entry.key}": '
          '${value.mapToStructureString(indentation: indentation + 1)},\n',
        );
      } else if (value is List) {
        result.write(
          '$indent"${entry.key}": '
          '${value.listToStructureString(indentation: indentation + 1)},\n',
        );
      } else {
        result.write(
          '$indent"${entry.key}": '
          '${value is String ? '"$value"' : value},\n',
        );
      }
    }
    result.write(result.toString().substring(0, result.length - 2));
    result.write('\n${space * indentation}}');
    return result.toString();
  }
}

extension List2StringEx on List {
  String listToStructureString({int indentation = 0, String space = '  '}) {
    if (isEmpty) return '[]';
    final StringBuffer result = StringBuffer('[\n');
    final String indent = space * (indentation + 1);
    for (final value in this) {
      if (value is Map) {
        result.write(
          '$indent'
          '${value.mapToStructureString(indentation: indentation + 1)},\n',
        );
      } else if (value is List) {
        result.write(
          '$indent'
          '${value.listToStructureString(indentation: indentation + 1)},\n',
        );
      } else {
        result.write('$indent${value is String ? '"$value"' : value},\n');
      }
    }
    result.write(result.toString().substring(0, result.length - 2));
    result.write('\n${space * indentation}]');
    return result.toString();
  }
}