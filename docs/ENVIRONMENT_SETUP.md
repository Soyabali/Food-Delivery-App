# Environment Setup

## Install

1. Flutter SDK (tested with Flutter 3.47.8 / Dart 3.13.7). Check with `flutter doctor`.
2. Windows only: turn on **Developer Mode** (`start ms-settings:developers`),
   which Flutter needs to build apps that use plugins.
3. From the project folder: `flutter pub get`.

## Configuration

Settings are build-time `--dart-define` values, read in
`lib/core/config/app_config.dart`. **Defaults work out of the box**: real
DummyJSON plus the on-device mock backend.

| Variable | Default | Meaning |
|---|---|---|
| `FOOD_API_BASE_URL` | `https://dummyjson.com` | Recipe/food provider |
| `BACKEND_MODE` | `mock` | `mock` = in-app backend; `http` = call `BACKEND_BASE_URL` |
| `BACKEND_BASE_URL` | `http://10.0.2.2:8000/api` | Your backend (only when `BACKEND_MODE=http`) |
| `API_TIMEOUT_SECONDS` | `15` | Per-request timeout |
| `MOCK_LATENCY_MS` | `600` | Simulated mock-backend delay |

To use a file:

```bash
cp .env.example .env          # edit values
flutter run --dart-define-from-file=.env
```

Or set single values: `flutter run --dart-define=BACKEND_MODE=http --dart-define=BACKEND_BASE_URL=https://api.example.com`.

In VS Code, `.vscode/launch.json` provides **Apna Food (mock backend)** and
**Apna Food (from .env)**.

`.env` is git-ignored. Only put **public** values in it: everything is
compiled into the app and can be extracted. Never put private keys here.

## Run

```bash
flutter devices                 # find your emulator, e.g. emulator-5554
flutter run -d emulator-5554
```

There is no separate mock server to start: the mock backend runs inside the
app. To clear its data, use **Profile → Reset demo data** (mock mode only) or
uninstall the app.

Demo login (mock mode, prefilled): `rahul.sharma@example.com` / `supersecret123`.

## Changing API URLs

- Food provider: `FOOD_API_BASE_URL`. Paths are in `FoodEndpoints`.
- Backend: `BACKEND_MODE=http` and `BACKEND_BASE_URL`. Paths are in `BackendEndpoints`.

## Common configuration errors

| Symptom | Cause / fix |
|---|---|
| "No internet connection" on every food section | Emulator has no internet, or `FOOD_API_BASE_URL` is wrong. Open a browser in the emulator to check. |
| Everything fails in `http` mode on the emulator | `localhost` inside the Android emulator is the emulator itself. Use `10.0.2.2` to reach your PC. |
| `CLEARTEXT communication not permitted` | Android blocks plain `http://` in release builds. Use HTTPS, or allow cleartext for your dev host via a network security config. |
| Splash shows an error with Retry | A saved session could not be verified (backend unreachable). Tap Retry once the backend is up. |
| Values from `.env` are ignored | You ran without `--dart-define-from-file=.env`. Defines are applied at build time, so do a full restart, not a hot reload. |
| Build error about symlinks (Windows) | Turn on Developer Mode. |
