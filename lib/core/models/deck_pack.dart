/// A browsable digital deck or rune set. Promo banner artwork is managed on
/// the backend (`/api/v1/store/promos/`) and cached locally by pack ID.
abstract class DeckPack {
  const DeckPack();

  String get id;
  String get name;
  String get subtitle;
  String get license;
}
