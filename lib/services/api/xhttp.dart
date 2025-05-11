import 'package:dio/dio.dart' as dio;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:miji/config/environment/env_config.dart';
import 'package:miji/services/logging/miji_logging.dart';

/// A singleton class for managing HTTP requests using Dio.
class XHttp {
  // HTTP Methods
  static const String get = 'GET';
  static const String post = 'POST';
  static const String put = 'PUT';
  static const String patch = 'PATCH';
  static const String delete = 'DELETE';

  // Constants
  static const String requestType = 'REQUEST';
  static const String responseType = 'RESPONSE';
  static const String errorType = 'RESPONSE_ERROR';
  static const int connectTimeout = 60000;
  static const int receiveTimeout = 60000;
  static const int sendTimeout = 60000;

  // Static Fields
  static dio.CancelToken cancelToken = dio.CancelToken();
  static dio.CancelToken whiteListCancelToken = dio.CancelToken();

  // Instance Fields
  final Map<String, dio.CancelToken> _pendingRequests = {};
  final dio.Dio _dio = dio.Dio();
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  /// Singleton instance
  static final XHttp _instance = XHttp._internal();

  factory XHttp() => _instance;

  XHttp._internal() {
    _initializeDio();
  }

  /// Initializes Dio with base configuration and interceptors.
  void _initializeDio() {
    _dio.options = dio.BaseOptions(
      baseUrl: env.baseUrl,
      headers: {'Content-Type': 'application/json'},
      connectTimeout: const Duration(milliseconds: connectTimeout),
      receiveTimeout: const Duration(milliseconds: receiveTimeout),
      sendTimeout: const Duration(milliseconds: sendTimeout),
      extra: {'cancelDuplicatedRequest': true},
    );
    _addInterceptors();
  }

  /// Adds Dio interceptors for request, response, and error handling.
  void _addInterceptors() {
    _dio.interceptors.add(
      dio.InterceptorsWrapper(
        onRequest: _handleRequestInterceptor,
        onResponse: _handleResponseInterceptor,
        onError: _handleErrorInterceptor,
      ),
    );
  }

  /// Handles request interception (e.g., adding token, deduplication).
  Future<void> _handleRequestInterceptor(
    dio.RequestOptions options,
    dio.RequestInterceptorHandler handler,
  ) async {
    McgLogger.d('XHttp', 'Request: ${options.uri}');

    // Add auth token
    final token = await _secureStorage.read(key: 'auth_token');
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }

    // Handle request deduplication
    if (_dio.options.extra['cancelDuplicatedRequest'] == true &&
        options.cancelToken == null) {
      final tokenKey = _generateRequestKey(options);
      _removePendingRequest(tokenKey);
      options.cancelToken = dio.CancelToken();
      options.extra['tokenKey'] = tokenKey;
      _pendingRequests[tokenKey] = options.cancelToken!;
    }

    _logRequest(options, requestType);
    handler.next(options);
  }

  /// Handles response interception (e.g., formatting response, logging).
  void _handleResponseInterceptor(
    dio.Response response,
    dio.ResponseInterceptorHandler handler,
  ) {
    McgLogger.d('XHttp', 'Response: ${response.statusCode}');
    _logRequest(response, responseType);

    if (_dio.options.extra['cancelDuplicatedRequest'] == true) {
      _removePendingRequest(response.requestOptions.extra['tokenKey']);
    }

    final isSuccess = response.statusCode == 200 || response.statusCode == 201;
    String message;
    if (response.data is Map<String, dynamic>) {
      final messageValue = (response.data as Map<String, dynamic>)['message'];
      message = messageValue?.toString() ?? 'No message provided';
    } else {
      message = response.statusMessage ?? 'Unknown response';
    }

    response.data = Result(
      data: response.data,
      success: isSuccess,
      code: response.statusCode ?? 500,
      message: message,
      headers: response.headers,
    );
    handler.next(response);
  }

  /// Handles error interception (e.g., formatting error, logging).
  void _handleErrorInterceptor(
    dio.DioException error,
    dio.ErrorInterceptorHandler handler,
  ) {
    McgLogger.e('XHttp', 'Error: ${error.message}', error);

    if (!dio.CancelToken.isCancel(error) &&
        _dio.options.extra['cancelDuplicatedRequest'] == true) {
      _pendingRequests.clear();
    }

    final errorInfo = _getErrorInfo(error);
    _logRequest({
      ...errorInfo,
      'url': error.requestOptions.uri.toString(),
      'method': error.requestOptions.method,
      'headers': error.response?.headers,
      'data': error.response?.data,
    }, errorType);

    if (error.response != null) {
      error.response!.data = Result(
        data: error.response?.data,
        success: false,
        code: error.response!.statusCode ?? 500,
        message: error.response!.statusMessage ?? 'Unknown error',
        headers: error.response?.headers,
      );
    }
    handler.next(error);
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

  /// Removes a pending request by token key.
  void _removePendingRequest(String? tokenKey) {
    if (tokenKey != null && _pendingRequests.containsKey(tokenKey)) {
      _pendingRequests[tokenKey]?.cancel(tokenKey);
      _pendingRequests.remove(tokenKey);
    }
  }

  /// Extracts error information based on Dio exception type.
  Map<String, dynamic> _getErrorInfo(dio.DioException error) {
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
    return {
      'statusCode': error.response?.statusCode,
      'statusMessage': error.response?.statusMessage,
      'errorType': error.type,
      'errorMessage': error.message,
      'errorTypeInfo': errorTypeInfo,
    };
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
  void _logRequest(dynamic logData, String logType) {
    final buffer = StringBuffer()
      ..writeln('===================== $logType START =====================');

    // Handle URL and METHOD based on logData type
    if (logData is dio.RequestOptions) {
      buffer
        ..writeln('- URL: ${logData.uri}')
        ..writeln('- METHOD: ${logData.method}');
    } else if (logData is dio.Response) {
      buffer
        ..writeln('- URL: ${logData.requestOptions.uri}')
        ..writeln('- METHOD: ${logData.requestOptions.method}');
    } else if (logData is Map) {
      buffer
        ..writeln('- URL: ${logData['url']}')
        ..writeln('- METHOD: ${logData['method']}');
    }

    if (logData is dio.RequestOptions && logData.data != null) {
      buffer.writeln('- ${logType}_BODY:\n${parseData(logData.data)}');
    } else if (logData is dio.Response && logData.data != null) {
      buffer.writeln('- ${logType}_BODY:\n${parseData(logData.data)}');
    } else if (logData is Map && logData['data'] != null) {
      buffer.writeln('- ${logType}_BODY:\n${parseData(logData['data'])}');
    }

    if (logType == responseType || logType == errorType) {
      final statusCode = logData is dio.Response
          ? logData.statusCode
          : logData is Map
              ? logData['statusCode']
              : null;
      final statusMessage = logData is dio.Response
          ? logData.statusMessage
          : logData is Map
              ? logData['statusMessage']
              : null;
      buffer
        ..writeln('- STATUS_CODE: $statusCode')
        ..writeln('- STATUS_MESSAGE: $statusMessage');
    }

    if (logType == errorType && logData is Map) {
      buffer
        ..writeln('- ERROR_TYPE: ${logData['errorType']}')
        ..writeln('- ERROR_MESSAGE: ${logData['errorMessage']}')
        ..writeln('- ERROR_TYPE_INFO: ${logData['errorTypeInfo']}');
    }

    buffer.writeln('===================== $logType END =====================');

    logType == errorType
        ? McgLogger.e('XHttp', buffer.toString())
        : McgLogger.d('XHttp', buffer.toString());
  }

  /// Parses data for logging.
  String parseData(dynamic data) {
    try {
      if (data is Map) {
        return data.mapToStructureString();
      }
      if (data is dio.FormData) {
        final map = Map.fromEntries([...data.fields, ...data.files]);
        return map.mapToStructureString();
      }
      if (data is List) {
        return data.listToStructureString();
      }
      return data.toString();
    } catch (e, stackTrace) {
      McgLogger.e('XHttp', 'Failed to parse data: $e', e, stackTrace);
      return 'Error parsing data: $e';
    }
  }

  /// Handles non-Dio exceptions.
  void _catchOthersError(dynamic e) {
    if (e is dio.DioException && dio.CancelToken.isCancel(e)) {
      McgLogger.d('XHttp', 'Request cancelled successfully');
    } else {
      McgLogger.e('XHttp', 'Error: $e');
    }
  }

  // Public Methods

  /// Gets instance with optional baseUrl.
  static XHttp getInstance({String? baseUrl}) {
    if (baseUrl != null && baseUrl.isNotEmpty) {
      _instance._dio.options.baseUrl = baseUrl;
    }
    return _instance;
  }

  /// Cancels all non-whitelisted requests.
  static XHttp cancelRequest() {
    if (_instance._dio.options.extra['cancelDuplicatedRequest'] == true) {
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
    dio.Options? options,
    void Function(int, int)? onSendProgress,
    void Function(int, int)? onReceiveProgress,
    String? baseUrl,
  }) async {
    getInstance(baseUrl: baseUrl);
    final requestToken = isCancelWhiteList ? whiteListCancelToken : cancelToken;

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
    bool isCancelWhiteList = false,
    void Function(int, int)? onReceiveProgress,
  }) async {
    final requestToken = isCancelWhiteList ? whiteListCancelToken : cancelToken;
    try {
      final response = await _dio.download(
        urlPath,
        savePath,
        onReceiveProgress: onReceiveProgress,
        cancelToken: requestToken,
      );
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
      _instance._dio.options.headers.remove('Authorization');
    } else {
      _secureStorage.write(key: 'auth_token', value: token);
      _instance._dio.options.headers['Authorization'] = 'Bearer $token';
    }
    return _instance;
  }

  /// Gets the current baseUrl.
  static String getBaseUrl() => _instance._dio.options.baseUrl;

  /// Sets the baseUrl.
  static XHttp setBaseUrl(String baseUrl) {
    _instance._dio.options.baseUrl = baseUrl;
    return _instance;
  }

  /// Sets a header.
  static XHttp setHeader(String key, String value) {
    _instance._dio.options.headers[key] = value;
    return _instance;
  }

  /// Removes a header.
  static XHttp removeHeader(String key) {
    _instance._dio.options.headers.remove(key);
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

/// Extensions for structured string conversion.
extension Map2StringEx on Map {
  String mapToStructureString({int indentation = 0, String space = '  '}) {
    if (isEmpty) return '{}';
    final buffer = StringBuffer('{\n');
    final indent = space * (indentation + 1);
    for (final entry in entries) {
      buffer.write('$indent"${entry.key}": ');
      final value = entry.value;
      if (value is Map) {
        buffer.write('${value.mapToStructureString(indentation: indentation + 1)}\n');
      } else if (value is List) {
        buffer.write('${value.listToStructureString(indentation: indentation + 1)}\n');
      } else {
        buffer.write('${value == null ? "null" : value is String ? '"$value"' : value}\n');
      }
    }
    buffer.write('${space * indentation}}');
    return buffer.toString();
  }
}

extension List2StringEx on List {
  String listToStructureString({int indentation = 0, String space = '  '}) {
    if (isEmpty) return '[]';
    final buffer = StringBuffer('[\n');
    final indent = space * (indentation + 1);
    for (final value in this) {
      if (value is Map) {
        buffer.write('$indent${value.mapToStructureString(indentation: indentation + 1)}\n');
      } else if (value is List) {
        buffer.write('$indent${value.listToStructureString(indentation: indentation + 1)}\n');
      } else {
        buffer.write('$indent${value == null ? "null" : value is String ? '"$value"' : value}\n');
      }
    }
    buffer.write('${space * indentation}]');
    return buffer.toString();
  }
}