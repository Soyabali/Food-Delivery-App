import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'api_exception.dart';

/// Returns the current bearer token, or null when signed out.
typedef TokenProvider = String? Function();

/// What services depend on. Two implementations exist:
/// * [HttpApiClient] — real HTTP (DummyJSON, or your backend), and
/// * `MockBackend` — answers the same paths on-device.
///
/// Every method returns decoded JSON (`Map`, `List`, or `null` for empty
/// bodies) and throws [ApiException] on failure.
abstract interface class ApiClient {
  Future<dynamic> get(String path, {Map<String, String>? query});
  Future<dynamic> post(String path, {Object? body});
  Future<dynamic> put(String path, {Object? body});
  Future<dynamic> patch(String path, {Object? body});
  Future<dynamic> delete(String path);
}

class HttpApiClient implements ApiClient {
  HttpApiClient({
    required this.baseUrl,
    required this.timeout,
    http.Client? httpClient,
    this.tokenProvider,
    this.defaultHeaders = const {},
  }) : _http = httpClient ?? http.Client();

  final String baseUrl;
  final Duration timeout;
  final TokenProvider? tokenProvider;
  final Map<String, String> defaultHeaders;
  final http.Client _http;

  Uri _uri(String path, Map<String, String>? query) {
    final base = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final uri = Uri.parse('$base$path');
    return query == null || query.isEmpty
        ? uri
        : uri.replace(queryParameters: {...uri.queryParameters, ...query});
  }

  Map<String, String> _headers({bool hasBody = false}) {
    final token = tokenProvider?.call();
    return {
      'Accept': 'application/json',
      if (hasBody) 'Content-Type': 'application/json; charset=utf-8',
      if (token != null) 'Authorization': 'Bearer $token',
      ...defaultHeaders,
    };
  }

  @override
  Future<dynamic> get(String path, {Map<String, String>? query}) =>
      _send('GET', _uri(path, query));

  @override
  Future<dynamic> post(String path, {Object? body}) =>
      _send('POST', _uri(path, null), body: body);

  @override
  Future<dynamic> put(String path, {Object? body}) =>
      _send('PUT', _uri(path, null), body: body);

  @override
  Future<dynamic> patch(String path, {Object? body}) =>
      _send('PATCH', _uri(path, null), body: body);

  @override
  Future<dynamic> delete(String path) => _send('DELETE', _uri(path, null));

  Future<dynamic> _send(String method, Uri uri, {Object? body}) async {
    final request = http.Request(method, uri)
      ..headers.addAll(_headers(hasBody: body != null));
    if (body != null) request.body = jsonEncode(body);

    final http.Response response;
    try {
      final streamed = await _http.send(request).timeout(timeout);
      response = await http.Response.fromStream(streamed).timeout(timeout);
    } on TimeoutException {
      throw ApiException.timeout;
    } on http.ClientException catch (e) {
      debugPrint('[api] $method $uri network error: $e');
      throw ApiException.network;
    } catch (e) {
      // SocketException / HandshakeException etc. (dart:io types aren't
      // available on web, so match by catch-all).
      debugPrint('[api] $method $uri failed: $e');
      throw ApiException.network;
    }

    final text = utf8.decode(response.bodyBytes);
    dynamic json;
    if (text.isNotEmpty) {
      try {
        json = jsonDecode(text);
      } on FormatException {
        if (response.statusCode >= 200 && response.statusCode < 300) {
          throw ApiException.invalidResponse;
        }
      }
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = json is Map ? json['message']?.toString() : null;
      throw ApiException.fromStatus(response.statusCode, message);
    }
    return json;
  }

  void close() => _http.close();
}
