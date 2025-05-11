import 'package:miji/services/api/xhttp.dart';

class ApiService {
  final XHttp xhttp;

  ApiService(this.xhttp);

  Future<Map<String, dynamic>> request(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? data,
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final result = await xhttp.request(
        path,
        method: method,
        data: data,
        queryParameters: queryParameters,
      );

      if (!result.success) {
        throw Exception('Request failed: ${result.message}');
      }

      return result.data;
    } catch (e) {
      throw Exception('API request error: $e');
    }
  }
}