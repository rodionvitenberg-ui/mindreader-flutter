import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/data/deck_packs_registry.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/models/deck_pack.dart';
import '../../core/models/divination_system.dart';
import '../../core/theme/app_colors.dart';
import '../../state/app_settings_controller.dart';
import '../profile/widgets/profile_header.dart';
import 'deck_cover.dart';

/// An HTTPS checkout supplied by the shop can receive the system and deck IDs.
/// Until then the listing links to the product website.
const _checkoutUrl = String.fromEnvironment('DECK_CHECKOUT_URL');
final _shopWebsite = Uri.https('soshallitbe.cyou');

Uri deckShopDestination(
  DivinationSystem system,
  String deckId, {
  String checkout = _checkoutUrl,
}) {
  final uri = Uri.tryParse(checkout);
  if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
    return _shopWebsite;
  }
  return uri.replace(
    queryParameters: {
      ...uri.queryParameters,
      'system': system.name,
      'deck': deckId,
    },
  );
}

class DeckShopScreen extends StatelessWidget {
  const DeckShopScreen({super.key, required this.system});

  final DivinationSystem system;

  Future<void> _openWebsite(
    BuildContext context,
    Uri uri,
    AppLanguage language,
  ) async {
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    } catch (_) {
      // Some platforms throw instead of returning false when no browser opens.
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.t(language, 'almanac.launchError'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final language = context.watch<AppSettingsController>().language;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const ProfileHeader(
              leading: BackButton(),
              child: ProfileHeaderTitle('almanac.shop'),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                children: [
                  for (final group in [
                    system,
                    ...DivinationSystem.values.where((s) => s != system),
                  ]) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
                      child: Text(
                        AppStrings.t(language, 'almanac.${group.name}'),
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ),
                    for (final pack in packsFor(group))
                      _listing(context, language, group, pack),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _listing(
    BuildContext context,
    AppLanguage language,
    DivinationSystem group,
    DeckPack pack,
  ) {
    final destination = deckShopDestination(group, pack.id);
    return ListTile(
      key: ValueKey('shop-${pack.id}'),
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: SizedBox(
        width: 72,
        height: 54,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: DeckCover(pack: pack),
        ),
      ),
      title: Text(pack.name),
      subtitle: Text(
        AppStrings.t(
          language,
          destination == _shopWebsite ? 'almanac.website' : 'almanac.buy',
        ),
      ),
      trailing: const Icon(
        Icons.open_in_new,
        size: 18,
        color: AppColors.textMuted,
      ),
      onTap: () => _openWebsite(context, destination, language),
    );
  }
}
