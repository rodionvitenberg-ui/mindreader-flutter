import '../../l10n/app_strings.dart';

export 'entitlements_service.dart';

/// Canonical store IAP product identifiers shared across Samsung Galaxy Store
/// and Huawei AppGallery adapters.
abstract final class StoreProductIds {
  static const proMonthly = 'tarottree_pro_monthly';
  static const proAnnual = 'tarottree_pro_annual';

  static const allPro = <String>[proMonthly, proAnnual];
}

/// Supported native store IAP providers for backend receipt verification.
enum StoreIapProvider {
  samsungIap('samsung_iap'),
  huaweiIap('huawei_iap');

  const StoreIapProvider(this.wireName);

  /// Backend wire identifier sent to `/api/v1/payments/verify-store-receipt/`.
  final String wireName;
}

/// Localized product metadata returned by a native store IAP catalog.
class StoreProductInfo {
  const StoreProductInfo({
    required this.productId,
    required this.title,
    required this.formattedPrice,
    required this.currencyCode,
    this.description,
  });

  final String productId;
  final String title;
  final String formattedPrice;
  final String currencyCode;
  final String? description;
}

/// Outcome of a store IAP purchase attempt.
enum StorePurchaseStatus {
  purchased,
  restored,
  cancelled,
  unconfigured,
  error,
}

/// Result returned by [StoreIapService.purchaseProduct].
class StorePurchaseResult {
  const StorePurchaseResult({
    required this.status,
    this.productId,
    this.provider,
    this.receiptData,
    this.purchaseToken,
    this.message,
  });

  final StorePurchaseStatus status;
  final String? productId;
  final StoreIapProvider? provider;
  final String? receiptData;
  final String? purchaseToken;
  final String? message;

  bool get isSuccess =>
      status == StorePurchaseStatus.purchased ||
      status == StorePurchaseStatus.restored;
}

/// Decoupled store billing adapter interface for Samsung Galaxy Store /
/// Huawei AppGallery IAP SDK integrations.
abstract class StoreIapService {
  Future<List<StoreProductInfo>> fetchProducts(List<String> productIds);

  Future<StorePurchaseResult> purchaseProduct(String productId);

  Future<void> restorePurchases();
}

/// Safe default implementation used when `BILLING_MODE=store_iap` is built
/// before native Samsung/Huawei IAP SDK credentials are wired.
class UnconfiguredStoreIapService implements StoreIapService {
  const UnconfiguredStoreIapService();

  @override
  Future<List<StoreProductInfo>> fetchProducts(List<String> productIds) async =>
      const <StoreProductInfo>[];

  @override
  Future<StorePurchaseResult> purchaseProduct(String productId) async =>
      StorePurchaseResult(
        status: StorePurchaseStatus.unconfigured,
        productId: productId,
        message: AppStrings.g('pro.iap.unconfigured'),
      );

  @override
  Future<void> restorePurchases() async {}
}
