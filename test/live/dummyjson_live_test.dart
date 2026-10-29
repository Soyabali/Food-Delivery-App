// Live check of every DummyJSON endpoint the app uses, through the real
// services and adapter. Needs internet, so it is skipped by default:
//
//   flutter test test/live --dart-define=RUN_LIVE=true
@Tags(['live'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobileapp/core/api/api_client.dart';
import 'package:mobileapp/core/api/api_exception.dart';
import 'package:mobileapp/core/storage/local_store.dart';
import 'package:mobileapp/data/mock_backend/mock_backend.dart';
import 'package:mobileapp/services/category_service.dart';
import 'package:mobileapp/services/food_service.dart';
import 'package:mobileapp/services/restaurant_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const runLive = bool.fromEnvironment('RUN_LIVE');

void main() {
  late FoodService food;
  late CategoryService categories;
  late RestaurantService restaurants;

  setUpAll(() async {
    HttpOverrides.global = null; // allow real network in this file
    SharedPreferences.setMockInitialValues({});
    final store = await LocalStore.open();
    final api = HttpApiClient(
      baseUrl: 'https://dummyjson.com',
      timeout: const Duration(seconds: 20),
    );
    restaurants = RestaurantService(
      MockBackend(store: store, tokenProvider: () => null, latency: Duration.zero),
    );
    food = FoodService(api, restaurants);
    categories = CategoryService(api);
  });

  group('DummyJSON (live)', skip: runLive ? false : 'set RUN_LIVE=true', () {
    test('GET /recipes?sortBy=rating', () async {
      final dishes = await food.getTopRated(limit: 5);
      expect(dishes, hasLength(5));
      expect(dishes.first.rating, greaterThanOrEqualTo(dishes.last.rating));
      expect(dishes.first.image, startsWith('https://cdn.dummyjson.com/'));
    });

    test('GET /recipes/{id}', () async {
      final dish = await food.getDish(1);
      expect(dish.name, 'Classic Margherita Pizza');
      expect(dish.ingredients, isNotEmpty);
      expect(dish.price, inInclusiveRange(100, 550));
    });

    test('GET /recipes/{id} unknown -> 404', () async {
      await expectLater(
        food.getDish(999999),
        throwsA(isA<ApiException>().having((e) => e.type, 'type', ApiErrorType.notFound)),
      );
    });

    test('GET /recipes/search', () async {
      expect((await food.search('pizza')).map((d) => d.name), contains('Classic Margherita Pizza'));
      expect(await food.search('zzzzqq'), isEmpty);
    });

    test('GET /recipes/tags', () async {
      expect((await categories.getCategories()).map((c) => c.name), containsAll(['Pizza', 'Pakistani', 'Dessert']));
    });

    test('GET /recipes/tag/{tag} (restaurant menus)', () async {
      for (final r in await restaurants.all()) {
        final menu = await food.menuFor(r);
        expect(menu, isNotEmpty, reason: '${r.name} menu is empty');
        if (r.isPureVeg) expect(menu.every((d) => d.isVeg), isTrue);
      }
    });

    test('GET /recipes/meal-type/{type}', () async {
      for (final m in CategoryService.mealTypes) {
        final dishes = await food.byMealType(m);
        // ignore: avoid_print
        print('meal-type $m -> ${dishes.length} recipes');
      }
      expect(await food.byMealType('Dinner'), isNotEmpty);
    });

    test('random dish (GET /recipes?limit=1&skip=n)', () async {
      expect((await food.getRandomDish()).name, isNotEmpty);
    });
  });
}
