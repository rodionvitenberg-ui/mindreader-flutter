/// UI language of the settings surface. The rest of the app keeps its
/// existing English-first copy — this enum only drives the strings that
/// live in the bottom dock, the settings sheet and the PRO subscription.
enum AppLanguage { en, ru }

/// Tiny key → localized string dictionary (Iteration 2). Deliberately not a
/// full i18n framework: only the navigation, settings and paywall strings
/// are translated so switching EN <-> RU updates those labels instantly.
class AppStrings {
  const AppStrings._();

  /// Missing keys fall back to the key itself (never throws).
  static String t(AppLanguage lang, String key) {
    final entry = _dict[key];
    if (entry == null) return key;
    return entry[lang] ?? entry[AppLanguage.en] ?? key;
  }

  static const Map<String, Map<AppLanguage, String>> _dict = {
    // ---- bottom dock ----
    'nav.camera': {AppLanguage.en: 'CAMERA', AppLanguage.ru: 'КАМЕРА'},
    'nav.table': {AppLanguage.en: 'TABLE', AppLanguage.ru: 'СТОЛ'},
    'nav.almanac': {AppLanguage.en: 'ALMANAC', AppLanguage.ru: 'АЛЬМАНАХ'},
    'nav.astral': {AppLanguage.en: 'ASTRAL', AppLanguage.ru: 'АСТРАЛ'},
    'nav.rituals': {AppLanguage.en: 'RITUALS', AppLanguage.ru: 'РИТУАЛЫ'},
    'nav.settings': {AppLanguage.en: 'SETTINGS', AppLanguage.ru: 'НАСТРОЙКИ'},
    'nav.profile': {AppLanguage.en: 'PROFILE', AppLanguage.ru: 'ПРОФИЛЬ'},

    'table.fit': {
      AppLanguage.en: 'Fit whole spread',
      AppLanguage.ru: 'Показать весь расклад',
    },
    'table.deal': {
      AppLanguage.en: 'Deal next card',
      AppLanguage.ru: 'Выложить следующую карту',
    },
    'table.myself': {
      AppLanguage.en: 'FOR MYSELF (PROFILE)',
      AppLanguage.ru: 'НА СЕБЯ',
    },
    'table.someone': {
      AppLanguage.en: 'FOR SOMEONE ELSE',
      AppLanguage.ru: 'НА ДРУГОГО',
    },
    'table.question': {
      AppLanguage.en: 'Question or details (optional)',
      AppLanguage.ru: 'Вопрос или детали (необязательно)',
    },
    'table.dictate': {
      AppLanguage.en: 'Dictate question',
      AppLanguage.ru: 'Продиктовать вопрос',
    },
    'table.stopDictation': {
      AppLanguage.en: 'Stop dictation',
      AppLanguage.ru: 'Завершить диктовку',
    },
    'table.noDictation': {
      AppLanguage.en: 'Voice input is unavailable. You can type your question.',
      AppLanguage.ru: 'Диктовка недоступна. Вопрос можно ввести с клавиатуры.',
    },

    // ---- profile page ----
    'profile.title': {AppLanguage.en: 'PROFILE', AppLanguage.ru: 'ПРОФИЛЬ'},
    'profile.card.identity': {
      AppLanguage.en: 'PERSONAL CONTEXT & BIRTH DATA',
      AppLanguage.ru: 'КОНТЕКСТ И ДАННЫЕ РОЖДЕНИЯ',
    },
    'profile.card.signIn': {
      AppLanguage.en: '1-CLICK SIGN-IN & PRO',
      AppLanguage.ru: 'ВХОД В 1 КЛИК И PRO',
    },
    'profile.card.migration': {
      AppLanguage.en: 'DEVICE MIGRATION',
      AppLanguage.ru: 'ПЕРЕНОС НА НОВОЕ УСТРОЙСТВО',
    },
    'profile.card.rituals': {
      AppLanguage.en: 'DAILY RITUALS & LANGUAGE',
      AppLanguage.ru: 'РИТУАЛЫ И ЯЗЫК',
    },

    // ---- ASTRAL windows ----
    'astral.natal': {
      AppLanguage.en: 'NATAL CHART',
      AppLanguage.ru: 'НАТАЛЬНАЯ КАРТА',
    },
    'astral.horoscope': {
      AppLanguage.en: 'HOROSCOPE',
      AppLanguage.ru: 'ГОРОСКОП',
    },
    'astral.synastry': {
      AppLanguage.en: 'SYNASTRY',
      AppLanguage.ru: 'СИНАСТРИЯ',
    },

    // ---- settings sheet ----
    'settings.title': {AppLanguage.en: 'SETTINGS', AppLanguage.ru: 'НАСТРОЙКИ'},
    'settings.language': {AppLanguage.en: 'LANGUAGE', AppLanguage.ru: 'ЯЗЫК'},
    'settings.english': {AppLanguage.en: 'ENGLISH', AppLanguage.ru: 'ENGLISH'},
    'settings.russian': {AppLanguage.en: 'РУССКИЙ', AppLanguage.ru: 'РУССКИЙ'},
    'settings.proHint': {
      AppLanguage.en: 'PRO SUBSCRIPTION',
      AppLanguage.ru: 'ПОДПИСКА PRO',
    },

    // ---- PRO subscription ----
    'pro.title': {AppLanguage.en: 'PRO', AppLanguage.ru: 'PRO'},
    'pro.subtitle': {
      AppLanguage.en: 'FREE TIER · 2 SAVED NATAL PROFILES',
      AppLanguage.ru: 'БЕСПЛАТНО · 2 ПРОФИЛЯ',
    },
    'pro.monthly': {
      AppLanguage.en: 'PRO MONTHLY',
      AppLanguage.ru: 'МЕСЯЧНАЯ ПОДПИСКА',
    },
    'pro.annual': {
      AppLanguage.en: 'PRO ANNUAL',
      AppLanguage.ru: 'ГОДОВАЯ ПОДПИСКА',
    },
    'pro.bestValue': {
      AppLanguage.en: 'BEST VALUE',
      AppLanguage.ru: 'ВЫГОДНЕЕ ВСЕГО',
    },
    'pro.activate': {
      AppLanguage.en: 'ACTIVATE PRO',
      AppLanguage.ru: 'АКТИВИРОВАТЬ PRO',
    },
    'pro.active': {
      AppLanguage.en: 'PRO ACTIVE',
      AppLanguage.ru: 'PRO АКТИВЕН',
    },
    'pro.benefit1': {
      AppLanguage.en: 'Unlimited natal profiles & synastry',
      AppLanguage.ru: 'Безлимитные профили и синастрия',
    },
    'pro.benefit2': {
      AppLanguage.en: 'Full session history & notebooks',
      AppLanguage.ru: 'Полная история сессий и блокноты',
    },
    'pro.benefit3': {
      AppLanguage.en: 'All decorative packs',
      AppLanguage.ru: 'Все декоративные наборы',
    },
    'pro.benefit4': {
      AppLanguage.en: 'Deep Oracle synthesis',
      AppLanguage.ru: 'Глубокий синтез Оракула',
    },
  };
}
