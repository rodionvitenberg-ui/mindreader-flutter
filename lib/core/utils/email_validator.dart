/// Strict email format validator + lightweight typo detector for common
/// email domains so readers catch typos before binding PRO status or recovery.
class EmailValidator {
  static final RegExp _pattern = RegExp(
    r"^[A-Za-z0-9.!#$%&'*+/=?^_`{|}~-]+@[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?)*\.[A-Za-z]{2,}$",
  );

  static const Map<String, String> _domainTypos = {
    'gamil.com': 'gmail.com',
    'gmial.com': 'gmail.com',
    'gmal.com': 'gmail.com',
    'gnail.com': 'gmail.com',
    'gmaill.com': 'gmail.com',
    'gmail.con': 'gmail.com',
    'gmail.co': 'gmail.com',
    'gmail.cm': 'gmail.com',
    'gmail.om': 'gmail.com',
    'gmail.ru': 'gmail.com',
    'googlemail.con': 'googlemail.com',
    'yanex.ru': 'yandex.ru',
    'yndex.ru': 'yandex.ru',
    'yande.ru': 'yandex.ru',
    'yandex.r': 'yandex.ru',
    'yandex.con': 'yandex.ru',
    'yandex.cm': 'yandex.ru',
    'yandx.ru': 'yandex.ru',
    'mial.ru': 'mail.ru',
    'mal.ru': 'mail.ru',
    'mail.r': 'mail.ru',
    'mail.con': 'mail.ru',
    'maill.ru': 'mail.ru',
    'bk.r': 'bk.ru',
    'inbox.r': 'inbox.ru',
    'list.r': 'list.ru',
    'icoud.com': 'icloud.com',
    'iclod.com': 'icloud.com',
    'icloud.con': 'icloud.com',
    'icloud.cm': 'icloud.com',
    'outlok.com': 'outlook.com',
    'outlook.con': 'outlook.com',
    'hotmial.com': 'hotmail.com',
    'hotmail.con': 'hotmail.com',
    'yaho.com': 'yahoo.com',
    'yahoo.con': 'yahoo.com',
    'protonmial.com': 'protonmail.com',
    'proton.m': 'proton.me',
  };

  /// Returns true when [raw] is a syntactically valid email address with no
  /// whitespace, no consecutive dots, and a real domain + TLD.
  static bool isValid(String raw) {
    final value = raw.trim();
    if (value.isEmpty || value.length > 254) return false;
    if (value.contains(' ') || value.contains('..')) return false;
    final at = value.indexOf('@');
    if (at <= 0 || at != value.lastIndexOf('@')) return false;
    if (at > 64) return false;
    return _pattern.hasMatch(value);
  }

  /// Returns a corrected full email address if the domain matches a known
  /// common typo (e.g. `user@gamil.com` → `user@gmail.com`), or `null`.
  static String? suggestCorrection(String raw) {
    final value = raw.trim();
    final at = value.indexOf('@');
    if (at <= 0 || at != value.lastIndexOf('@')) return null;
    final local = value.substring(0, at);
    final domain = value.substring(at + 1).toLowerCase();
    final fix = _domainTypos[domain];
    if (fix == null) return null;
    return '$local@$fix';
  }
}
