import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({required String baseUrl, http.Client? httpClient})
    : _baseUri = Uri.parse(baseUrl),
      _httpClient = httpClient ?? http.Client();

  final Uri _baseUri;
  final http.Client _httpClient;

  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, String>? queryParameters,
  }) async {
    final response = await _httpClient.get(
      _uri(path, queryParameters: queryParameters),
    );
    return _decodeObject(response);
  }

  Future<List<dynamic>> getJsonList(
    String path, {
    Map<String, String>? queryParameters,
  }) async {
    final response = await _httpClient.get(
      _uri(path, queryParameters: queryParameters),
    );
    return _decodeList(response);
  }

  Future<Map<String, dynamic>> postJson(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final response = await _httpClient.post(
      _uri(path),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode(body ?? const <String, dynamic>{}),
    );
    return _decodeObject(response);
  }

  Uri _uri(String path, {Map<String, String>? queryParameters}) {
    final normalizedPath = path.startsWith('/') ? path.substring(1) : path;
    final basePath = _baseUri.path.endsWith('/')
        ? _baseUri.path
        : '${_baseUri.path}/';
    return _baseUri.replace(
      path: '$basePath$normalizedPath',
      queryParameters: queryParameters,
    );
  }

  Map<String, dynamic> _decodeObject(http.Response response) {
    final body = _decodeBody(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final detail = body is Map<String, dynamic> ? body['detail'] : null;
      throw ApiException(
        detail is String ? detail : 'API通信に失敗しました',
        statusCode: response.statusCode,
      );
    }
    if (body is Map<String, dynamic>) {
      return body;
    }
    throw const ApiException('APIレスポンスの形式が不正です');
  }

  List<dynamic> _decodeList(http.Response response) {
    final body = _decodeBody(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final detail = body is Map<String, dynamic> ? body['detail'] : null;
      throw ApiException(
        detail is String ? detail : 'API通信に失敗しました',
        statusCode: response.statusCode,
      );
    }
    if (body is List<dynamic>) {
      return body;
    }
    throw const ApiException('APIレスポンスの形式が不正です');
  }

  dynamic _decodeBody(http.Response response) {
    if (response.body.isEmpty) {
      return const <String, dynamic>{};
    }
    return jsonDecode(utf8.decode(response.bodyBytes));
  }
}
