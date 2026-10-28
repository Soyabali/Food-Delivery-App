import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobileapp/core/api/api_client.dart';
import 'package:mobileapp/core/api/api_exception.dart';

HttpApiClient clientFor(
  MockClientHandler handler, {
  Duration timeout = const Duration(seconds: 2),
  String? token,
}) =>
    HttpApiClient(
      baseUrl: 'https://api.test/v1/',
      timeout: timeout,
      httpClient: MockClient(handler),
      tokenProvider: () => token,
    );

Future<ApiException> errorOf(Future<dynamic> f) async {
  try {
    await f;
  } on ApiException catch (e) {
    return e;
  }
  fail('expected ApiException');
}

void main() {
  test('builds URL, query, headers and decodes JSON', () async {
    late http.Request seen;
    final client = clientFor((r) async {
      seen = r;
      return http.Response('{"ok":true}', 200);
    }, token: 'abc');

    final json = await client.get('/recipes', query: {'q': 'pizza'});

    expect(json, {'ok': true});
    expect(seen.url.toString(), 'https://api.test/v1/recipes?q=pizza');
    expect(seen.headers['Authorization'], 'Bearer abc');
    expect(seen.headers['Accept'], 'application/json');
  });

  test('sends JSON bodies', () async {
    late http.Request seen;
    final client = clientFor((r) async {
      seen = r;
      return http.Response('', 204);
    });
    final result = await client.post('/cart/items', body: {'quantity': 2});
    expect(result, isNull);
    expect(seen.method, 'POST');
    expect(jsonDecode(seen.body), {'quantity': 2});
    expect(seen.headers['Content-Type'], contains('application/json'));
  });

  test('maps 404 with server message', () async {
    final client = clientFor(
      (_) async => http.Response('{"message":"Recipe not found"}', 404),
    );
    final e = await errorOf(client.get('/recipes/999'));
    expect(e.type, ApiErrorType.notFound);
    expect(e.message, 'Recipe not found');
  });

  test('maps 401 and 400', () async {
    expect(
      (await errorOf(clientFor((_) async => http.Response('{}', 401)).get('/x'))).type,
      ApiErrorType.unauthorized,
    );
    final bad = await errorOf(
      clientFor((_) async => http.Response('{"message":"Invalid coupon"}', 400))
          .post('/cart/coupon'),
    );
    expect(bad.type, ApiErrorType.badRequest);
    expect(bad.message, 'Invalid coupon');
  });

  test('5xx hides server details behind a generic message', () async {
    final e = await errorOf(
      clientFor((_) async => http.Response('{"message":"stack trace..."}', 503))
          .get('/x'),
    );
    expect(e.type, ApiErrorType.server);
    expect(e.message, isNot(contains('stack')));
    expect(e.isRetryable, isTrue);
  });

  test('non-JSON success body is an invalid response', () async {
    final e = await errorOf(
      clientFor((_) async => http.Response('<html></html>', 200)).get('/x'),
    );
    expect(e.type, ApiErrorType.invalidResponse);
  });

  test('connection failure is a network error', () async {
    final e = await errorOf(
      clientFor((r) async => throw http.ClientException('no route', r.url))
          .get('/x'),
    );
    expect(e.type, ApiErrorType.network);
  });

  test('slow responses time out', () async {
    final client = clientFor(
      (_) => Future.delayed(
        const Duration(milliseconds: 300),
        () => http.Response('{}', 200),
      ),
      timeout: const Duration(milliseconds: 50),
    );
    expect((await errorOf(client.get('/x'))).type, ApiErrorType.timeout);
  });
}
