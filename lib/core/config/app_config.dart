/// Build-time configuration. Values come from `--dart-define` or
/// `--dart-define-from-file=.env` (see `.env.example` and
/// docs/ENVIRONMENT_SETUP.md). Defaults run the app with DummyJSON plus the
/// on-device mock backend, so no setup is needed for a first run.
///
/// Only public, non-secret values belong here: anything compiled into a
/// mobile app can be extracted from the binary.
enum BackendMode {
  /// Cart, orders, auth, restaurants... are served by the in-app
  /// [MockBackend] and stored on the device.
  mock,

  /// The same endpoints are sent over HTTP to [AppConfig.backendBaseUrl].
  http,
}

class AppConfig {
  const AppConfig({
    required this.foodApiBaseUrl,
    required this.backendMode,
    required this.backendBaseUrl,
    required this.requestTimeout,
    required this.mockLatency,
  });

  factory AppConfig.fromEnvironment() {
    const mode = String.fromEnvironment('BACKEND_MODE', defaultValue: 'mock');
    return AppConfig(
      foodApiBaseUrl: const String.fromEnvironment(
        'FOOD_API_BASE_URL',
        defaultValue: 'https://dummyjson.com',
      ),
      backendMode: mode == 'http' ? BackendMode.http : BackendMode.mock,
      backendBaseUrl: const String.fromEnvironment(
        'BACKEND_BASE_URL',
        defaultValue: 'http://10.0.2.2:3000/api',
      ),
      requestTimeout: const Duration(
        seconds: int.fromEnvironment('API_TIMEOUT_SECONDS', defaultValue: 15),
      ),
      mockLatency: const Duration(
        milliseconds: int.fromEnvironment('MOCK_LATENCY_MS', defaultValue: 600),
      ),
    );
  }

  /// Recipes/food provider (DummyJSON by default).
  final String foodApiBaseUrl;

  final BackendMode backendMode;

  /// Used only when [backendMode] is [BackendMode.http].
  final String backendBaseUrl;

  final Duration requestTimeout;

  /// Simulated round-trip time of the mock backend.
  final Duration mockLatency;

  bool get isMockBackend => backendMode == BackendMode.mock;
}
