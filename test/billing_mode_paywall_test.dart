import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mindreader/core/config/app_build_config.dart';
import 'package:mindreader/core/l10n/app_strings.dart';
import 'package:mindreader/core/services/backend_auth_service.dart';
import 'package:mindreader/core/services/billing/store_iap_service.dart';
import 'package:mindreader/design_system/taro.dart';
import 'package:mindreader/features/profile/widgets/profile_signin_card.dart';
import 'package:mindreader/features/shell/widgets/pro_subscription_sheet.dart';
import 'package:mindreader/state/app_settings_controller.dart';
import 'package:mindreader/state/astral_controller.dart';
import 'package:mindreader/state/backend_auth_controller.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeStoreIapService implements StoreIapService {
  _FakeStoreIapService({this.products = const []});

  final List<StoreProductInfo> products;
  final List<String> fetchedIds = [];
  final List<String> purchasedIds = [];
  int restoreCalls = 0;

  @override
  Future<List<StoreProductInfo>> fetchProducts(List<String> productIds) async {
    fetchedIds.addAll(productIds);
    return products;
  }

  @override
  Future<StorePurchaseResult> purchaseProduct(String productId) async {
    purchasedIds.add(productId);
    return StorePurchaseResult(
      status: StorePurchaseStatus.purchased,
      productId: productId,
      provider: StoreIapProvider.samsungIap,
      receiptData: 'receipt-samsung-xyz',
      purchaseToken: 'tok-samsung-1',
    );
  }

  @override
  Future<void> restorePurchases() async {
    restoreCalls++;
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    billingModeOverride = null;
    isStoreBuildOverride = null;
  });

  tearDown(() {
    billingModeOverride = null;
    isStoreBuildOverride = null;
  });

  group('BillingMode config & parsing', () {
    test('parses web, reader, store_iap and legacy STORE_BUILD fallback', () {
      expect(parseBillingMode('web'), BillingMode.web);
      expect(parseBillingMode('reader'), BillingMode.reader);
      expect(parseBillingMode('store_iap'), BillingMode.storeIap);
      expect(parseBillingMode('', legacyStoreBuild: false), BillingMode.web);
      expect(parseBillingMode('', legacyStoreBuild: true), BillingMode.reader);
      expect(
        parseBillingMode('web', legacyStoreBuild: true),
        BillingMode.web,
      );
      expect(
        parseBillingMode('store_iap', legacyStoreBuild: true),
        BillingMode.storeIap,
      );
    });

    test('billingModeOverride drives all mode getters cleanly', () {
      billingModeOverride = BillingMode.web;
      expect(isWebCheckoutMode, isTrue);
      expect(isReaderStoreMode, isFalse);
      expect(isStoreIapMode, isFalse);
      expect(showPricingCards, isTrue);
      expect(showExternalPurchaseUi, isTrue);

      billingModeOverride = BillingMode.reader;
      expect(isWebCheckoutMode, isFalse);
      expect(isReaderStoreMode, isTrue);
      expect(isStoreIapMode, isFalse);
      expect(showPricingCards, isFalse);
      expect(showExternalPurchaseUi, isFalse);

      billingModeOverride = BillingMode.storeIap;
      expect(isWebCheckoutMode, isFalse);
      expect(isReaderStoreMode, isFalse);
      expect(isStoreIapMode, isTrue);
      expect(showPricingCards, isTrue);
      expect(showExternalPurchaseUi, isFalse);
    });
  });

  group('StoreIapService & EntitlementsService', () {
    test('UnconfiguredStoreIapService returns localized message without crashing', () async {
      const iap = UnconfiguredStoreIapService();
      expect(await iap.fetchProducts(StoreProductIds.allPro), isEmpty);

      final result = await iap.purchaseProduct(StoreProductIds.proMonthly);
      expect(result.status, StorePurchaseStatus.unconfigured);
      expect(result.isSuccess, isFalse);
      expect(result.message, AppStrings.g('pro.iap.unconfigured'));

      await expectLater(iap.restorePurchases(), completes);
    });

    test('EntitlementsService posts verify-store-receipt payload for samsung_iap and huawei_iap', () async {
      Map<String, dynamic>? capturedBody;
      String? capturedAuth;
      Uri? capturedUri;

      final client = MockClient((req) async {
        capturedUri = req.url;
        capturedAuth = req.headers['Authorization'];
        capturedBody = jsonDecode(req.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'verified': true,
            'isPro': true,
            'proPlan': 'annual',
            'proExpiresAt': '2027-11-27T00:00:00Z',
          }),
          200,
        );
      });

      final service = EntitlementsService(
        baseUrl: 'https://api.example.test',
        client: client,
      );

      final res = await service.verifyStoreReceipt(
        request: const StoreReceiptVerificationRequest(
          provider: StoreIapProvider.huaweiIap,
          productId: StoreProductIds.proAnnual,
          receiptData: 'huawei-inapp-purchase-data',
          purchaseToken: 'huawei-token-42',
        ),
        bearerToken: 'bearer-abc',
      );

      expect(capturedUri?.path, '/api/v1/payments/verify-store-receipt/');
      expect(capturedAuth, 'Bearer bearer-abc');
      expect(capturedBody, {
        'provider': 'huawei_iap',
        'productId': 'tarottree_pro_annual',
        'receiptData': 'huawei-inapp-purchase-data',
        'purchaseToken': 'huawei-token-42',
      });
      expect(res.verified, isTrue);
      expect(res.isPro, isTrue);
      expect(res.proPlan, 'annual');
      expect(res.proExpiresAt, isNotNull);
    });
  });

  group('ProSubscriptionSheet & ProfileSignInCard across all 3 billing modes', () {
    Widget buildHarness({
      required Widget child,
      required AppSettingsController settings,
      required AstralController astral,
      required BackendAuthController auth,
      StoreIapService iap = const UnconfiguredStoreIapService(),
      EntitlementsService? entitlements,
    }) {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: settings),
          ChangeNotifierProvider.value(value: astral),
          ChangeNotifierProvider.value(value: auth),
          Provider<StoreIapService>.value(value: iap),
          Provider<EntitlementsService>.value(
            value: entitlements ?? EntitlementsService(baseUrl: ''),
          ),
        ],
        child: MaterialApp(
          theme: buildTaroTheme(),
          home: Scaffold(body: child),
        ),
      );
    }

    testWidgets('BillingMode.web renders pricing cards, web checkout, and Solana support', (
      tester,
    ) async {
      billingModeOverride = BillingMode.web;
      final settings = AppSettingsController();
      final astral = AstralController();
      final auth = BackendAuthController(
        service: BackendAuthService(baseUrl: ''),
      );

      await tester.pumpWidget(
        buildHarness(
          settings: settings,
          astral: astral,
          auth: auth,
          child: const ProSubscriptionSheet(
            billingModeOverride: BillingMode.web,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('pro-early-supporter-banner')), findsOneWidget);
      expect(find.byKey(const ValueKey('pro-plan-monthly')), findsOneWidget);
      expect(find.byKey(const ValueKey('pro-plan-annual')), findsOneWidget);
      expect(find.text('\$4.99'), findsOneWidget);
      expect(find.text('\$39.99'), findsOneWidget);
      expect(find.byKey(const ValueKey('pro-checkout-button')), findsOneWidget);
      expect(find.byKey(const ValueKey('pro-check-status-button')), findsOneWidget);
      expect(find.byKey(const ValueKey('pro-support-project-button')), findsOneWidget);
      expect(find.byKey(const ValueKey('pro-reader-account-sync-card')), findsNothing);
      expect(find.byKey(const ValueKey('pro-store-iap-button')), findsNothing);
    });

    testWidgets('BillingMode.reader hides all prices, checkout/Solana links, and syncs PRO via account', (
      tester,
    ) async {
      billingModeOverride = BillingMode.reader;

      final client = MockClient((req) async {
        if (req.url.path == '/api/v1/auth/login/') {
          return http.Response(
            jsonEncode({
              'id': 'u-reader',
              'verified': true,
              'email': 'reader@mindreader.quest',
              'name': 'Reader',
              'emailConfirmed': true,
              'isPro': false,
              'token': 'tok-reader',
              'expiresAt': DateTime.now()
                  .add(const Duration(days: 30))
                  .toIso8601String(),
            }),
            200,
          );
        }
        if (req.url.path == '/api/v1/account/me/') {
          return http.Response(
            jsonEncode({
              'id': 'u-reader',
              'verified': true,
              'email': 'reader@mindreader.quest',
              'name': 'Reader',
              'emailConfirmed': true,
              'isPro': true,
              'proPlan': 'annual',
            }),
            200,
          );
        }
        return http.Response('{}', 404);
      });

      final settings = AppSettingsController();
      final astral = AstralController();
      final auth = BackendAuthController(
        service: BackendAuthService(
          baseUrl: 'https://api.example.test',
          client: client,
        ),
      );
      await auth.initialLoad;

      // Guest state first: shows sign-in button + refresh CTA + plain-text sync card, zero prices.
      await tester.pumpWidget(
        buildHarness(
          settings: settings,
          astral: astral,
          auth: auth,
          child: const SingleChildScrollView(
            child: Column(
              children: [
                ProSubscriptionSheet(billingModeOverride: BillingMode.reader),
                ProfileSignInCard(),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Strictly ZERO currency prices, checkout buttons, or Solana links.
      expect(find.textContaining('\$'), findsNothing);
      expect(find.textContaining('Solana'), findsNothing);
      expect(find.byKey(const ValueKey('pro-early-supporter-banner')), findsNothing);
      expect(find.byKey(const ValueKey('pro-plan-monthly')), findsNothing);
      expect(find.byKey(const ValueKey('pro-plan-annual')), findsNothing);
      expect(find.byKey(const ValueKey('pro-checkout-button')), findsNothing);
      expect(find.byKey(const ValueKey('pro-support-project-button')), findsNothing);
      expect(find.byKey(const ValueKey('pro-store-iap-button')), findsNothing);

      // Reader App Account Sync card + Sign-In + Refresh CTA present.
      expect(find.byKey(const ValueKey('pro-reader-account-sync-card')), findsOneWidget);
      expect(find.textContaining('mindreader.quest'), findsWidgets);
      expect(find.byKey(const ValueKey('pro-reader-signin-button')), findsOneWidget);
      expect(find.byKey(const ValueKey('pro-check-status-button')), findsOneWidget);
      expect(find.byKey(const ValueKey('profile-reader-account-sync')), findsOneWidget);

      // Sign in and tap Refresh PRO Status -> unlocks PRO immediately.
      await auth.signInWithPassword(
        email: 'reader@mindreader.quest',
        password: 'password123',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('pro-check-status-button')));
      await tester.pumpAndSettle();

      expect(settings.isProUnlocked, isTrue);
      expect(astral.isProUnlocked, isTrue);
    });

    testWidgets('BillingMode.storeIap uses store prices, hides web/Solana links, and routes to StoreIapService', (
      tester,
    ) async {
      billingModeOverride = BillingMode.storeIap;

      final fakeIap = _FakeStoreIapService(
        products: const [
          StoreProductInfo(
            productId: StoreProductIds.proMonthly,
            title: 'PRO Monthly',
            formattedPrice: '€4.49',
            currencyCode: 'EUR',
          ),
          StoreProductInfo(
            productId: StoreProductIds.proAnnual,
            title: 'PRO Annual',
            formattedPrice: '€34.99',
            currencyCode: 'EUR',
          ),
        ],
      );

      String? verifiedProvider;
      final receiptClient = MockClient((req) async {
        if (req.url.path == '/api/v1/payments/verify-store-receipt/') {
          final body = jsonDecode(req.body) as Map<String, dynamic>;
          verifiedProvider = body['provider'] as String?;
          return http.Response(
            jsonEncode({'verified': true, 'isPro': true, 'proPlan': 'annual'}),
            200,
          );
        }
        if (req.url.path == '/api/v1/auth/login/') {
          return http.Response(
            jsonEncode({
              'id': 'u-iap',
              'verified': true,
              'email': 'iap@example.com',
              'name': 'IAP User',
              'emailConfirmed': true,
              'isPro': false,
              'token': 'tok-iap',
              'expiresAt': DateTime.now()
                  .add(const Duration(days: 30))
                  .toIso8601String(),
            }),
            200,
          );
        }
        if (req.url.path == '/api/v1/account/me/') {
          return http.Response(
            jsonEncode({
              'id': 'u-iap',
              'verified': true,
              'email': 'iap@example.com',
              'name': 'IAP User',
              'emailConfirmed': true,
              'isPro': false,
            }),
            200,
          );
        }
        return http.Response('{}', 200);
      });

      final settings = AppSettingsController();
      final astral = AstralController();
      final auth = BackendAuthController(
        service: BackendAuthService(
          baseUrl: 'https://api.example.test',
          client: receiptClient,
        ),
      );
      await auth.initialLoad;
      await auth.signInWithPassword(
        email: 'iap@example.com',
        password: 'password123',
      );

      final entitlements = EntitlementsService(
        baseUrl: 'https://api.example.test',
        client: receiptClient,
      );

      await tester.pumpWidget(
        buildHarness(
          settings: settings,
          astral: astral,
          auth: auth,
          iap: fakeIap,
          entitlements: entitlements,
          child: ProSubscriptionSheet(
            billingModeOverride: BillingMode.storeIap,
            storeIapService: fakeIap,
            entitlementsService: entitlements,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Store prices loaded from StoreIapService; NO web checkout or Solana links.
      expect(fakeIap.fetchedIds, containsAll(StoreProductIds.allPro));
      expect(find.byKey(const ValueKey('pro-plan-monthly')), findsOneWidget);
      expect(find.byKey(const ValueKey('pro-plan-annual')), findsOneWidget);
      expect(find.text('€4.49'), findsOneWidget);
      expect(find.text('€34.99'), findsOneWidget);
      expect(find.byKey(const ValueKey('pro-checkout-button')), findsNothing);
      expect(find.byKey(const ValueKey('pro-support-project-button')), findsNothing);
      expect(find.textContaining('Solana'), findsNothing);
      expect(find.byKey(const ValueKey('pro-store-iap-button')), findsOneWidget);
      expect(find.byKey(const ValueKey('pro-restore-purchases-button')), findsOneWidget);

      // Tap Restore Purchases -> calls StoreIapService.restorePurchases().
      await tester.tap(find.byKey(const ValueKey('pro-restore-purchases-button')));
      await tester.pumpAndSettle();
      expect(fakeIap.restoreCalls, 1);

      // Select Annual plan & purchase -> invokes StoreIapService + receipt verify + unlocks PRO.
      await tester.tap(find.byKey(const ValueKey('pro-plan-annual')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('pro-store-iap-button')));
      await tester.pumpAndSettle();

      expect(fakeIap.purchasedIds, [StoreProductIds.proAnnual]);
      expect(verifiedProvider, 'samsung_iap');
      expect(settings.isProUnlocked, isTrue);
      expect(astral.isProUnlocked, isTrue);
    });

    testWidgets('BillingMode.storeIap with UnconfiguredStoreIapService shows calm fallback without crashing', (
      tester,
    ) async {
      billingModeOverride = BillingMode.storeIap;
      final settings = AppSettingsController();
      final astral = AstralController();
      final auth = BackendAuthController(
        service: BackendAuthService(baseUrl: ''),
      );

      await tester.pumpWidget(
        buildHarness(
          settings: settings,
          astral: astral,
          auth: auth,
          child: const ProSubscriptionSheet(
            billingModeOverride: BillingMode.storeIap,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Fallback display prices when native SDK returns no products yet.
      expect(find.text('\$4.99'), findsOneWidget);
      expect(find.text('\$39.99'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('pro-store-iap-button')));
      await tester.pumpAndSettle();

      expect(
        find.text(AppStrings.t(AppLanguage.en, 'pro.iap.unconfigured')),
        findsOneWidget,
      );
      expect(settings.isProUnlocked, isFalse);
    });

    test('all 6 languages define complete Reader App and Store IAP keys', () {
      const keys = [
        'pro.reader.title',
        'pro.reader.body',
        'pro.reader.refreshCta',
        'shop.reader.managedNote',
        'pro.iap.unconfigured',
        'pro.iap.restoreCta',
        'pro.iap.restoreComplete',
      ];
      for (final lang in AppLanguage.values) {
        for (final key in keys) {
          final value = AppStrings.t(lang, key);
          expect(value, isNot(equals(key)), reason: '$lang missing $key');
          expect(value.trim(), isNotEmpty, reason: '$lang empty $key');
        }
      }
    });
  });
}
