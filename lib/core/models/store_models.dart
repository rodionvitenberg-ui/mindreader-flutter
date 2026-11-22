import '../models/deck_pack.dart';
import '../models/divination_system.dart';
import '../models/lenormand_pack.dart';
import '../models/rune_pack.dart';
import '../models/tarot_deck_pack.dart';

class BackendAuthSession {
  const BackendAuthSession({
    required this.id,
    required this.verified,
    required this.token,
    required this.expiresAt,
    this.email,
  });

  final String id;
  final bool verified;
  final String? email;
  final String token;
  final DateTime expiresAt;

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  Map<String, dynamic> toJson() => {
        'id': id,
        'verified': verified,
        'email': email,
        'token': token,
        'expiresAt': expiresAt.toIso8601String(),
      };

  static BackendAuthSession? fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final token = json['token'];
    final expiresRaw = json['expiresAt'];
    if (id is! String || token is! String || expiresRaw is! String) return null;
    final expires = DateTime.tryParse(expiresRaw);
    if (expires == null) return null;
    return BackendAuthSession(
      id: id,
      verified: json['verified'] == true,
      email: json['email'] is String ? json['email'] as String : null,
      token: token,
      expiresAt: expires,
    );
  }
}

class BackendPublicConfig {
  const BackendPublicConfig({
    this.guestAccess = true,
    this.emailVerification = false,
    this.devPayments = false,
  });

  final bool guestAccess;
  final bool emailVerification;
  final bool devPayments;

  factory BackendPublicConfig.fromJson(Map<String, dynamic> json) =>
      BackendPublicConfig(
        guestAccess: json['guestAccess'] != false,
        emailVerification: json['emailVerification'] == true,
        devPayments: json['devPayments'] == true,
      );
}

class StoreVersionInfo {
  const StoreVersionInfo({
    required this.version,
    required this.minAppVersion,
    required this.incomplete,
    required this.cardCount,
    required this.sizeBytes,
    required this.sha256,
  });

  final String version;
  final String minAppVersion;
  final bool incomplete;
  final int cardCount;
  final int sizeBytes;
  final String sha256;

  factory StoreVersionInfo.fromJson(Map<String, dynamic> json) =>
      StoreVersionInfo(
        version: json['version'] as String? ?? '1.0.0',
        minAppVersion: json['minAppVersion'] as String? ?? '0.0.0',
        incomplete: json['incomplete'] == true,
        cardCount: (json['cardCount'] as num?)?.toInt() ?? 0,
        sizeBytes: (json['sizeBytes'] as num?)?.toInt() ?? 0,
        sha256: json['sha256'] as String? ?? '',
      );
}

class StorePreviewAsset {
  const StorePreviewAsset({required this.kind, required this.url});

  final String kind;
  final String url;
}

class StoreProduct {
  const StoreProduct({
    required this.id,
    required this.slug,
    required this.title,
    required this.tagline,
    required this.description,
    required this.system,
    required this.itemType,
    required this.badge,
    required this.featured,
    required this.sortOrder,
    required this.visualConfig,
    required this.artist,
    required this.publisher,
    required this.license,
    required this.attribution,
    required this.free,
    required this.priceMinor,
    required this.currency,
    required this.owned,
    this.promoImageUrl,
    this.coverUrl,
    this.version,
  });

  final String id;
  final String slug;
  final String title;
  final String tagline;
  final String description;
  final DivinationSystem system;
  final String itemType;
  final String badge;
  final bool featured;
  final int sortOrder;
  final Map<String, dynamic> visualConfig;
  final String artist;
  final String publisher;
  final String license;
  final String attribution;
  final bool free;
  final int priceMinor;
  final String currency;
  final bool owned;
  final String? promoImageUrl;
  final String? coverUrl;
  final StoreVersionInfo? version;

  String? get artworkUrl =>
      (promoImageUrl != null && promoImageUrl!.isNotEmpty)
          ? promoImageUrl
          : coverUrl;

  StoreProduct copyWith({bool? owned}) => StoreProduct(
        id: id,
        slug: slug,
        title: title,
        tagline: tagline,
        description: description,
        system: system,
        itemType: itemType,
        badge: badge,
        featured: featured,
        sortOrder: sortOrder,
        visualConfig: visualConfig,
        artist: artist,
        publisher: publisher,
        license: license,
        attribution: attribution,
        free: free,
        priceMinor: priceMinor,
        currency: currency,
        owned: owned ?? this.owned,
        promoImageUrl: promoImageUrl,
        coverUrl: coverUrl,
        version: version,
      );

  static StoreProduct fromJson(
    Map<String, dynamic> json, {
    required Uri origin,
  }) {
    String? resolve(Object? raw) {
      if (raw is! String || raw.isEmpty) return null;
      return origin.resolve(raw).toString();
    }

    final sysName = json['system'] as String? ?? 'tarot';
    final sys = DivinationSystem.values.firstWhere(
      (s) => s.name == sysName,
      orElse: () => DivinationSystem.tarot,
    );
    final rawVersion = json['version'];
    final rawStyle = json['visualConfig'];
    return StoreProduct(
      id: json['id'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      title: json['title'] as String? ?? '',
      tagline: json['tagline'] as String? ?? '',
      description: json['description'] as String? ?? '',
      system: sys,
      itemType: json['itemType'] as String? ?? '${sys.name}_deck',
      badge: json['badge'] as String? ?? '',
      featured: json['featured'] == true,
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 100,
      visualConfig: rawStyle is Map
          ? Map<String, dynamic>.from(rawStyle)
          : const {},
      artist: json['artist'] as String? ?? '',
      publisher: json['publisher'] as String? ?? '',
      license: json['license'] as String? ?? '',
      attribution: json['attribution'] as String? ?? '',
      free: json['free'] == true || ((json['priceMinor'] as num?)?.toInt() ?? 0) == 0,
      priceMinor: (json['priceMinor'] as num?)?.toInt() ?? 0,
      currency: json['currency'] as String? ?? 'USD',
      owned: json['owned'] == true,
      promoImageUrl: resolve(json['promoImageUrl']),
      coverUrl: resolve(json['coverUrl']),
      version: rawVersion is Map
          ? StoreVersionInfo.fromJson(Map<String, dynamic>.from(rawVersion))
          : null,
    );
  }
}

class StoreProductDetail {
  const StoreProductDetail({
    required this.product,
    required this.previews,
    required this.versions,
  });

  final StoreProduct product;
  final List<StorePreviewAsset> previews;
  final List<StoreVersionInfo> versions;

  static StoreProductDetail fromJson(
    Map<String, dynamic> json, {
    required Uri origin,
  }) {
    final product = StoreProduct.fromJson(json, origin: origin);
    final rawPreviews = json['previews'] as List? ?? const [];
    final previews = <StorePreviewAsset>[
      for (final item in rawPreviews)
        if (item is Map && item['url'] is String)
          StorePreviewAsset(
            kind: item['kind'] as String? ?? 'preview',
            url: origin.resolve(item['url'] as String).toString(),
          ),
    ];
    final rawVersions = json['versions'] as List? ?? const [];
    final versions = <StoreVersionInfo>[
      for (final item in rawVersions)
        if (item is Map)
          StoreVersionInfo.fromJson(Map<String, dynamic>.from(item)),
    ];
    return StoreProductDetail(
      product: product,
      previews: previews,
      versions: versions,
    );
  }
}

class StoreDownloadInfo {
  const StoreDownloadInfo({
    required this.version,
    required this.minAppVersion,
    required this.incomplete,
    required this.cardCount,
    required this.sizeBytes,
    required this.sha256,
    required this.url,
  });

  final String version;
  final String minAppVersion;
  final bool incomplete;
  final int cardCount;
  final int sizeBytes;
  final String sha256;
  final String url;

  static StoreDownloadInfo fromJson(
    Map<String, dynamic> json, {
    required Uri origin,
  }) {
    return StoreDownloadInfo(
      version: json['version'] as String? ?? '1.0.0',
      minAppVersion: json['minAppVersion'] as String? ?? '0.0.0',
      incomplete: json['incomplete'] == true,
      cardCount: (json['cardCount'] as num?)?.toInt() ?? 0,
      sizeBytes: (json['sizeBytes'] as num?)?.toInt() ?? 0,
      sha256: json['sha256'] as String? ?? '',
      url: origin.resolve(json['url'] as String? ?? '').toString(),
    );
  }
}

enum StoreInstallStage {
  idle,
  awaitingWebCheckout,
  claiming,
  downloading,
  verifying,
  installing,
  installed,
  error,
}

class StoreInstallState {
  const StoreInstallState({
    this.stage = StoreInstallStage.idle,
    this.progress = 0,
    this.errorMessage,
  });

  final StoreInstallStage stage;
  final double progress;
  final String? errorMessage;

  bool get isBusy =>
      stage == StoreInstallStage.claiming ||
      stage == StoreInstallStage.downloading ||
      stage == StoreInstallStage.verifying ||
      stage == StoreInstallStage.installing;
}

/// Serializable metadata for a store pack installed into `PackAssetStore`.
class InstalledPackRecord {
  const InstalledPackRecord({
    required this.deckId,
    required this.slug,
    required this.system,
    required this.version,
    required this.storeKey,
    required this.title,
    required this.tagline,
    required this.license,
    required this.cardPaths,
    required this.stonePaths,
    this.backPath,
    this.coverPath,
    this.style = const {},
  });

  final String deckId;
  final String slug;
  final DivinationSystem system;
  final String version;
  final String storeKey;
  final String title;
  final String tagline;
  final String license;
  final Map<int, String> cardPaths;
  final List<String> stonePaths;
  final String? backPath;
  final String? coverPath;
  final Map<String, dynamic> style;

  Map<String, dynamic> toJson() => {
        'deckId': deckId,
        'slug': slug,
        'system': system.name,
        'version': version,
        'storeKey': storeKey,
        'title': title,
        'tagline': tagline,
        'license': license,
        'cardPaths': {
          for (final e in cardPaths.entries) e.key.toString(): e.value,
        },
        'stonePaths': stonePaths,
        'backPath': backPath,
        'coverPath': coverPath,
        'style': style,
      };

  static InstalledPackRecord? fromJson(Map<String, dynamic> json) {
    final slug = json['slug'];
    final storeKey = json['storeKey'];
    final sysName = json['system'];
    if (slug is! String || storeKey is! String || sysName is! String) {
      return null;
    }
    final sys = DivinationSystem.values.firstWhere(
      (s) => s.name == sysName,
      orElse: () => DivinationSystem.tarot,
    );
    final rawCards = json['cardPaths'] as Map? ?? const {};
    final cards = <int, String>{};
    for (final entry in rawCards.entries) {
      final k = int.tryParse(entry.key.toString());
      if (k != null && entry.value is String) {
        cards[k] = entry.value as String;
      }
    }
    final rawStones = json['stonePaths'] as List? ?? const [];
    final rawStyle = json['style'];
    return InstalledPackRecord(
      deckId: json['deckId'] as String? ?? slug,
      slug: slug,
      system: sys,
      version: json['version'] as String? ?? '1.0.0',
      storeKey: storeKey,
      title: json['title'] as String? ?? slug,
      tagline: json['tagline'] as String? ?? '',
      license: json['license'] as String? ?? '',
      cardPaths: cards,
      stonePaths: [for (final s in rawStones) if (s is String) s],
      backPath: json['backPath'] as String?,
      coverPath: json['coverPath'] as String?,
      style: rawStyle is Map ? Map<String, dynamic>.from(rawStyle) : const {},
    );
  }

  /// Instantiates the concrete [DeckPack] (`TarotDeckPack`, `LenormandPack`, or
  /// `RunePack`) used everywhere across the Table, Almanac, and Deck Picker.
  DeckPack toDeckPack() {
    int argb(String key, int fallback) {
      final val = style[key];
      if (val is int) return val;
      if (val is num) return val.toInt();
      return fallback;
    }

    CardBackStyle parseBackStyle(Object? raw) {
      if (raw is String) {
        for (final value in CardBackStyle.values) {
          if (value.name == raw) return value;
        }
      }
      return CardBackStyle.obsidian;
    }

    switch (system) {
      case DivinationSystem.tarot:
        return TarotDeckPack(
          id: slug,
          name: title,
          rawSubtitle: tagline,
          assetFolder: '',
          rawLicense: license,
          backStyle: parseBackStyle(style['backStyle']),
          backAccentArgb: argb('backAccentArgb', 0xFFA78BFA),
          backSecondaryArgb: argb('backSecondaryArgb', 0xFF6366F1),
          faceAccentArgb: argb('faceAccentArgb', 0xFFA78BFA),
          faceSecondaryArgb: argb('faceSecondaryArgb', 0xFF6366F1),
          isIllustrated: style['isIllustrated'] != false,
          storeKey: storeKey,
          storeCoverPath: coverPath,
          storeCardPaths: cardPaths,
          storeBackPath: backPath,
        );
      case DivinationSystem.lenormand:
        return LenormandPack(
          id: slug,
          name: title,
          rawSubtitle: tagline,
          assetFolder: '',
          rawLicense: license,
          backStyle: parseBackStyle(style['backStyle']),
          backAccentArgb: argb('backAccentArgb', 0xFFA78BFA),
          backSecondaryArgb: argb('backSecondaryArgb', 0xFF6366F1),
          faceAccentArgb: argb('faceAccentArgb', 0xFFA78BFA),
          faceSecondaryArgb: argb('faceSecondaryArgb', 0xFF6366F1),
          faceBackgroundArgb: argb('faceBackgroundArgb', 0xFF13131A),
          storeKey: storeKey,
          storeCoverPath: coverPath,
          storeCardPaths: cardPaths,
          storeBackPath: backPath,
        );
      case DivinationSystem.runes:
        return RunePack(
          id: slug,
          name: title,
          rawSubtitle: tagline,
          assetFolder: '',
          rawLicense: license,
          stoneBaseArgb: argb('stoneBaseArgb', 0xFF3A2B22),
          stoneDarkArgb: argb('stoneDarkArgb', 0xFF140D09),
          stoneRimArgb: argb('stoneRimArgb', 0xFF7DD3FC),
          glyphArgb: argb('glyphArgb', 0xFFE0F2FE),
          glowArgb: argb('glowArgb', 0xFF38BDF8),
          specularArgb: argb('specularArgb', 0xFFEFF8FF),
          carveShadowArgb: argb('carveShadowArgb', 0xDF070402),
          stoneVariantCount: stonePaths.isNotEmpty
              ? stonePaths.length
              : argb('stoneVariantCount', 5),
          storeKey: storeKey,
          storeCoverPath: coverPath,
          storeStonePaths: stonePaths,
        );
    }
  }
}
