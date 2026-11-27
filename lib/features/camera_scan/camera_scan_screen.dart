import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/models/divination_card.dart';
import '../../core/models/divination_system.dart';
import '../../core/models/reading_mode.dart';
import '../../core/models/reading_source.dart';
import '../../core/models/reading_status.dart';
import '../../core/services/backend_auth_service.dart';
import '../../core/services/local_storage_service.dart';
import '../../core/services/oracle_synthesis_service.dart';
import '../../core/services/oracle_voice_service.dart';
import '../../core/services/spread_inference_service.dart';
import '../../core/services/vision_scanner_service.dart';
import '../../core/theme/app_typography.dart';
import '../../design_system/taro.dart';
import '../../state/app_settings_controller.dart';
import '../../state/backend_auth_controller.dart';
import '../../state/daily_quota_controller.dart';
import '../../state/guided_session_coordinator.dart';
import '../../state/live_oracle_controller.dart';
import '../../state/live_reading_controller.dart';
import '../../state/oracle_session_controller.dart';
import '../../state/spread_controller.dart';
import '../oracle/widgets/compact_oracle.dart';
import '../shell/widgets/pro_subscription_sheet.dart';
import 'widgets/camera_mode_selector.dart';
import 'widgets/camera_top_hud.dart';
import 'widgets/guided_spread_hud.dart';
import 'widgets/recognition_review_sheet.dart';

/// Pillar 2: phygital pipeline supporting all three camera-driven modes:
/// - **Quick Scan**: batch capture -> `enginetaro` crops + Cloud VLM -> review -> Table.
/// - **Guided Spread**: slot-by-slot ritual via [GuidedSessionCoordinator] + [GuidedSpreadHud].
/// - **Live Oracle**: freeform card laying with [LiveOracleController] + [CompactOracle].
///
/// LAZY CAMERA LIFECYCLE: [CameraController] is initialized ONLY while
/// [isActiveTab] is true and disposed immediately on tab switch or background.
class CameraScanScreen extends StatefulWidget {
  const CameraScanScreen({
    super.key,
    required this.onHandoff,
    this.isActiveTab = true,
    this.webCaptureModeOverride,
  });

  final VoidCallback onHandoff; // shell switches to the Digital Table

  /// False while another shell tab is active: the camera stays OFF.
  final bool isActiveTab;

  /// Optional test seam to preview/verify the Web/PWA photo-capture stage.
  @visibleForTesting
  final bool? webCaptureModeOverride;

  @override
  State<CameraScanScreen> createState() => _CameraScanScreenState();
}

class _CameraScanScreenState extends State<CameraScanScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  CameraController? _camera;
  bool _initError = false;
  bool _flashOn = false;
  bool _busy = false;
  bool _lockOn = false;
  int _detectedCount = 0;

  /// Active physical reading mode (persisted across launches).
  ReadingMode _mode = ReadingMode.quickScan;

  /// Guided Spread pending confirmation state (awaitingConfirmation).
  DetectedCard? _pendingGuidedCard;
  bool _pendingGuidedReversed = false;
  bool _guidedQuotaCharged = false;

  /// Live Oracle freeform state.
  final List<DetectedCard> _liveCards = [];
  bool _liveQuotaCharged = false;

  /// Latest concise Oracle line shown over the viewfinder in Guided / Live modes.
  String? _oracleCaption;

  String _modeInstruction(AppLanguage lang) => switch (_mode) {
        ReadingMode.quickScan => AppStrings.t(lang, 'camera.mode.quickScan'),
        ReadingMode.guidedSpread =>
          AppStrings.t(lang, 'camera.mode.guidedSpread'),
        ReadingMode.liveOracle => AppStrings.t(lang, 'camera.mode.liveOracle'),
        ReadingMode.standard => AppStrings.t(lang, 'camera.mode.quickScan'),
      };

  late final AnimationController _lockOnAnim;

  bool get _mobileCameraAvailable =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lockOnAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _loadCameraMode();
    if (_mobileCameraAvailable && widget.isActiveTab) _initCamera();
  }

  @override
  void didUpdateWidget(covariant CameraScanScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActiveTab == oldWidget.isActiveTab) return;
    if (widget.isActiveTab) {
      if (_camera == null && _mobileCameraAvailable) _initCamera();
    } else {
      _releaseCamera();
    }
  }

  Future<void> _initCamera() async {
    if (_initError && mounted) setState(() => _initError = false);
    try {
      final cameras = await availableCameras();
      if (!mounted || !widget.isActiveTab) return;
      if (cameras.isEmpty) {
        setState(() => _initError = true);
        return;
      }
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        back,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted || !widget.isActiveTab) {
        await controller.dispose();
        return;
      }
      _camera = controller;
      if (mounted) setState(() => _initError = false);
    } catch (_) {
      if (mounted && widget.isActiveTab) setState(() => _initError = true);
    }
  }

  Future<void> _releaseCamera() async {
    final camera = _camera;
    _camera = null;
    if (camera != null) {
      try {
        await camera.dispose();
      } catch (_) {
        // Already disposed.
      }
    }
    if (mounted) {
      setState(() {
        _flashOn = false;
        _busy = false;
        _lockOn = false;
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final camera = _camera;
    _camera = null;
    if (camera != null) unawaited(camera.dispose());
    _lockOnAnim.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      _releaseCamera();
    } else if (state == AppLifecycleState.resumed) {
      if (widget.isActiveTab && _mobileCameraAvailable && _camera == null) {
        _initCamera();
      }
    }
  }

  Future<void> _toggleFlash() async {
    if (_camera == null) return;
    _flashOn = !_flashOn;
    await _camera!.setFlashMode(_flashOn ? FlashMode.torch : FlashMode.off);
    if (mounted) setState(() {});
  }

  /// Resolves the backend scan-spread credentials (guest or verified bearer)
  /// when the Django backend is configured, keeping VLM keys off the client.
  Future<(String?, String?)> _resolveBackendVisionAuth() async {
    final auth = context.read<BackendAuthController?>();
    if (auth == null || !auth.isConfigured) return (null, null);
    final token = await auth.ensureToken();
    if (token == null || token.isEmpty) return (null, null);
    return (BackendAuthService.defaultBackendUrl, token);
  }

  // ---- Mode Session Lifecycle ----

  void _ensureGuidedSessionStarted() {
    final live = context.read<LiveReadingController?>();
    if (live == null) return;
    final ctrl = context.read<SpreadController>();
    final oracle = context.read<OracleSessionController>();
    if (live.phase == GuidePhase.preparing || live.phase.isTerminal) {
      final coord = GuidedSessionCoordinator(live: live, spread: ctrl);
      coord.start();
      live.transitionTo(GuidePhase.awaitingCard);
      oracle.beginSession(
        source: ReadingSource.physical,
        mode: ReadingMode.guidedSpread,
      );
      _pendingGuidedCard = null;
      _pendingGuidedReversed = false;
      _guidedQuotaCharged = false;
      _oracleCaption = null;
    }
  }

  void _ensureLiveOracleSessionStarted() {
    final liveOracle = context.read<LiveOracleController?>();
    if (liveOracle == null) return;
    final oracle = context.read<OracleSessionController>();
    if (!liveOracle.isActive) {
      liveOracle.begin();
      oracle.beginSession(
        source: ReadingSource.physical,
        mode: ReadingMode.liveOracle,
      );
      _liveCards.clear();
      _liveQuotaCharged = false;
      _oracleCaption = null;
    }
  }

  void _exitGuidedSession() {
    final live = context.read<LiveReadingController?>();
    live?.cancel();
    context.read<OracleSessionController>().setStatus(ReadingStatus.idle);
    setState(() {
      _pendingGuidedCard = null;
      _oracleCaption = null;
      _mode = ReadingMode.quickScan;
    });
    LocalStorageService()
        .saveCameraMode(ReadingMode.quickScan)
        .then((_) {}, onError: (Object _) {});
  }

  void _endLiveOracleSession({bool openTable = false}) {
    final liveOracle = context.read<LiveOracleController?>();
    liveOracle?.reset();
    context.read<OracleVoiceService?>()?.stop();
    if (openTable && _liveCards.isNotEmpty) {
      widget.onHandoff();
      return;
    }
    context.read<OracleSessionController>().setStatus(ReadingStatus.idle);
    setState(() {
      _liveCards.clear();
      _oracleCaption = null;
      _liveQuotaCharged = false;
      _mode = ReadingMode.quickScan;
    });
    LocalStorageService()
        .saveCameraMode(ReadingMode.quickScan)
        .then((_) {}, onError: (Object _) {});
  }

  // ---- Scanning Entry Point ----

  Future<void> _scan(Uint8List? bytes) async {
    if (_busy) return;
    final ctrl = context.read<SpreadController>();
    final clarifierScan = ctrl.clarifierScanRequested;
    final isPro = context.read<AppSettingsController?>()?.isProUnlocked ?? false;
    final quota = context.read<DailyQuotaController?>();

    // Check daily quota (only once per Guided / Live session, or per Quick Scan).
    final alreadyChargedForSession =
        (_mode == ReadingMode.guidedSpread && _guidedQuotaCharged) ||
        (_mode == ReadingMode.liveOracle && _liveQuotaCharged);
    if (!clarifierScan &&
        !alreadyChargedForSession &&
        quota != null &&
        !quota.canUseCameraMode(_mode, isPro: isPro)) {
      await ProSubscriptionSheet.show(
        context,
        reason: ProGateReason.cameraQuota,
      );
      return;
    }

    if (ctrl.system != DivinationSystem.tarot) {
      _showManualFallback(ctrl.system);
      return;
    }

    if (!clarifierScan && _mode == ReadingMode.guidedSpread) {
      await _scanGuidedCard(bytes);
      return;
    }
    if (!clarifierScan && _mode == ReadingMode.liveOracle) {
      await _scanLiveOracleCard(bytes);
      return;
    }

    // Default: Quick Scan (or single-card clarifier scan).
    setState(() => _busy = true);
    try {
      final jpeg = bytes == null
          ? Uint8List.fromList(List.generate(256, (i) => i & 0xff))
          : await VisionScannerService().compressJpeg(bytes);
      final (backendUrl, token) = bytes == null
          ? (null, null)
          : await _resolveBackendVisionAuth();
      final cards = await VisionScannerService().detectSpread(
        jpeg: jpeg,
        cardCount: clarifierScan ? 1 : null,
        mode: clarifierScan ? 'guided_single' : 'quick_scan',
        backendBaseUrl: backendUrl,
        bearerToken: token,
      );
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      setState(() {
        _detectedCount = cards.length;
        _lockOn = true;
      });
      await _lockOnAnim.forward(from: 0);
      if (!mounted || cards.isEmpty) return;
      if (clarifierScan) {
        ctrl.completeClarifierScan(cards.first.card, cards.first.isReversed);
        widget.onHandoff();
      } else {
        await _reviewAndHandoff(ctrl, cards, chargeQuota: bytes != null);
      }
    } catch (_) {
      if (mounted) {
        showTaroGlassSnackbar(
          context,
          message: AppStrings.g('ui.camera_scan_screen.scan_failed_try_again'),
          tone: TaroGlassSnackbarTone.error,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Guided Spread: captures ONE physical card for the current slot and enters
  /// `awaitingConfirmation` so the user confirms or flips orientation before binding.
  Future<void> _scanGuidedCard(Uint8List? bytes) async {
    _ensureGuidedSessionStarted();
    final live = context.read<LiveReadingController?>();
    if (live == null) return;
    if (live.phase == GuidePhase.paused) live.resume();
    if (live.phase == GuidePhase.awaitingNextCard) live.advanceToNextSlot();
    if (live.phase != GuidePhase.awaitingCard &&
        live.phase != GuidePhase.awaitingConfirmation) {
      return;
    }
    if (live.phase == GuidePhase.awaitingConfirmation) {
      live.transitionTo(GuidePhase.awaitingCard);
    }

    setState(() {
      _busy = true;
      _pendingGuidedCard = null;
    });
    live.transitionTo(GuidePhase.cardDetected);
    live.transitionTo(GuidePhase.recognizingCard);

    try {
      final jpeg = bytes == null
          ? Uint8List.fromList(List.generate(256, (i) => i & 0xff))
          : await VisionScannerService().compressJpeg(bytes);
      final (backendUrl, token) = bytes == null
          ? (null, null)
          : await _resolveBackendVisionAuth();
      final cards = await VisionScannerService().detectSpread(
        jpeg: jpeg,
        cardCount: 1,
        mode: 'guided_single',
        backendBaseUrl: backendUrl,
        bearerToken: token,
      );
      if (!mounted) return;
      if (cards.isEmpty) {
        live.transitionTo(GuidePhase.awaitingConfirmation);
        live.transitionTo(GuidePhase.awaitingCard);
        showTaroGlassSnackbar(
          context,
          message: AppStrings.g('ui.camera_scan_screen.scan_failed_try_again'),
          tone: TaroGlassSnackbarTone.warning,
        );
        return;
      }
      HapticFeedback.mediumImpact();
      setState(() {
        _detectedCount = 1;
        _lockOn = true;
        _pendingGuidedCard = cards.first;
        _pendingGuidedReversed = cards.first.isReversed;
      });
      await _lockOnAnim.forward(from: 0);
      if (!mounted) return;
      live.transitionTo(GuidePhase.awaitingConfirmation);
      if (bytes != null && !_guidedQuotaCharged) {
        _guidedQuotaCharged = true;
        context.read<DailyQuotaController?>()?.recordCameraMode(
              ReadingMode.guidedSpread,
            );
      }
    } catch (_) {
      if (mounted) {
        live.transitionTo(GuidePhase.awaitingConfirmation);
        live.transitionTo(GuidePhase.awaitingCard);
        showTaroGlassSnackbar(
          context,
          message: AppStrings.g('ui.camera_scan_screen.scan_failed_try_again'),
          tone: TaroGlassSnackbarTone.error,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Handles GuidedSpreadHud primary button: Confirm detected card OR Next slot.
  Future<void> _onGuidedPrimaryAction() async {
    final live = context.read<LiveReadingController?>();
    if (live == null) return;
    final ctrl = context.read<SpreadController>();
    final oracle = context.read<OracleSessionController>();
    final coord = GuidedSessionCoordinator(live: live, spread: ctrl);

    if (live.phase == GuidePhase.awaitingConfirmation &&
        _pendingGuidedCard != null) {
      final picked = _pendingGuidedCard!;
      final reversed = _pendingGuidedReversed;
      final bound = coord.confirmCard(
        TarotDivinationCard(picked.card),
        reversed: reversed,
      );
      if (!bound) return;
      setState(() {
        _pendingGuidedCard = null;
        _busy = true;
      });
      try {
        final cmd = await OracleSynthesisService().interpretFreeform(
          intention: ctrl.spreadLabel,
          slots: ctrl.slots,
          system: ctrl.system,
          history: oracle.messages,
        );
        if (!mounted) return;
        oracle.addOracleMessage(cmd.text);
        if (live.oracleShouldSpeak) {
          context.read<OracleVoiceService?>()?.speak(cmd.text);
        }
        setState(() => _oracleCaption = cmd.text);
        live.transitionTo(GuidePhase.awaitingNextCard);
      } finally {
        if (mounted) setState(() => _busy = false);
      }
      return;
    }

    if (live.phase == GuidePhase.awaitingNextCard) {
      final hasMore = coord.nextCard();
      setState(() => _oracleCaption = null);
      if (!hasMore && coord.isComplete) {
        live.complete();
        widget.onHandoff();
      }
    }
  }

  /// Live Oracle: captures 1 newly laid card, appends it non-destructively to
  /// the live spread, and streams the Oracle's response into [OracleSessionController].
  Future<void> _scanLiveOracleCard(Uint8List? bytes) async {
    _ensureLiveOracleSessionStarted();
    final ctrl = context.read<SpreadController>();
    final liveOracle = context.read<LiveOracleController?>();
    final oracle = context.read<OracleSessionController>();

    setState(() => _busy = true);
    try {
      final jpeg = bytes == null
          ? Uint8List.fromList(List.generate(256, (i) => i & 0xff))
          : await VisionScannerService().compressJpeg(bytes);
      final (backendUrl, token) = bytes == null
          ? (null, null)
          : await _resolveBackendVisionAuth();
      final cards = await VisionScannerService().detectSpread(
        jpeg: jpeg,
        cardCount: 1,
        mode: 'live_oracle',
        backendBaseUrl: backendUrl,
        bearerToken: token,
      );
      if (!mounted || cards.isEmpty) return;

      HapticFeedback.mediumImpact();
      final added = cards.first;
      setState(() {
        _detectedCount = 1;
        _lockOn = true;
        _liveCards.add(added);
      });
      await _lockOnAnim.forward(from: 0);
      if (!mounted) return;

      if (bytes != null && !_liveQuotaCharged) {
        _liveQuotaCharged = true;
        context.read<DailyQuotaController?>()?.recordCameraMode(
              ReadingMode.liveOracle,
            );
      }

      ctrl.loadScannedSpread(
        system: DivinationSystem.tarot,
        cards: [for (final c in _liveCards) TarotDivinationCard(c.card)],
        reversed: [for (final c in _liveCards) c.isReversed],
      );

      final cmd = await OracleSynthesisService().interpretFreeform(
        intention: liveOracle?.intention ?? '',
        slots: ctrl.slots,
        system: ctrl.system,
        history: oracle.messages,
      );
      if (!mounted) return;
      liveOracle?.recordAction(cmd.action);
      oracle.addOracleMessage(cmd.text);
      context.read<OracleVoiceService?>()?.speak(cmd.text);
      setState(() => _oracleCaption = cmd.text);
    } catch (_) {
      if (mounted) {
        showTaroGlassSnackbar(
          context,
          message: AppStrings.g('ui.camera_scan_screen.scan_failed_try_again'),
          tone: TaroGlassSnackbarTone.error,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Shows Recognition Review, places confirmed spread on the table, and hands off.
  Future<void> _reviewAndHandoff(
    SpreadController ctrl,
    List<DetectedCard> detected, {
    required bool chargeQuota,
  }) async {
    final cards = [for (final d in detected) TarotDivinationCard(d.card)];
    final reversed = [for (final d in detected) d.isReversed];
    final inference = const SpreadInferenceService().infer(
      SpreadInferenceInput(
        system: DivinationSystem.tarot,
        detectedCount: cards.length,
      ),
    );
    final result = await RecognitionReviewSheet.show(
      context,
      cards: cards,
      reversed: reversed,
      inference: inference,
    );
    if (!mounted || result == null) return;
    if (chargeQuota) {
      context.read<DailyQuotaController?>()?.recordCameraMode(_mode);
    }
    final spread = result.spread;
    ctrl.loadScannedSpread(
      system: DivinationSystem.tarot,
      cards: result.cards,
      reversed: result.reversed,
      spreadType: spread?.tarot,
      lenormandSpread: spread?.lenormand,
      runeCast: spread?.rune,
    );
    widget.onHandoff();
  }

  void _showManualFallback(DivinationSystem system) {
    showTaroGlassSnackbar(
      context,
      message: AppStrings.g('camera.manualFallback', {
        'system': system.label,
      }),
      tone: TaroGlassSnackbarTone.warning,
    );
  }

  Future<void> _capture() async {
    if (_camera == null || !_camera!.value.isInitialized) return;
    final shot = await _camera!.takePicture();
    await _scan(await shot.readAsBytes());
  }

  Future<void> _captureWithWebCamera() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.rear,
      imageQuality: 90,
      maxWidth: 1600,
    );
    if (picked == null) return;
    await _scan(await picked.readAsBytes());
  }

  Future<void> _pickFromGallery() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    await _scan(await picked.readAsBytes());
  }

  Future<void> _loadCameraMode() async {
    try {
      final stored = await LocalStorageService().loadCameraMode();
      if (!mounted || stored == null || stored == ReadingMode.standard) {
        return;
      }
      setState(() => _mode = stored);
      if (stored == ReadingMode.guidedSpread) {
        _ensureGuidedSessionStarted();
      } else if (stored == ReadingMode.liveOracle) {
        _ensureLiveOracleSessionStarted();
      }
    } catch (_) {
      // Keep QUICK SCAN default.
    }
  }

  Future<void> _onModeSelected(ReadingMode next) async {
    if (next == _mode) return;
    final oracle = context.read<OracleSessionController>();
    final sessionActive = oracle.readingStatus == ReadingStatus.active &&
        (oracle.readingMode == ReadingMode.guidedSpread ||
            oracle.readingMode == ReadingMode.liveOracle);
    if (sessionActive) {
      final confirmed = await _confirmModeSwitch();
      if (!confirmed || !mounted) return;
    }
    if (_mode == ReadingMode.guidedSpread) {
      context.read<LiveReadingController?>()?.cancel();
    } else if (_mode == ReadingMode.liveOracle) {
      context.read<LiveOracleController?>()?.reset();
    }
    setState(() {
      _mode = next;
      _pendingGuidedCard = null;
      _oracleCaption = null;
    });
    if (next == ReadingMode.guidedSpread) {
      _ensureGuidedSessionStarted();
    } else if (next == ReadingMode.liveOracle) {
      _ensureLiveOracleSessionStarted();
    }
    LocalStorageService()
        .saveCameraMode(next)
        .then((_) {}, onError: (Object _) {});
  }

  Future<bool> _confirmModeSwitch() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const ValueKey('camera-mode-confirm'),
        backgroundColor: TaroColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TaroRadii.panel),
          side: BorderSide(
            color: TaroColors.mist.withValues(alpha: TaroOpacity.borderStrong),
          ),
        ),
        title: Text(
          AppStrings.g('ui.camera_scan_screen.switch_reading_mode'),
          style: AppTypography.heading(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: TaroColors.textPrimary,
          ),
        ),
        content: Text(
          AppStrings.g('camera.modeSwitchWarning'),
          style: AppTypography.body(
            fontSize: 13.5,
            color: TaroColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppStrings.g('common.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppStrings.g('common.switch')),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<SpreadController>();
    final lang =
        context.watch<AppSettingsController?>()?.language ?? AppStrings.current;
    final isPro = context.watch<AppSettingsController?>()?.isProUnlocked ?? false;
    final quota = context.watch<DailyQuotaController?>();
    final live = context.watch<LiveReadingController?>();
    final voice = context.watch<OracleVoiceService?>();
    final remaining = quota?.remainingToday(_mode);
    final limit = quota?.limitFor(_mode);

    final webCaptureMode = widget.webCaptureModeOverride ?? kIsWeb;
    final cameraReady =
        !webCaptureMode &&
        _camera != null &&
        _camera!.value.isInitialized &&
        !_initError;
    final cameraLoading =
        !webCaptureMode &&
        widget.isActiveTab &&
        _mobileCameraAvailable &&
        !cameraReady &&
        !_initError;
    final simulated = !webCaptureMode && (!_mobileCameraAvailable || _initError);

    final isGuided =
        !ctrl.clarifierScanRequested &&
        _mode == ReadingMode.guidedSpread &&
        live != null;
    final isLive =
        !ctrl.clarifierScanRequested && _mode == ReadingMode.liveOracle;

    final filledGuidedCount = isGuided
        ? ctrl.slots
            .take(live.slotCount)
            .where((s) => s.card != null)
            .length
        : 0;
    final currentRole = isGuided &&
            live.currentSlotIndex < ctrl.slots.length
        ? ctrl.slots[live.currentSlotIndex].role
        : '';

    return ColoredBox(
      key: const ValueKey('camera-black-backdrop'),
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (_mobileCameraAvailable && cameraReady)
            CameraPreview(_camera!)
          else if (webCaptureMode)
            _WebPhotoCaptureStage(
              lang: lang,
              busy: _busy,
              onTakePhoto: _captureWithWebCamera,
              onPickGallery: _pickFromGallery,
            )
          else if (cameraLoading)
            const Center(
              child: CircularProgressIndicator(
                key: ValueKey('camera-loading-indicator'),
                color: Colors.white70,
                strokeWidth: 2.5,
              ),
            )
          else if (simulated)
            const _SimulatedViewfinder(),
          const _HudContrastScrim(),
          SafeArea(
            child: Column(
              children: [
                TaroGlassLayer(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: CameraTopHud(
                          system: ctrl.system,
                          onSystemChanged: (s) {
                            HapticFeedback.selectionClick();
                            context.read<SpreadController>().setSystem(s);
                          },
                          flashOn: _flashOn,
                          onToggleFlash: _toggleFlash,
                          onPickGallery: _pickFromGallery,
                          showActions: _mobileCameraAvailable || kIsWeb,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: CameraModeSelector(
                          value: _mode,
                          onChanged: _onModeSelected,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: TaroColors.hudScrim,
                    borderRadius: BorderRadius.circular(TaroRadii.pill),
                    border: Border.all(
                      color: ctrl.clarifierScanRequested
                          ? TaroColors.lavender.withValues(
                              alpha: TaroOpacity.borderStrong,
                            )
                          : TaroColors.hudBorder,
                    ),
                  ),
                  child: Text(
                    ctrl.clarifierScanRequested
                        ? AppStrings.g('camera.photographNext')
                        : _modeInstruction(lang),
                    style: AppTypography.label(
                      fontSize: 9.5,
                      letterSpacing: 1.2,
                      color: ctrl.clarifierScanRequested
                          ? TaroColors.lavender
                          : TaroColors.textPrimary,
                    ),
                  ),
                ),
                if (!isPro &&
                    remaining != null &&
                    limit != null &&
                    !ctrl.clarifierScanRequested) ...[
                  const SizedBox(height: 8),
                  Container(
                    key: const ValueKey('camera-quota-pill'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: TaroColors.hudScrim,
                      borderRadius: BorderRadius.circular(TaroRadii.pill),
                      border: Border.all(
                        color: remaining == 0
                            ? TaroColors.dawn.withValues(alpha: 0.65)
                            : TaroColors.hudBorder,
                      ),
                    ),
                    child: Text(
                      AppStrings.g('camera.quota.remaining', {
                        'remaining': '$remaining',
                        'limit': '$limit',
                      }),
                      style: AppTypography.label(
                        fontSize: 8.5,
                        letterSpacing: 0.9,
                        color: remaining == 0
                            ? TaroColors.dawn
                            : TaroColors.textSecondary,
                      ),
                    ),
                  ),
                ],
                if (isLive && voice != null) ...[
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: CompactOracle(
                        key: const ValueKey('live-compact-oracle'),
                        voice: voice,
                        onExpand: widget.onHandoff,
                        onEnd: () => _endLiveOracleSession(openTable: false),
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                if (_oracleCaption != null && (isGuided || isLive))
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: TaroGlassPanel(
                      key: const ValueKey('camera-oracle-caption'),
                      radius: 16,
                      tint: TaroColors.hudScrim,
                      fillColor: TaroColors.hudFill,
                      borderColor: TaroColors.lavender.withValues(alpha: 0.45),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      child: Text(
                        _oracleCaption!,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.body(
                          fontSize: 12.5,
                          height: 1.4,
                          color: TaroColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                if (isGuided && _pendingGuidedCard != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: TaroGlassPanel(
                      key: const ValueKey('guided-pending-card'),
                      radius: 16,
                      tint: TaroColors.hudScrim,
                      fillColor: TaroColors.hudFill,
                      borderColor: TaroColors.lavender.withValues(alpha: 0.7),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.style_outlined,
                            size: 18,
                            color: TaroColors.lavender,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _pendingGuidedCard!.card.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.heading(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: TaroColors.textPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            key: const ValueKey('guided-flip-orientation'),
                            onTap: () => setState(
                              () => _pendingGuidedReversed =
                                  !_pendingGuidedReversed,
                            ),
                            child: TaroGlassPill(
                              label: _pendingGuidedReversed
                                  ? AppStrings.t(lang, 'card.reversed')
                                  : AppStrings.t(lang, 'card.upright'),
                              accent: _pendingGuidedReversed,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (isLive && _liveCards.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: TaroGlassPanel(
                      key: const ValueKey('live-cards-strip'),
                      radius: 16,
                      tint: TaroColors.hudScrim,
                      fillColor: TaroColors.hudFill,
                      borderColor: TaroColors.hudBorder,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  for (var i = 0; i < _liveCards.length; i++)
                                    Padding(
                                      padding: const EdgeInsets.only(right: 6),
                                      child: TaroGlassPill(
                                        label:
                                            '#${i + 1} ${_liveCards[i].card.name}${_liveCards[i].isReversed ? ' ↓' : ''}',
                                        accent: i == _liveCards.length - 1,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          TaroGlassIconButton(
                            key: const ValueKey('live-open-table'),
                            icon: Icons.chat_bubble_outline,
                            tooltip: AppStrings.g(
                              'ui.guided_spread_hud.open_full_chat',
                            ),
                            size: 38,
                            iconSize: 16,
                            onPressed: () =>
                                _endLiveOracleSession(openTable: true),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (simulated && !isGuided)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: TaroColors.hudScrim,
                        borderRadius: BorderRadius.circular(TaroRadii.pill),
                        border: Border.all(color: TaroColors.hudBorder),
                      ),
                      child: Text(
                        AppStrings.g(
                          'ui.camera_scan_screen.simulated_viewfinder_u00b7_tap_to_run_the_mock_s',
                        ),
                        style: AppTypography.label(
                          fontSize: 9,
                          letterSpacing: 0.9,
                          color: TaroColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                Padding(
                  padding: EdgeInsets.only(bottom: isGuided ? 12 : 28),
                  child: _busy
                      ? TaroGlassProgress(
                          linear: false,
                          size: 32,
                          semanticLabel: AppStrings.g(
                            'ui.camera_scan_screen.scanning_spread',
                          ),
                        )
                      : _ShutterButton(
                          key: const ValueKey('shutter'),
                          onTap: cameraReady
                              ? _capture
                              : webCaptureMode
                                  ? _captureWithWebCamera
                                  : () => _scan(null),
                        ),
                ),
                if (isGuided)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: GuidedSpreadHud(
                      key: const ValueKey('guided-spread-hud'),
                      spreadName: ctrl.spreadLabel,
                      filledCount: filledGuidedCount,
                      totalSlots: live.slotCount,
                      currentSlotRole: currentRole,
                      phase: live.phase,
                      flashOn: _flashOn,
                      onToggleFlash: _toggleFlash,
                      onPause: live.pause,
                      onExit: _exitGuidedSession,
                      onConfirm: _onGuidedPrimaryAction,
                      onResume: live.resume,
                      onOpenChat: widget.onHandoff,
                    ),
                  ),
              ],
            ),
          ),
          if (_lockOn)
            IgnorePointer(
              child: AnimatedBuilder(
                animation: _lockOnAnim,
                builder: (context, _) => CustomPaint(
                  size: Size.infinite,
                  painter: _LockOnPainter(
                    count: _detectedCount,
                    t: _lockOnAnim.value,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _HudContrastScrim extends StatelessWidget {
  const _HudContrastScrim();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Column(
        children: [
          Container(
            height: 196,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.68),
                  Colors.black.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
          const Spacer(),
          Container(
            height: 184,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.72),
                  Colors.black.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WebPhotoCaptureStage extends StatelessWidget {
  const _WebPhotoCaptureStage({
    required this.lang,
    required this.busy,
    required this.onTakePhoto,
    required this.onPickGallery,
  });

  final AppLanguage lang;
  final bool busy;
  final VoidCallback onTakePhoto;
  final VoidCallback onPickGallery;

  @override
  Widget build(BuildContext context) {
    return Stack(
      key: const ValueKey('camera-web-capture-stage'),
      fit: StackFit.expand,
      children: [
        const TaroDuskBackground(),
        Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 150, 24, 130),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: TaroGlassPanel(
                radius: 24,
                padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            TaroColors.lavender.withValues(alpha: 0.28),
                            TaroColors.lavender.withValues(alpha: 0.04),
                          ],
                        ),
                        border: Border.all(
                          color: TaroColors.lavender.withValues(alpha: 0.45),
                        ),
                      ),
                      child: const Icon(
                        Icons.center_focus_strong_outlined,
                        size: 30,
                        color: TaroColors.lavender,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      AppStrings.t(lang, 'camera.web.title'),
                      textAlign: TextAlign.center,
                      style: AppTypography.heading(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: TaroColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      AppStrings.t(lang, 'camera.web.subtitle'),
                      textAlign: TextAlign.center,
                      style: AppTypography.body(
                        fontSize: 12.5,
                        height: 1.45,
                        color: TaroColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 18),
                    TaroGlassButton(
                      key: const ValueKey('camera-web-take-photo'),
                      icon: Icons.camera_alt_outlined,
                      label: AppStrings.t(lang, 'camera.web.takePhoto'),
                      onPressed: busy ? null : onTakePhoto,
                    ),
                    const SizedBox(height: 10),
                    TaroGlassButton(
                      key: const ValueKey('camera-web-choose-gallery'),
                      icon: Icons.photo_library_outlined,
                      variant: TaroGlassButtonVariant.secondary,
                      label: AppStrings.t(lang, 'camera.web.chooseGallery'),
                      onPressed: busy ? null : onPickGallery,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SimulatedViewfinder extends StatelessWidget {
  const _SimulatedViewfinder();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.center_focus_strong_outlined,
              size: 44,
              color: TaroColors.mist,
            ),
            const SizedBox(height: 12),
            Text(
              AppStrings.g('ui.camera_scan_screen.camera_unavailable_mock_mode'),
              textAlign: TextAlign.center,
              style: AppTypography.label(
                fontSize: 10,
                letterSpacing: 1.1,
                height: 1.8,
                color: TaroColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShutterButton extends StatelessWidget {
  const _ShutterButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: AppStrings.g('ui.camera_scan_screen.capture_spread'),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: 76,
          height: 76,
          child: TaroGlassLayer(
            child: TaroGlassSurface(
              radius: 38,
              tint: TaroColors.lavender.withValues(alpha: 0.22),
              fillColor: TaroColors.hudFill,
              borderColor: TaroColors.lavender,
              glow: TaroGlow.soft(TaroColors.lavender, alpha: 0.35, blur: 22),
              child: Center(
                child: Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: TaroColors.lavender.withValues(alpha: 0.34),
                    border: Border.all(
                      color: TaroColors.textPrimary.withValues(alpha: 0.45),
                      width: 1.2,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LockOnPainter extends CustomPainter {
  _LockOnPainter({required this.count, required this.t});

  final int count;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final cols = count.clamp(1, 3);
    final rows = (count / 3).ceil();
    final rectW = size.width * 0.22;
    final rectH = rectW * 1.65;
    for (var i = 0; i < count; i++) {
      final col = i % cols;
      final row = i ~/ cols;
      final cx = size.width / 2 + (col - (cols - 1) / 2) * (rectW + 14);
      final cy = size.height * 0.40 + (row - (rows - 1) / 2) * (rectH + 18);
      final appear = (t * 1.8 - i * 0.12).clamp(0.0, 1.0);
      final fade = (t * 1.5 - i * 0.1).clamp(0.0, 1.0);
      if (fade <= 0) continue;
      final rect = Rect.fromCenter(
        center: Offset(cx, cy),
        width: rectW * (0.7 + 0.3 * appear),
        height: rectH * (0.7 + 0.3 * appear),
      );
      final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(10));
      canvas.drawRRect(
        rrect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..color = TaroColors.lavender.withValues(alpha: fade)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
      canvas.drawRRect(
        rrect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = TaroColors.lavender.withValues(alpha: 0.9 * fade),
      );
    }
  }

  @override
  bool shouldRepaint(_LockOnPainter old) => old.t != t || old.count != count;
}
