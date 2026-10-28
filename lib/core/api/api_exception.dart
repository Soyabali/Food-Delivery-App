enum ApiErrorType {
  /// No connection / DNS failure / connection refused.
  network,
  timeout,

  /// 401: missing or expired session.
  unauthorized,

  /// 404.
  notFound,

  /// Other 4xx: the request was rejected (validation, bad coupon...).
  badRequest,

  /// 5xx.
  server,

  /// Response could not be parsed into the expected shape.
  invalidResponse,
}

/// The only error type services throw. Screens show [message] directly.
class ApiException implements Exception {
  const ApiException(this.type, this.message, {this.statusCode});

  final ApiErrorType type;
  final String message;
  final int? statusCode;

  factory ApiException.fromStatus(int status, String? serverMessage) {
    final type = switch (status) {
      401 => ApiErrorType.unauthorized,
      404 => ApiErrorType.notFound,
      >= 500 => ApiErrorType.server,
      _ => ApiErrorType.badRequest,
    };
    final fallback = switch (type) {
      ApiErrorType.unauthorized => 'Your session has expired. Please log in again.',
      ApiErrorType.notFound => 'We couldn’t find what you were looking for.',
      ApiErrorType.server => 'Our servers are having trouble. Please try again shortly.',
      _ => 'Something went wrong with that request.',
    };
    // Server messages are shown for 4xx (user-actionable); 5xx stays generic.
    final message = type == ApiErrorType.server ||
            serverMessage == null ||
            serverMessage.isEmpty
        ? fallback
        : serverMessage;
    return ApiException(type, message, statusCode: status);
  }

  static const network = ApiException(
    ApiErrorType.network,
    'No internet connection. Check your network and try again.',
  );
  static const timeout = ApiException(
    ApiErrorType.timeout,
    'The request took too long. Please try again.',
  );
  static const invalidResponse = ApiException(
    ApiErrorType.invalidResponse,
    'We received an unexpected response. Please try again.',
  );

  bool get isRetryable => switch (type) {
        ApiErrorType.network ||
        ApiErrorType.timeout ||
        ApiErrorType.server ||
        ApiErrorType.invalidResponse =>
          true,
        _ => false,
      };

  @override
  String toString() => 'ApiException($type, $statusCode): $message';
}

/// Converts anything thrown by a service into an [ApiException] so the UI has
/// a single error shape. Parsing bugs (TypeError/FormatException from
/// adapters) surface as [ApiErrorType.invalidResponse].
ApiException toApiException(Object error) => switch (error) {
      ApiException e => e,
      FormatException() || TypeError() => ApiException.invalidResponse,
      _ => const ApiException(
          ApiErrorType.server,
          'Something went wrong. Please try again.',
        ),
    };
