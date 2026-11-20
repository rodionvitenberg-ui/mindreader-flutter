/// A browsable digital deck or rune set. Cover paths are optional until
/// dedicated landscape illustrations are bundled with the pack.
abstract class DeckPack {
  const DeckPack({this.coverAssets = const []});

  String get id;
  String get name;
  String get subtitle;
  String get license;
  final List<String> coverAssets;
}
