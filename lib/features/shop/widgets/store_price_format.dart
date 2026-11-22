import '../../../core/l10n/app_strings.dart';
import '../../../core/models/store_models.dart';

String formatStorePrice(StoreProduct product, AppLanguage language) {
  if (product.free || product.priceMinor <= 0) {
    return AppStrings.t(language, 'shop.price.free');
  }
  final major = (product.priceMinor / 100).toStringAsFixed(2);
  return switch (product.currency.toUpperCase()) {
    'USD' => '\$$major',
    'EUR' => '€$major',
    'GBP' => '£$major',
    'RUB' => '${(product.priceMinor / 100).round()} ₽',
    final code => '$major $code',
  };
}

String formatStoreBytes(int bytes) {
  if (bytes >= 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  if (bytes >= 1024) {
    return '${(bytes / 1024).round()} KB';
  }
  return '$bytes B';
}
