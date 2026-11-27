# Tarot Tree (`mindreader.quest`) — Аудит продукта и план выхода на рынок (PWA-first)

> Последнее обновление: 2026-11-26  
> Предыдущий спринт (Фазы 0–7 от 2026-11-24) полностью завершён и перенесён в архив внизу документа.  
> Текущая цель: **закрыть все технические, UX и продуктовые блокеры для безопасного публичного запуска PWA и получить первых пользователей и платящих подписчиков с $0 бюджета на сторы.**

---

## 1. Результаты исследования и аудита (2026-11-26)

### 1.1. Что уже построено (активы продукта)
- **Flutter-приложение:** ~64 600 строк Dart (246 файлов без учёта словарей), **98 тестовых файлов**, **6 языков × 2 760 ключей** (`en/ru/es/pt/de/fr`).
- **Django-бэкенд:** ~5 700 строк Python (64 файла) — PostgreSQL, гостевая и email-авторизация, `ai_gateway`, `oracle`, `vision`, `catalog`/`store`, `entitlements`, `payments` (включая Solana-верификацию), rate-limits и idempotency.
- **CV-движок (`enginetaro`):** ~5 450 строк Python — OpenCV-детекция контуров карт, перспективный кроп, сортировка в порядке чтения.
- **Астрономический движок:** 100% офлайн-эфемериды (`lib/core/services/natal_calculator_service.dart`, Meeus / VSOP87 + порт домов Swiss Ephemeris, сверенный с `swetest`).
- **Готовые механики удержания и виральности:**
  - 3 аутентичные системы в едином домене: Таро (78 карт, 6 исторических колод), Ленорман (36 карт, без перевёрнутых по традиции), Руны Старшего Футарка (24 3D-камня, меркстав только для несимметричных).
  - Тактильный стол (20-слойная 3D-тасовка с «запечённой» позой, полёт вытянутой карты, 680 мс переворот, Focus View + Spread View, нити стихий, свой расклад на 1–12 вопросов, +1 уточняющие карты).
  - Эффект Зейгарник («Проверка сбываемости» через 3/7/14 дней), лунные ритуалы + «Карта дня» за 30 сек + стрики, оффлайн-микрообучение за 2 минуты, 9:16 editorial-карточки для Stories с брендированием.
- **Промо-сайт (`promo-tarottree`):** Next.js на 10 языках с `/pro/`, `/shop/`, `/support/`, `/account/` и ссылкой на APK + веб-приложение.

### 1.2. Конкурентный анализ: чем мы круче и где слабее
- **Labyrinthos:** силён в обучении и минимализме, но статичный выбор карт, нет рун, нет сканера физических колод, нет глубокого диалогового ИИ-Оракула с уточняющими картами и натальной астрологией.
- **Moonly:** силён в эстетике, луне и медитациях, но гадания поверхностные — нет полноценного тактильного стола Таро, кастомных раскладов и CV-сканера.
- **Co-Star / Nebula / Hint / Astroline:** лидеры по выручке, но агрессивные пейволлы ($10–20/неделю), сбор личных данных и фатальный тон. *Ключевой рыночный инсайт:* **Nebula/Hint/Astroline зарабатывают десятки миллионов именно через Web-воронки в обход комиссий App Store/Google Play.**
- **AI-боты и веб-обёртки над ChatGPT:** нет тактильности, нет памяти/дневника, шаблонный «цыганский» стиль.

**Наши 4 главных преимущества (USP):**
1. **Phygital-сканер реальных раскладов** (Quick Scan / Guided / Live Oracle) — огромный сегмент владельцев физических колод почти не охвачен качественными инструментами.
2. **Тактильность + 3 системы + Астрология в спокойной дорогой эстетике** (Dark Obsidian / Forest).
3. **Психологический не-фатальный тон + Zero-Knowledge / Local-First** — сильный фактор доверия в интимной нише.
4. **Встроенный цикл возврата и органики** (check-in 3/7/14 дн. + 9:16 Stories-карточки).

**Слабые стороны на старте:**
1. **Размытое позиционирование «комбайна всего»:** для удержания богатство фич — плюс, но для привлечения холодного трафика нужно бить в 1–2 понятных визуальных крючка (сканер реального расклада + тактильная 3D-физика).
2. **Тяжёлый холодный старт Flutter Web (`build/web` = 89 МБ):** `main.dart.js` 6.6 МБ + CanvasKit WASM + 36 МБ колод + 4.1 МБ фонов. Без оптимизации и HTML-сплэша половина мобильного 4G-трафика отвалится до первого кадра.

### 1.3. Найденные в коде блокеры PWA-запуска
1. **[P0 — Безопасность] Утечка AI-ключей из клиентского JS:** `OracleSynthesisService` (`lib/core/services/oracle_synthesis_service.dart`) и `CloudTranscriptionService` (`lib/core/services/voice/cloud_transcription_service.dart`) вызывают LLM/STT напрямую с клиента через `String.fromEnvironment`, минуя готовый Django `/api/v1/oracle/`. В PWA эти ключи открыто лежат в `main.dart.js`.
2. **[P0 — Экономика] Клиентские квоты и PRO в `localStorage`:** `DailyQuotaController` (`lib/state/daily_quota_controller.dart`) и `is_pro_unlocked` (`lib/core/services/local_storage_service.dart`) проверяются только на клиенте и обходятся через DevTools; щедрые бесплатные лимиты могут сжечь бюджет токенов при всплеске трафика.
3. **[P0 — UX в PWA] Вкладка «Камера» показывает `MOCK MODE` на Web:** в `lib/features/camera_scan/camera_scan_screen.dart` стоит `_mobileCameraAvailable => !kIsWeb && ...`, из-за чего на мобильном браузере центральная кнопка затвора запускает фейковый `_scan(null)` вместо съёмки/загрузки реального фото.
4. **[P0 — VLM-конфиг] Проверить боевые ключи/квоты DeepSeek `deepseek-flash` (DeepSeek-V4.1-Flash):** `deepseek-flash` на `api.deepseek.com` поддерживает `image_url` нативно — убедиться, что на сервере задан рабочий `VISION_VLM_API_KEY` и прогнать реальные фото раскладов через `enginetaro` кроппер + VLM.
5. **[P0 — PWA-инфраструктура]:**
   - `build/web/flutter_service_worker.js` самоудаляется (`self.registration.unregister()`) → офлайн-режим в PWA фактически не работает.
   - `web/index.html` не имеет HTML/SVG-прелоадера → 4–8 сек пустого тёмного экрана на 4G.
   - `assets/images/forest.png` и `oak.png` весят ~4.1 МБ и предзагружаются на старте (`MainNavigationShell`).
   - Нет баннера установки на рабочий стол (`beforeinstallprompt` + инструкция для iOS Safari).
   - `flutter_local_notifications` на Web — no-op → напоминания check-in (3/7/14 дн.) и утренних/лунных ритуалов в PWA не приходят.
6. **[P1 — Витрина и дистрибуция]:**
   - Проверить поведение `share_plus` на десктопных и мобильных браузерах (добавить fallback-скачивание PNG).
   - Сверить обещания на `promo-tarottree` (про «шифрование на устройстве», «три личности Оракула», «полный офлайн») с фактическим кодом.
   - Оплата только через Solana отсекает ~95%+ целевой аудитории Таро/астрологии (позже добавить Merchant of Record + Telegram Stars/карты).
   - Домен `.cyou` со временем заменить на `.app` / `.com` (доставляемость писем и доверие при оплате).

### 1.4. Стратегия дистрибуции с $0 на сторы
- **PWA + Web-to-Web воронка:** мгновенный вход по ссылке из TikTok / Reels / Pinterest / Reddit без сторов и комиссий 30%.
- **Telegram Mini App (TMA) + Бот:** обёртка поверх той же PWA за 0 ₽ → решает проблему пушей (напоминания о check-in и карте дня), даёт вирусное распространение и оплаты (Telegram Stars / Tribute).
- **Бесплатные Android-сторы + прямой APK:** RuStore, Huawei AppGallery, Samsung Galaxy Store, Amazon Appstore.
- **Google Play ($25 один раз навсегда):** окупается с первых 5 подписчиков Early Supporter ($4.99/мес).
- **Бесплатная органика:** 10–15 коротких видео (сканер реального расклада + 3D-физика колоды/рун), ежедневные 9:16 карточки в Pinterest/Telegram, комьюнити (`r/SecularTarot`, `r/tarot`, Habr/VC.ru, Product Hunt), programmatic SEO на `promo-tarottree` из уже готовых датасетов.

---

## 2. Сводка фаз закрытия блокеров (Roadmap)

| Фаза | Приоритет | Задача | Статус | Гейт верификации |
| --- | --- | --- | --- | --- |
| **Фаза A** | `P0` | Проксирование Oracle AI и STT через Django + серверные квоты и защита PRO | `[x] DONE` | 0 API-ключей в `build/web/main.dart.js`, 42/42 Django + 4/4 proxy-тестов Flutter зелёные |
| **Фаза B** | `P0` | Web-камера в PWA (убрать `MOCK MODE`) + проверка VLM-конвейера (`deepseek-flash`) | `[x] DONE` | Web photo-capture UI без `MOCK MODE`, `pwa_readiness_test` + `camera_modes_and_vision_test` зелёные |
| **Фаза C** | `P0` | Скорость и полноценная PWA: HTML-сплэш, WebP-фоны, кастомный `sw.js`, A2HS-баннер | `[x] DONE` | `flutter build web --release` зелёный, фоны 3.7 МБ → 168 КБ, `sw.js` + A2HS готовы |
| **Фаза D** | `P1` | Полировка Web-шеринга, честность текстов `promo-tarottree`, прод-деплой и CORS | `[x] DONE` | Fallback-скачивание PNG на Web, 10 словарей promo синхронизированы, `.env.example` актуализирован |
| **Фаза E** | `P1` | Telegram Mini App (TMA) + бот напоминаний (замена Web Push для check-in и Луны) | `[x] DONE` | TMA-мост + deep links, Django `apps.telegram_bot` + `send_telegram_reminders`, 46/46 Django-тестов зелёные |
| **Фаза F** | `P2` | Бесплатная дистрибуция ($0): альтернативные сторы, Programmatic SEO, запуск органики | `[ ] TODO` | APK опубликован в ≥2 бесплатных сторах, SEO-страницы проиндексированы, вышло ≥10 роликов |
| **Фаза G** | `P2` | Массовая платёжка (карты/MoR + Stars), переход на `.app`/`.com`, выход в Google Play ($25) | `[ ] TODO` | Успешная тестовая оплата картой → автоактивация PRO без ручного tx hash |

---

## 3. Пошаговый план работ

### Фаза A (`P0`) — Безопасность ключей и серверная экономика ИИ `[x] DONE`
> **Цель:** исключить утечку любых AI/STT-ключей из публичного PWA-бандла и защитить бюджет токенов на сервере.

- [x] **A.1 — Серверный эндпоинт для единого Oracle-клиента (Django):**
  - Добавлен `POST /api/v1/oracle/complete/` (`backend/apps/oracle/proxy_service.py`, `api.py`, `urls.py`): приоритет #1 — `ai_gateway`, приоритет #2 — env `ORACLE_LLM_URL` / `ORACLE_LLM_API_KEY` / `ORACLE_LLM_MODEL`.
- [x] **A.2 — Серверный эндпоинт для голосового STT (Django):**
  - Добавлен `POST /api/v1/oracle/transcribe/` (multipart, лимит 5 МБ в `http.py` + view, zero disk retention, поддержка Whisper / Gemini native / OpenAI `input_audio`).
- [x] **A.3 — Серверные квоты Free vs PRO (Django):**
  - Добавлены `consume_quota` / `quota_peek` в `backend/apps/core/api.py`, эндпоинт `GET /api/v1/oracle/quota/` и лимиты `ORACLE_FREE_DAILY_LIMIT` (15) vs `ORACLE_PRO_DAILY_LIMIT` (300), `STT_FREE_DAILY_LIMIT` (25) vs `STT_PRO_DAILY_LIMIT` (300) с ответом `429 quota_exceeded` + `remaining` + `resetAt`.
- [x] **A.4 — Переключить Flutter-сервисы на Django API:**
  - `OracleSynthesisService` и `CloudTranscriptionService` получили приоритетный путь #0 через Django (`registerBackendAuth` в `lib/main.dart`), прямые ключи отключены на `kIsWeb` (включая `VisionScannerService`).
  - `TableWorkspace` перехватывает `OracleQuotaExceededException` (HTTP 429) и открывает `ProSubscriptionSheet`.
- [x] **A.5 — Верификация Фазы A:**
  - 42/42 Django-тестов (включая новый `backend/tests/test_oracle_proxy_and_stt.py`), `makemigrations --check`, `spectacular --validate --fail-on-warn`, `flutter analyze` = 0, `test/oracle_backend_proxy_test.dart` зелёный, 0 API-ключей в `build/web/main.dart.js`.

---

### Фаза B (`P0`) — Рабочая камера в PWA и проверка VLM-конвейера `[x] DONE`
> **Цель:** превратить главную киллер-фичу (сканирование реальных раскладов) из сломанного «MOCK MODE» в работающий сценарий прямо в мобильном браузере.

- [x] **B.1 — Переделать Web-сценарий вкладки «Камера» (`lib/features/camera_scan/camera_scan_screen.dart`):**
  - На `kIsWeb` вместо чёрного `_SimulatedViewfinder` («MOCK MODE») отображается `_WebPhotoCaptureStage` с кнопками «Сфотографировать» (`ImageSource.camera`, `CameraDevice.rear`) и «Выбрать из галереи» (`ImageSource.gallery`).
  - Центральная кнопка затвора `_ShutterButton` на Web вызывает `_captureWithWebCamera()` вместо фейкового `_scan(null)`.
  - Добавлены переводы на 6 языков (`l10n/*.tsv`, 2 768 ключей).
- [x] **B.2 — Проверить VLM-конвейер (`deepseek-flash` / OpenAI-compatible):**
  - `deepseek-flash` (DeepSeek-V4.1-Flash, нативный `image_url`) оставлен валидным серверным дефолтом; на `kIsWeb` клиент не использует `VISION_API_KEY` и ходит через `/api/v1/vision/scan-spread/`.
  - *Заметка к прод-деплою:* после поднятия сервера прогнать 5–10 реальных фото раскладов с телефона на боевом `VISION_VLM_API_KEY`.
- [x] **B.3 — Верификация Фазы B:**
  - `test/pwa_readiness_test.dart`, `test/camera_modes_and_vision_test.dart`, `test/camera_lifecycle_test.dart` зелёные.

---

### Фаза C (`P0`) — Ускорение и доведение PWA до уровня нативного приложения `[x] DONE`
> **Цель:** убрать «пустой экран» на холодном старте, уменьшить трафик первого визита, вернуть офлайн-кэш и повысить возвращаемость через установку на рабочий стол.

- [x] **C.1 — Мгновенный HTML/SVG-прелоадер в `web/index.html`:**
  - Встроен лёгкий HTML/CSS-сплэш `#tarot-html-splash` в палитре Tarot Tree (`#0C101B` + лавандовое свечение + логотип), плавно исчезающий по `flutter-first-frame`.
- [x] **C.2 — Оптимизация ассетов и сборки Web:**
  - `assets/images/forest.png` (1.7 МБ → **76 КБ** `.webp`) и `oak.png` (2.0 МБ → **92 КБ** `.webp`), обновлены пути в `TaroBackgroundAssets` (`section_backgrounds_test.dart` зелёный).
  - Проверен `--wasm` dry-run: наш код на 100% Wasm-совместим; Wasm-флаг пока блокируют 2 сторонних плагина (`flutter_tts 4.2.5`, `flutter_timezone 4.1.1`) — сборка остаётся на стабильном CanvasKit JS до их обновления.
- [x] **C.3 — Кастомный лёгкий Service Worker (`web/sw.js`):**
  - Network-First для App Shell, ленивый Cache-First для CanvasKit/шрифтов/колод (36 МБ колод НЕ предзагружаются на старте), строго Network-Only для `/api/*`, зарегистрирован в `web/index.html`.
- [x] **C.4 — Мягкий баннер установки PWA на экран (A2HS):**
  - В `web/index.html` перехвачен `beforeinstallprompt` + детектор iOS Safari и `standalone`; создан платформенный мост `lib/core/services/pwa_install_service*.dart` и виджет `PwaInstallBanner`, встроенный в `MainNavigationShell` (показывается на Web только после 1-го завершённого расклада).
- [x] **C.5 — Верификация Фазы C:**
  - `flutter build web --release` собран чисто (`build/web/sw.js`, `build/web/index.html`, WebP-фоны); `test/pwa_readiness_test.dart` и `test/l10n_coverage_test.dart` зелёные.
  - *После деплоя:* прогнать Lighthouse на боевом `app.soshallitbe.cyou` и настроить gzip/brotli + `Cache-Control` на Nginx/Cloudflare.

---

### Фаза D (`P1`) — Полировка Web-шеринга, честность витрины и прод-деплой `[x] DONE`
> **Цель:** убрать шероховатости, которые подрывают доверие нового пользователя на вебе.

- [x] **D.1 — Fallback-скачивание 9:16 карточки на Web (`lib/core/services/share_card_service.dart`):**
  - Добавлен платформенный хелпер `lib/core/services/web_file_download*.dart` (Blob + `<a download="tarot_tree_story.png">`).
  - `SharePlusAdapter` на Web сначала вызывает нативный Web Share API; если браузер/WebView возвращает `unavailable` или отклоняет `navigator.share({ files })`, автоматически скачивает PNG и `ShareCardPreviewSheet` показывает снэкбар `share.downloaded` (добавлен в 6 языков, 2 769 ключей).
- [x] **D.2 — Ревизия текстов промо-сайта (`promo-tarottree`):**
  - Выровнены формулировки в словарях (`en/ru/uk/es/pt/de`): честное local-first хранение на устройстве и психологический ИИ-Оракул без фатализма; проверена целостность всех 10 JSON-словарей (388 ключей).
  - В `promo-tarottree/package.json` имя пакета обновлено с `promo-depress` на `promo-tarottree`.
- [x] **D.3 — Продакшен-чек деплоя Django + PWA + Promo:**
  - Актуализирован `backend/.env.example` со всеми боевыми переменными (CORS, CSRF, SMTP, `VISION_VLM_*`, `ORACLE_LLM_*`, `STT_*`, лимиты Free/PRO, `TELEGRAM_*`, Solana).
  - *После выкладки на VPS:* выполнить `manage.py migrate`, `manage.py check --deploy`, проверить `/api/v1/health/`.

---

### Фаза E (`P1`) — Telegram Mini App (TMA) + бот напоминаний `[x] DONE`
> **Цель:** получить бесплатный канал виральной дистрибуции в Telegram и полностью закрыть проблему отсутствия Web Push в PWA.

- [x] **E.1 — Адаптация PWA под Telegram WebApp:**
  - В `web/index.html` добавлена асинхронная (неблокирующая оффлайн-PWA) загрузка `telegram-web-app.js` и мост `window.__tarotTma` (`ready()`, `expand()`, цвета шапки `#0C101B`, `initData`, `startParam`).
  - Создан платформенный сервис `lib/core/services/telegram_webapp_service*.dart` + маппинг диплинков `tabIndexForStartParam` (`camera`/`table`/`almanac`/`astral`/`daily`/`lunar`/`checkin`).
  - `MainNavigationShell` вызывает `initialize()`, открывает нужную вкладку по `startapp` и скрывает A2HS-баннер внутри Telegram.
- [x] **E.2 — Лёгкий Django-бот напоминаний (`backend/apps/telegram_bot/`):**
  - Модели `TelegramSubscriber` и `TelegramCheckInReminder` (`migrations/0001_initial.py`), админка и 0 новых pip-зависимостей.
  - `POST /api/v1/telegram/webhook/` (защищён `X-Telegram-Bot-Api-Secret-Token`): команды `/start`, `/daily`, `/lunar`, `/checkin [3|7|14] [тема]`, `/stop` с локализацией RU/EN и inline-кнопкой запуска Mini App.
  - `POST /api/v1/telegram/checkin/`: планирование check-in напрямую из Mini App с официальной HMAC-SHA256 проверкой `initData`.
  - Cron-команда `python manage.py send_telegram_reminders`: идемпотентная рассылка due check-in (3/7/14 дн.), «Карты дня» и окон Новолуния/Полнолуния (±18 ч).
- [x] **E.3 — Верификация Фазы E:**
  - 46/46 Django-тестов (включая `backend/tests/test_telegram_bot.py`), `spectacular --validate --fail-on-warn`, `flutter analyze` = 0, 14/14 P1 Flutter-тестов (`pwa_readiness_test`, `share_card_test`, `l10n_coverage_test`, `section_backgrounds_test`) и релизный `flutter build web --release`.
  - *После деплоя:* создать бота у `@BotFather`, прописать `TELEGRAM_BOT_TOKEN` + `TELEGRAM_WEBHOOK_SECRET`, зарегистрировать webhook `https://<api>/api/v1/telegram/webhook/` и поставить cron на `manage.py send_telegram_reminders` каждые 15–30 минут.

---

### Фаза F (`P2`) — Бесплатная дистрибуция ($0) и первые 500 пользователей
> **Цель:** проверить реальный спрос, собрать фидбек и получить первые оплаты без рекламного бюджета.

- [ ] **F.1 — Бесплатные Android-сторы и 3 биллинг-сборки (`BILLING_MODE`):**
  - 3 релизные APK-сборки из единой кодовой базы (`lib/core/config/app_build_config.dart`):
    1. **Прямой сайт APK (`BILLING_MODE=web`, по умолчанию):** `flutter build apk --release`
    2. **RuStore / нулевой биллинг (Reader App, без цен и внешних ссылок):** `flutter build apk --release --dart-define=BILLING_MODE=reader`
    3. **Samsung Galaxy Store / Huawei AppGallery (Store IAP через `StoreIapService`):** `flutter build apk --release --dart-define=BILLING_MODE=store_iap`
  - Выложить подписанный release APK / AAB в: **RuStore**, **Huawei AppGallery**, **Samsung Galaxy Store**, **Amazon Appstore**.
  - Обновить прямую ссылку на актуальный APK на `promo-tarottree`.
- [ ] **F.2 — Programmatic SEO на `promo-tarottree` (бесплатный поисковый трафик):**
  - Сгенерировать статические SEO-страницы (Next.js SSG) из уже существующих датасетов:
    - 78 страниц карт Таро (прямая / перевёрнутая / любовь / работа / стихия + кнопка «Вытянуть расклад с ИИ бесплатно»).
    - 36 страниц Ленорман и 24 страницы Рун Старшего Футарка.
    - Страницы сочетаний из `assets/data/tarot_pair_drills.json`.
  - Обновить `sitemap.ts` и `robots.ts`, добавить микроразметку (JSON-LD `FAQPage` / `SoftwareApplication`) для Google, Яндекса и ИИ-поисковиков.
- [ ] **F.3 — Контент-запуск (10–15 коротких роликов, 3 формата):**
  - *Формат 1 (Phygital-вау):* реальный расклад на столе → фото в PWA → распознавание + разбор Оракула + уточняющая карта.
  - *Формат 2 (ASMR / тактильность):* запись экрана 3D-тасовки колоды и раскатывания рунных камней в темноте.
  - *Формат 3 (Органика из `ShareCardCanvas`):* ежедневная «Карта дня» и расклады на Новолуние/Полнолуние в Pinterest и Telegram-канале.
- [ ] **F.4 — Точечные запуски в комьюнити:**
  - Пост в `r/SecularTarot` и `r/tarot` (акцент: психологический не-фатальный подход, сканер реальных карт, Zero-Knowledge, бесплатно в браузере).
  - Техническая статья-бэкстейдж на Habr / VC.ru («Как я в одиночку написал ИИ-сканер карт Таро с OpenCV, офлайн-эфемеридами Swiss Ephemeris и 3D-физикой на Flutter»).
  - Бесплатный запуск на Product Hunt (после закрытия Фаз A–D).

---

### Фаза G (`P2`) — Массовые оплаты, чистый домен и Google Play
> **Цель:** убрать барьер крипто-оплаты для 95% аудитории и выйти в Google Play с первых продаж.

- [ ] **G.1 — Массовая платёжка (рядом с Solana):**
  - Для глобального рынка: подключить Merchant of Record (**Paddle / Lemon Squeezy / Creem** — $0 на старт, сами закрывают VAT/налоги, карты + Apple Pay / Google Pay прямо в вебе) через существующий адаптерный слой `backend/apps/payments/providers.py`.
  - Для СНГ / Telegram: **Telegram Stars** и/или **Tribute / ЮKassa / Lava.top**.
  - Сохранить оффер **Early Supporter ($4.99/мес или $39.99/год для первых 100)**.
- [ ] **G.2 — Реинвестиция первых доходов:**
  - Первые $10–12 → покупка домена `.app` / `.com` (вместо `.cyou`), настройка SPF/DKIM/DMARC для писем с чеками и редиректов со старого домена.
  - Первые $25 → регистрация аккаунта **Google Play** (единоразово навсегда) и публикация нативного Android-приложения.

---

## 4. Журнал прогресса (новый спринт)
- **2026-11-26 (Аудит):** Проведён полный аудит кода (Flutter, Django, `enginetaro`, `promo-tarottree`, `build/web`), конкурентов и PWA-стратегии; сформирован пошаговый план закрытия всех блокеров (Фазы A–G).
- **2026-11-26 (P0 — Фазы A, B, C):** Закрыты все три P0-фазы:
  - *Фаза A:* Django-прокси `POST /api/v1/oracle/complete/`, `POST /api/v1/oracle/transcribe/`, `GET /api/v1/oracle/quota/` + серверные квоты Free/PRO (`429 quota_exceeded`); Flutter `OracleSynthesisService`, `CloudTranscriptionService` и `VisionScannerService` переведены на серверный прокси без ключей на Web.
  - *Фаза B:* Web/PWA-вкладка «Камера» переведена с `MOCK MODE` на нативный захват фото / выбор из галереи (`_WebPhotoCaptureStage` + `_captureWithWebCamera`); `deepseek-flash` подтверждён и оставлен дефолтом.
  - *Фаза C:* Встроен мгновенный HTML-сплэш в `web/index.html`, пережаты фоны (`forest.webp` 76 КБ, `oak.webp` 92 КБ — экономия 3.5 МБ), добавлен кастомный `web/sw.js` (Network-First shell + ленивый Cache-First ассетов + Network-Only `/api/`) и мягкий A2HS-баннер `PwaInstallBanner` после первого расклада.
  - *Верификация:* 42/42 Django tests + `makemigrations --check` + `spectacular --validate`; `flutter analyze` = 0; 44/44 целевых P0-тестов Flutter; релизный `flutter build web --release` собран чисто, 0 ключей в `main.dart.js`.
- **2026-11-26 (P1 — Фазы D, E):** Полностью закрыты обе P1-фазы:
  - *Фаза D:* Fallback-скачивание 9:16 PNG-карточки на десктопных браузерах и WebView (`web_file_download*.dart`, `SharePlusAdapter`, снэкбар `share.downloaded` на 6 языках); выровнены тексты `promo-tarottree` (local-first без завышенных обещаний, переименован `package.json`); обновлён `backend/.env.example`.
  - *Фаза E:* Интегрирован неблокирующий мост Telegram Mini App (`web/index.html`, `telegram_webapp_service*.dart`, диплинки `startapp` в `MainNavigationShell`, скрытие A2HS внутри Telegram) и создан Django-модуль `apps.telegram_bot` (webhook + команды `/start`, `/daily`, `/lunar`, `/checkin`, `/stop` + HMAC-SHA256 эндпоинт `/api/v1/telegram/checkin/` + cron-рассылка `manage.py send_telegram_reminders`).
  - *Верификация:* 46/46 Django tests + `spectacular --validate`; все 10 словарей `promo-tarottree` валидны (388 ключей); `flutter analyze` = 0; 14/14 P1 Flutter-тестов зелёные; релизный `flutter build web --release` собран чисто.
- **2026-11-26 (Продакшен-деплой на `BIA` и единый DeepSeek):**
  - Единый серверный `DEEPSEEK_API_KEY` теперь обслуживает Vision (`deepseek-flash`), Oracle LLM (`deepseek-chat`) и Voice ASR (`/v1/tools/asr` + `ffmpeg` в памяти для `.m4a`); 47/47 Django tests зелёные.
  - Раскатаны на `BIA`: `backend/` + миграция `telegram_bot.0001_initial`, свежий `build/web/` в `/opt/tarottree/web-app/`, тюнинг Nginx (`gzip` + `wasm`, `sw.js no-cache`, кэш `/assets/` и `/canvaskit/`), пересобран `promo-tarottree`.
  - Живые боевые проверки: `/api/v1/health/` = 200, `/api/v1/oracle/complete/` (`env:deepseek-chat`, квота 1/15) = 200, `/api/v1/vision/scan-spread/` (`deepseek-flash`, `crops`, `The Star` 0.99) = 200, `main.dart.js` gzip 2.1 МБ, `forest.webp` 75 КБ.
  - Актуализирована вся проектная документация (`README.md`, `ARCHITECTURE.md`, `PRIVACY.md`, `backend/API.md`, `backend/BACKEND_ARCHITECTURE.md`, `PLAN.md`).

---

## 5. Архив завершённого спринта (Фазы 0–7, 2026-11-24)

| Фаза | Задача | Статус |
| --- | --- | --- |
| **Фаза 0** | Пересоздание `PLAN.md` и синхронизация с `TASK_STATE.json` | `[x] DONE` |
| **Фаза 1** | Круглая иконка Tarot Tree (`tool/gen_app_icons.py`, Android/iOS/Web) | `[x] DONE` |
| **Фаза 2** | Очистка чата Оракула + авторская иконка `SeerEyeIcon` | `[x] DONE` |
| **Фаза 3** | Автоматическое и динамическое автосохранение раскладов без ИИ | `[x] DONE` |
| **Фаза 4 ★** | 3-кнопочный футер стола + виральный 9:16 шеринг (`ShareCardCanvas`) | `[x] DONE` |
| **Фаза 5** | Эффект Зейгарник («Проверка сбываемости» через 3 / 7 / 14 дней) | `[x] DONE` |
| **Фаза 6** | Лунные ритуалы + «Карта дня» за 30 сек + стрики | `[x] DONE` |
| **Фаза 7** | Микро-обучение за 2 минуты (Таро / Ленорман / Руны, 0 API) + облачный мультиязычный голосовой ввод | `[x] DONE` |
