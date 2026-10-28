import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobileapp/app/app.dart';
import 'package:mobileapp/core/config/app_config.dart';
import 'package:mobileapp/core/connectivity/connectivity_service.dart';
import 'package:mobileapp/core/storage/local_store.dart';
import 'package:mobileapp/features/splash/splash_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_food_api.dart';

const testConfig = AppConfig(
  foodApiBaseUrl: 'https://dummyjson.test',
  backendMode: BackendMode.mock,
  backendBaseUrl: 'http://unused',
  requestTimeout: Duration(seconds: 5),
  mockLatency: Duration.zero,
);

/// Real services wired to a fake DummyJSON ([FakeFoodApi]) and the real
/// mock backend (zero latency, in-memory SharedPreferences).
class TestHarness {
  TestHarness({this.online = true, Map<String, Object>? storedPrefs})
      : _storedPrefs = storedPrefs ?? {};

  final bool online;
  final Map<String, Object> _storedPrefs;
  final foodApi = FakeFoodApi();
  final connectivityEvents = StreamController<List<ConnectivityResult>>();
  late AppServices services;

  void setOnline(bool value) => connectivityEvents
      .add([value ? ConnectivityResult.wifi : ConnectivityResult.none]);

  Future<void> launch(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues(_storedPrefs);
    await tester.runAsync(() async {
      services = await AppServices.create(
        config: testConfig,
        store: await LocalStore.open(),
        httpClient: foodApi.client,
        connectivity: ConnectivityService(
          changes: connectivityEvents.stream,
          check: () async =>
              [online ? ConnectivityResult.wifi : ConnectivityResult.none],
        ),
      );
    });

    await tester.pumpWidget(ApnaFoodApp(services: services));
    await tester.pump();
    await tester.pump(SplashScreen.minimumDisplay);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
  }

  Future<void> loginWithDemoAccount(WidgetTester tester) async {
    await tester.tap(find.text('Login').first);
    await tester.pumpAndSettle();
  }

  Future<void> dispose(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await connectivityEvents.close();
  }
}

/// Scrolls Home until a restaurant card is visible, then opens it.
Future<void> openRestaurant(WidgetTester tester, String name) async {
  await tester.scrollUntilVisible(
    find.text(name),
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text(name).first);
  await tester.pumpAndSettle();
}

Future<void> pressSystemBack(WidgetTester tester) async {
  // ignore: invalid_use_of_protected_member
  await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();
}
