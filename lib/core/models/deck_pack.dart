/// A browsable digital deck or rune set (either built-in or installed from the
/// Tarot Tree digital store). Promo banner artwork is managed on the backend
/// (`/api/v1/store/promos/`) and cached locally by pack ID.
abstract class DeckPack {
  const DeckPack();

  String get id;
  String get name;
  String get subtitle;
  String get license;

  /// True when this pack was downloaded from the digital store rather than
  /// bundled into the Flutter asset manifest.
  bool get isStorePack => storeKey != null;

  /// Cross-platform storage namespace (`<system>/<slug>/<version>`) in
  /// `PackAssetStore`, or `null` for built-in packs.
  String? get storeKey => null;

  /// Optional relative path to the extracted `cover.webp` inside [storeKey].
  String? get storeCoverPath => null;
}
