import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobileapp/features/authentication/login/login_screen.dart';
import 'package:mobileapp/features/home/home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_food_api.dart';
import 'test_helpers.dart';

void main() {
  testWidgets('fresh launch goes Splash -> Login with demo label', (tester) async {
    final h = TestHarness();
    await h.launch(tester);

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('Demo mode · simulated sign-in'), findsOneWidget);
    // Promo banner comes from GET /offers (mock backend).
    expect(find.textContaining('with code APNA100'), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('empty login shows field errors', (tester) async {
    final h = TestHarness();
    await h.launch(tester);
    await tester.enterText(find.byType(TextFormField).at(0), '');
    await tester.enterText(find.byType(TextFormField).at(1), '');
    await h.loginWithDemoAccount(tester);

    expect(find.text('Email address is required'), findsOneWidget);
    expect(find.text('Password is required'), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('wrong password shows the backend error', (tester) async {
    final h = TestHarness();
    await h.launch(tester);
    await tester.enterText(find.byType(TextFormField).at(1), 'nope-nope');
    await h.loginWithDemoAccount(tester);

    expect(find.text('Incorrect email or password.'), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
    await h.dispose(tester);
  });

  testWidgets('login loads Home sections from the APIs', (tester) async {
    final h = TestHarness();
    await h.launch(tester);
    await h.loginWithDemoAccount(tester);

    expect(find.text('Hi, Rahul 👋'), findsOneWidget);
    expect(find.text('50% OFF'), findsOneWidget); // GET /offers
    expect(find.text('Chicken Biryani'), findsWidgets); // GET /recipes?sortBy=rating
    await tester.scrollUntilVisible(
      find.text('Royal Biryani House'), 300,
      scrollable: find.byType(Scrollable).first,
    ); // GET /restaurants
    expect(
      h.foodApi.requests.map((u) => u.path),
      containsAll(['/recipes/tags', '/recipes']),
    );

    await pressSystemBack(tester);
    expect(find.text('Press back again to exit'), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
    await h.dispose(tester);
  });

  testWidgets('food API outage shows retry, then recovers', (tester) async {
    final h = TestHarness();
    h.foodApi.failure = FakeFailure.network;
    await h.launch(tester);
    await h.loginWithDemoAccount(tester);

    expect(find.text('Retry'), findsWidgets);
    expect(find.textContaining('No internet connection'), findsWidgets);
    // Backend-driven sections (offers, restaurants) still render.
    expect(find.text('50% OFF'), findsOneWidget);

    h.foodApi.failure = FakeFailure.none;
    await tester.tap(find.text('Retry').first);
    await tester.pumpAndSettle();
    expect(find.text('Top Rated Dishes'), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('search hits /recipes/search and shows empty state', (tester) async {
    final h = TestHarness();
    await h.launch(tester);
    await h.loginWithDemoAccount(tester);
    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'pizza');
    await tester.pump(const Duration(milliseconds: 450)); // debounce
    await tester.pumpAndSettle();
    expect(find.text('Classic Margherita Pizza'), findsOneWidget);
    expect(h.foodApi.requests.last.queryParameters['q'], 'pizza');

    await tester.enterText(find.byType(TextField), 'zzzz');
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpAndSettle();
    expect(find.text('Nothing found'), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('restaurant -> dish -> cart -> order -> confirmation', (tester) async {
    final h = TestHarness();
    await h.launch(tester);
    await h.loginWithDemoAccount(tester);

    await openRestaurant(tester, 'Royal Biryani House');
    expect(h.foodApi.requests.last.path, '/recipes/tag/Pakistani');
    await tester.tap(find.text('ADD').first);
    await tester.pumpAndSettle();
    expect(find.text('Ingredients'), findsOneWidget);

    await tester.tap(find.textContaining('Add to Cart'));
    await tester.pumpAndSettle();
    expect(h.services.cart.totalQuantity, 1);

    await tester.tap(find.text('VIEW CART'));
    await tester.pumpAndSettle();
    expect(find.text('Your Cart'), findsOneWidget);
    expect(find.text('Bill Details'), findsOneWidget);
    final total = h.services.cart.cart.total;
    expect(total, greaterThan(0));

    await tester.tap(find.text('Proceed to Payment'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Pay ₹'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Order Placed Successfully!'), findsOneWidget);
    expect(h.services.cart.isEmpty, isTrue);
    expect(h.services.orders.orders, hasLength(1));

    // ignore: invalid_use_of_protected_member
    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(HomeScreen), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('session persists across app restarts', (tester) async {
    final first = TestHarness();
    await first.launch(tester);
    await first.loginWithDemoAccount(tester);
    expect(find.byType(HomeScreen), findsOneWidget);
    // Snapshot everything the first run wrote to device storage.
    final saved = (await tester.runAsync(() async {
      final p = await SharedPreferences.getInstance();
      return {for (final k in p.getKeys()) k: p.get(k)!};
    }))!;
    await first.dispose(tester);

    // "Restart": a fresh app over the same storage skips login.
    final second = TestHarness(storedPrefs: saved);
    await second.launch(tester);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
    await second.dispose(tester);
  });

  testWidgets('logout asks for confirmation and clears history', (tester) async {
    final h = TestHarness();
    await h.launch(tester);
    await h.loginWithDemoAccount(tester);

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Log out'), 200);
    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log out').last);
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    await pressSystemBack(tester);
    expect(find.byType(HomeScreen), findsNothing);
    await h.dispose(tester);
  });

  testWidgets('registration creates an account via the backend', (tester) async {
    final h = TestHarness();
    await h.launch(tester);
    await tester.tap(find.text('Sign Up'));
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Asha Verma');
    await tester.enterText(fields.at(1), 'asha@example.com');
    await tester.enterText(fields.at(2), '98765 43210');
    await tester.enterText(fields.at(3), 'longenough1');
    await tester.enterText(fields.at(4), 'longenough1');
    await tester.ensureVisible(find.textContaining('I agree to the'));
    await tester.tap(find.textContaining('I agree to the'));
    await tester.ensureVisible(find.widgetWithText(InkWell, 'Sign Up'));
    await tester.tap(find.widgetWithText(InkWell, 'Sign Up'));
    await tester.pumpAndSettle();

    expect(find.text('Hi, Asha 👋'), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('forgot password: code, new password, log in', (tester) async {
    final h = TestHarness();
    await h.launch(tester);
    await tester.tap(find.text('Forgot Password?'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Send Reset Code'));
    await tester.pumpAndSettle();
    expect(find.text('Email address is required'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).first, 'rahul.sharma@example.com');
    await tester.tap(find.text('Send Reset Code'));
    await tester.pumpAndSettle();
    expect(find.text('Code Sent!'), findsOneWidget);
    final demo = tester.widget<Text>(find.textContaining('your code is')).data!;
    final code = RegExp(r'(\d{6})').firstMatch(demo)!.group(1)!;

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(1), code);
    await tester.enterText(fields.at(2), 'BrandNew#2026');
    await tester.enterText(fields.at(3), 'BrandNew#2026');
    await tester.ensureVisible(find.text('Reset Password'));
    await tester.tap(find.text('Reset Password'));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).at(1), 'BrandNew#2026');
    await h.loginWithDemoAccount(tester);
    expect(find.byType(HomeScreen), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('placing an order needs internet', (tester) async {
    final h = TestHarness(online: false);
    await h.launch(tester);
    await h.loginWithDemoAccount(tester);
    expect(find.textContaining("You're offline"), findsOneWidget);

    await openRestaurant(tester, 'Royal Biryani House');
    await tester.tap(find.text('ADD').first);
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Add to Cart'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('VIEW CART'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Proceed to Payment'));
    await tester.pumpAndSettle();
    expect(find.text('No internet connection'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await h.dispose(tester);
  });
}
