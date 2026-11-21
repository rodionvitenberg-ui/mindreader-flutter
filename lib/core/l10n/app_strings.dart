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

  /// Localized card/stone count caption used on spread tiles where the number
  /// helps convey the spread's scale (e.g. "5 cards" / "5 карт", "7 stones" /
  /// "7 рун").
  static String cardCount(
    AppLanguage lang,
    int count, {
    bool isRune = false,
  }) {
    if (lang == AppLanguage.ru) {
      final mod100 = count % 100;
      final mod10 = count % 10;
      if (isRune) {
        if (mod100 >= 11 && mod100 <= 14) return '$count рун';
        if (mod10 == 1) return '$count руна';
        if (mod10 >= 2 && mod10 <= 4) return '$count руны';
        return '$count рун';
      }
      if (mod100 >= 11 && mod100 <= 14) return '$count карт';
      if (mod10 == 1) return '$count карта';
      if (mod10 >= 2 && mod10 <= 4) return '$count карты';
      return '$count карт';
    }
    if (isRune) {
      return '$count ${count == 1 ? 'stone' : 'stones'}';
    }
    return '$count ${count == 1 ? 'card' : 'cards'}';
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

    'astral.edit': {
      AppLanguage.en: 'Edit birth data',
      AppLanguage.ru: 'Изменить данные рождения',
    },
    'astral.newChart': {
      AppLanguage.en: 'NEW NATAL CHART',
      AppLanguage.ru: 'НОВАЯ НАТАЛЬНАЯ КАРТА',
    },
    'astral.generate': {
      AppLanguage.en: '✦ GENERATE NATAL CHART',
      AppLanguage.ru: '✦ ПОСТРОИТЬ НАТАЛЬНУЮ КАРТУ',
    },
    'astral.save': {
      AppLanguage.en: 'Save changes',
      AppLanguage.ru: 'Сохранить изменения',
    },
    'astral.name': {AppLanguage.en: 'NAME', AppLanguage.ru: 'ИМЯ'},
    'astral.date': {AppLanguage.en: 'DATE', AppLanguage.ru: 'ДАТА'},
    'astral.time': {AppLanguage.en: 'TIME', AppLanguage.ru: 'ВРЕМЯ'},
    'astral.city': {
      AppLanguage.en: 'BIRTH CITY',
      AppLanguage.ru: 'ГОРОД РОЖДЕНИЯ',
    },
    'astral.searchCity': {
      AppLanguage.en: 'Search a city',
      AppLanguage.ru: 'Найти город',
    },
    'astral.house': {
      AppLanguage.en: 'HOUSE SYSTEM',
      AppLanguage.ru: 'СИСТЕМА ДОМОВ',
    },
    'astral.legacyTime': {
      AppLanguage.en:
          'Check the birth data so this chart uses historical time zone rules.',
      AppLanguage.ru: 'Проверьте данные рождения, чтобы карта учитывала исторический часовой пояс.',
    },
    'astral.unknownTime': {
      AppLanguage.en: 'Birth time unknown',
      AppLanguage.ru: 'Время рождения неизвестно',
    },
    'astral.unknownMoon': {
      AppLanguage.en: 'The Moon changes signs on this date.',
      AppLanguage.ru: 'В этот день Луна меняет знак.',
    },
    'astral.missingCity': {
      AppLanguage.en: 'Choose a birth city first.',
      AppLanguage.ru: 'Выберите город рождения.',
    },
    'astral.skippedTime': {
      AppLanguage.en:
          'This local time did not exist on that date. Check the birth time.',
      AppLanguage.ru: 'Такого местного времени в эту дату не было. Проверьте время рождения.',
    },
    'astral.repeatedTime': {
      AppLanguage.en: 'Which UTC offset applied at birth?',
      AppLanguage.ru: 'Какое смещение UTC действовало в момент рождения?',
    },
    'astral.today': {AppLanguage.en: 'Today', AppLanguage.ru: 'Сегодня'},
    'astral.week': {AppLanguage.en: '7 days', AppLanguage.ru: '7 дней'},
    'astral.transits': {AppLanguage.en: 'Transits', AppLanguage.ru: 'Транзиты'},
    'astral.orb': {AppLanguage.en: 'Orb', AppLanguage.ru: 'Орбис'},
    'astral.exact': {
      AppLanguage.en: 'Exact at',
      AppLanguage.ru: 'Точный аспект',
    },
    'astral.closest': {
      AppLanguage.en: 'Closest in this period',
      AppLanguage.ru: 'Минимальный орбис за период',
    },
    'astral.activePeriod': {
      AppLanguage.en: 'Active period',
      AppLanguage.ru: 'Период действия',
    },
    'astral.outsideRange': {
      AppLanguage.en: 'Beyond calculation range',
      AppLanguage.ru: 'За пределами расчёта',
    },
    'astral.discuss': {
      AppLanguage.en: 'Discuss with Oracle',
      AppLanguage.ru: 'Обсудить с Оракулом',
    },
    'astral.discussTransit': {
      AppLanguage.en: 'Discuss this transit',
      AppLanguage.ru: 'Обсудить этот транзит',
    },
    'astral.chooseFirst': {
      AppLanguage.en: 'First person',
      AppLanguage.ru: 'Первый человек',
    },
    'astral.chooseSecond': {
      AppLanguage.en: 'Second person',
      AppLanguage.ru: 'Второй человек',
    },
    'astral.addPerson': {
      AppLanguage.en: 'Add a person',
      AppLanguage.ru: 'Добавить человека',
    },
    'astral.selectPair': {
      AppLanguage.en: 'Select two different birth charts.',
      AppLanguage.ru: 'Выберите две разные натальные карты.',
    },
    'astral.relationshipThemes': {
      AppLanguage.en: 'Relationship themes',
      AppLanguage.ru: 'Темы отношений',
    },
    'astral.allAspects': {
      AppLanguage.en: 'All cross-chart aspects',
      AppLanguage.ru: 'Все аспекты между картами',
    },
    'astral.synastryDetails': {
      AppLanguage.en: 'Compatibility details',
      AppLanguage.ru: 'Подробнее о совместимости',
    },
    'astral.pickDate': {
      AppLanguage.en: 'Choose a date',
      AppLanguage.ru: 'Выбрать дату',
    },
    'astral.selectTime': {
      AppLanguage.en: 'TIME KNOWN',
      AppLanguage.ru: 'ВРЕМЯ ИЗВЕСТНО',
    },
    'astral.placement': {
      AppLanguage.en: 'FULL PLACEMENTS',
      AppLanguage.ru: 'ПОЛОЖЕНИЯ',
    },
    'astral.matrix': {
      AppLanguage.en: 'ASPECT MATRIX',
      AppLanguage.ru: 'АСПЕКТЫ',
    },
    'astral.details': {
      AppLanguage.en: 'OPEN FULL PROFILE',
      AppLanguage.ru: 'ПОДРОБНОСТИ КАРТЫ',
    },
    'astral.close': {AppLanguage.en: 'Close', AppLanguage.ru: 'Закрыть'},
    'astral.profileFill': {
      AppLanguage.en: 'FILL FROM PROFILE',
      AppLanguage.ru: 'ЗАПОЛНИТЬ ИЗ ПРОФИЛЯ',
    },
    'astral.natalWheel': {
      AppLanguage.en: 'NATAL WHEEL',
      AppLanguage.ru: 'НАТАЛЬНОЕ КОЛЕСО',
    },
    'astral.replay': {
      AppLanguage.en: '↻ REPLAY',
      AppLanguage.ru: '↻ ПОВТОРИТЬ',
    },
    'astral.overlay': {
      AppLanguage.en: '✦ LIVE TRANSITS OVERLAY',
      AppLanguage.ru: '✦ ТЕКУЩИЕ ТРАНЗИТЫ',
    },
    'astral.myChart': {AppLanguage.en: 'MY CHART', AppLanguage.ru: 'МОЯ КАРТА'},
    'astral.noTransits': {
      AppLanguage.en: 'No active transits for this day.',
      AppLanguage.ru: 'На этот день нет активных транзитов.',
    },
    'header.almanac': {AppLanguage.en: 'Almanac', AppLanguage.ru: 'Альманах'},
    'header.profile': {AppLanguage.en: 'Profile', AppLanguage.ru: 'Профиль'},

    'almanac.all': {AppLanguage.en: 'All', AppLanguage.ru: 'Все'},
    'almanac.major': {AppLanguage.en: 'Major', AppLanguage.ru: 'Старшие'},
    'almanac.water': {AppLanguage.en: 'Water', AppLanguage.ru: 'Вода'},
    'almanac.air': {AppLanguage.en: 'Air', AppLanguage.ru: 'Воздух'},
    'almanac.fire': {AppLanguage.en: 'Fire', AppLanguage.ru: 'Огонь'},
    'almanac.earth': {AppLanguage.en: 'Earth', AppLanguage.ru: 'Земля'},
    'almanac.wands': {AppLanguage.en: 'Wands', AppLanguage.ru: 'Жезлы'},
    'almanac.cups': {AppLanguage.en: 'Cups', AppLanguage.ru: 'Кубки'},
    'almanac.swords': {AppLanguage.en: 'Swords', AppLanguage.ru: 'Мечи'},
    'almanac.pentacles': {
      AppLanguage.en: 'Pentacles',
      AppLanguage.ru: 'Пентакли',
    },
    'almanac.hearts': {AppLanguage.en: 'Hearts', AppLanguage.ru: 'Червы'},
    'almanac.diamonds': {AppLanguage.en: 'Diamonds', AppLanguage.ru: 'Бубны'},
    'almanac.clubs': {AppLanguage.en: 'Clubs', AppLanguage.ru: 'Трефы'},
    'almanac.spades': {AppLanguage.en: 'Spades', AppLanguage.ru: 'Пики'},
    'almanac.cardinal': {
      AppLanguage.en: 'Cardinal',
      AppLanguage.ru: 'Кардинальные',
    },
    'almanac.fixed': {AppLanguage.en: 'Fixed', AppLanguage.ru: 'Фиксированные'},
    'almanac.mutable': {
      AppLanguage.en: 'Mutable',
      AppLanguage.ru: 'Мутабельные',
    },
    'almanac.freyr': {
      AppLanguage.en: 'Freyr’s Aett',
      AppLanguage.ru: 'Атт Фрейра',
    },
    'almanac.hagal': {
      AppLanguage.en: 'Hagal’s Aett',
      AppLanguage.ru: 'Атт Хагаля',
    },
    'almanac.tyr': {AppLanguage.en: 'Tyr’s Aett', AppLanguage.ru: 'Атт Тюра'},
    'almanac.picker.tarot': {
      AppLanguage.en: 'DECK SELECTOR',
      AppLanguage.ru: 'Выбор колоды',
    },
    'almanac.picker.lenormand': {
      AppLanguage.en: 'LENORMAND PACKS',
      AppLanguage.ru: 'Колоды Ленорман',
    },
    'almanac.picker.runes': {
      AppLanguage.en: 'RUNE STONE SETS',
      AppLanguage.ru: 'Наборы рун',
    },
    'almanac.deck': {AppLanguage.en: 'DECK', AppLanguage.ru: 'КОЛОДА'},
    'almanac.cover': {AppLanguage.en: 'Cover', AppLanguage.ru: 'Заставка'},
    'almanac.shop': {
      AppLanguage.en: 'Deck shop',
      AppLanguage.ru: 'Магазин колод',
    },
    'almanac.shopLink': {
      AppLanguage.en: 'Deck shop →',
      AppLanguage.ru: 'Магазин колод →',
    },
    'almanac.website': {
      AppLanguage.en: 'View on website',
      AppLanguage.ru: 'На сайте магазина',
    },
    'almanac.buy': {
      AppLanguage.en: 'Buy on website',
      AppLanguage.ru: 'Купить на сайте',
    },
    'almanac.launchError': {
      AppLanguage.en: 'Could not open the shop website',
      AppLanguage.ru: 'Не удалось открыть сайт магазина',
    },
    'almanac.tarot': {AppLanguage.en: 'TAROT', AppLanguage.ru: 'ТАРО'},
    'almanac.lenormand': {
      AppLanguage.en: 'LENORMAND',
      AppLanguage.ru: 'ЛЕНОРМАН',
    },
    'almanac.runes': {AppLanguage.en: 'RUNES', AppLanguage.ru: 'РУНЫ'},
    'almanac.zodiac': {AppLanguage.en: 'ZODIAC', AppLanguage.ru: 'ЗОДИАК'},
    'almanac.searchCards': {
      AppLanguage.en: 'Search card, keyword or glyph',
      AppLanguage.ru: 'Найти карту, руну или слово',
    },
    'almanac.searchSigns': {
      AppLanguage.en: 'Search sign, keyword or archetype',
      AppLanguage.ru: 'Найти знак, слово или архетип',
    },
    'almanac.noCards': {
      AppLanguage.en: 'No cards match',
      AppLanguage.ru: 'Ничего не найдено',
    },
    'almanac.noSigns': {
      AppLanguage.en: 'No signs match',
      AppLanguage.ru: 'Знаки не найдены',
    },

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
      AppLanguage.en: 'Topic or question (day, love, work)…',
      AppLanguage.ru: 'Тема или вопрос (день, отношения, работа)…',
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

    // ---- spread selection & custom spread ----
    'spread.choose': {
      AppLanguage.en: 'Choose Spread',
      AppLanguage.ru: 'Выбор расклада',
    },
    'spread.tarot.one': {
      AppLanguage.en: 'Daily Anchor',
      AppLanguage.ru: 'Карта дня',
    },
    'spread.tarot.three': {
      AppLanguage.en: 'Three Cards',
      AppLanguage.ru: 'Три карты',
    },
    'spread.tarot.four': {
      AppLanguage.en: 'Target & Shadow',
      AppLanguage.ru: 'Цель и тень',
    },
    'spread.tarot.loveBridge': {
      AppLanguage.en: 'Love Bridge',
      AppLanguage.ru: 'Любовный мост',
    },
    'spread.tarot.careerCrossroads': {
      AppLanguage.en: 'Career Crossroads',
      AppLanguage.ru: 'Перекрёсток пути',
    },
    'spread.tarot.seven': {
      AppLanguage.en: 'Horseshoe Synthesis',
      AppLanguage.ru: 'Подкова',
    },
    'spread.tarot.celticCross': {
      AppLanguage.en: 'Celtic Cross',
      AppLanguage.ru: 'Кельтский крест',
    },
    'spread.lenormand.one': {
      AppLanguage.en: 'Daily Sign',
      AppLanguage.ru: 'Знак дня',
    },
    'spread.lenormand.three': {
      AppLanguage.en: 'Lenormand Line',
      AppLanguage.ru: 'Три карты',
    },
    'spread.lenormand.five': {
      AppLanguage.en: 'Cross of 5',
      AppLanguage.ru: 'Крест из 5',
    },
    'spread.lenormand.nine': {
      AppLanguage.en: '3×3 Portrait Box',
      AppLanguage.ru: 'Портрет 3×3',
    },
    'spread.lenormand.grandPortrait': {
      AppLanguage.en: 'Grand Portrait',
      AppLanguage.ru: 'Большой портрет',
    },
    'spread.runes.one': {
      AppLanguage.en: 'Odin’s Rune',
      AppLanguage.ru: 'Руна Одина',
    },
    'spread.runes.three': {
      AppLanguage.en: 'The Three Norns',
      AppLanguage.ru: 'Три норны',
    },
    'spread.runes.five': {
      AppLanguage.en: 'Thor’s Cross',
      AppLanguage.ru: 'Крест Тора',
    },
    'spread.runes.seven': {
      AppLanguage.en: 'Heimdall’s Bridge',
      AppLanguage.ru: 'Мост Хеймдалля',
    },
    'spread.runes.worldTree': {
      AppLanguage.en: 'Yggdrasil’s World Tree',
      AppLanguage.ru: 'Древо миров',
    },
    'spread.custom': {
      AppLanguage.en: 'Custom Spread',
      AppLanguage.ru: 'Свой расклад',
    },
    'spread.customSubtitle': {
      AppLanguage.en: 'Write or dictate 1–12 questions',
      AppLanguage.ru: 'Напишите или продиктуйте 1–12 вопросов',
    },
    'spread.customTitleLabel': {
      AppLanguage.en: 'Spread name (optional)',
      AppLanguage.ru: 'Название расклада (необязательно)',
    },
    'spread.customQuestionsLabel': {
      AppLanguage.en: 'QUESTIONS · 1 QUESTION = 1 POSITION',
      AppLanguage.ru: 'ВОПРОСЫ · 1 ВОПРОС = 1 ПОЗИЦИЯ',
    },
    'spread.customQuestionInput': {
      AppLanguage.en: 'Write or dictate a question…',
      AppLanguage.ru: 'Напишите или продиктуйте вопрос…',
    },
    'spread.customAddQuestion': {
      AppLanguage.en: 'Add question',
      AppLanguage.ru: 'Добавить вопрос',
    },
    'spread.customEmptyHint': {
      AppLanguage.en:
          'Add 1 to 12 questions — each becomes its own position on the table.',
      AppLanguage.ru:
          'Добавьте от 1 до 12 вопросов — каждый станет отдельной позицией на столе.',
    },
    'spread.customLimitReached': {
      AppLanguage.en: 'Maximum of 12 positions reached',
      AppLanguage.ru: 'Достигнут максимум — 12 позиций',
    },
    'spread.customMoveUp': {
      AppLanguage.en: 'Move up',
      AppLanguage.ru: 'Поднять выше',
    },
    'spread.customMoveDown': {
      AppLanguage.en: 'Move down',
      AppLanguage.ru: 'Опустить ниже',
    },
    'spread.customDelete': {
      AppLanguage.en: 'Remove question',
      AppLanguage.ru: 'Удалить вопрос',
    },
    'spread.customOpenTable': {
      AppLanguage.en: 'OPEN TABLE',
      AppLanguage.ru: 'ОТКРЫТЬ СТОЛ',
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
    'reading.title': {AppLanguage.en: 'Reading experience', AppLanguage.ru: 'Помощь при раскладе'},
    'reading.positions': {AppLanguage.en: 'Show spread positions', AppLanguage.ru: 'Показывать позиции'},
    'reading.guide': {AppLanguage.en: 'Guided reading', AppLanguage.ru: 'Обучение во время расклада'},
    'reading.relationships': {AppLanguage.en: 'Show card relationships', AppLanguage.ru: 'Показывать связи карт'},
    'reading.positions.hint': {AppLanguage.en: 'Outline and number empty spaces.', AppLanguage.ru: 'Контуры и номера свободных мест.'},
    'reading.guide.hint': {AppLanguage.en: 'Get a short tip for the next step.', AppLanguage.ru: 'Краткая подсказка для следующего шага.'},
    'reading.relationships.hint': {AppLanguage.en: 'Explore connections when inspecting a card.', AppLanguage.ru: 'Связи при просмотре открытой карты.'},
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
