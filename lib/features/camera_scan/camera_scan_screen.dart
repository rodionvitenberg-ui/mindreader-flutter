import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/models/divination_card.dart';
import '../../core/models/divination_system.dart';
import '../../core/models/reading_mode.dart';
import '../../core/models/reading_status.dart';
import '../../core/services/local_storage_service.dart';
import '../../core/services/spread_inference_service.dart';
import '../../core/services/vision_scanner_service.dart';
import '../../core/theme/app_colors.dart';
import '../../state/oracle_session_controller.dart';
import '../../state/spread_controller.dart';
import 'widgets/camera_mode_selector.dart';
import 'widgets/camera_top_hud.dart';
import 'widgets/recognition_review_sheet.dart';

/// Pillar 2: phygital pipeline. Native camera on Android/iOS with a
/// simulated viewfinder + mock scan on desktop/emulator, dynamic lavender
/// lock-on frames, then a seamless handoff to the Digital Table with every
/// detected card already FACE UP.
///
/// LAZY CAMERA LIFECYCLE: the [CameraController] is initialized ONLY while
/// [isActiveTab] is true (the CAMERA tab is open) and is disposed the
/// instant the user switches away — the green OS privacy indicator must
/// never stay on while the TABLE or ALMANAC tab is visible.
class CameraScanScreen extends StatefulWidget {
  const CameraScanScreen({
    super.key,
    required this.onHandoff,
    this.isActiveTab = true,
  });

  final VoidCallback onHandoff; // shell switches to the Digital Table

  /// False while another shell tab is active: the camera stays OFF.
  final bool isActiveTab;

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

  /// The active physical reading mode (persisted across launches).
  ReadingMode _mode = ReadingMode.quickScan;

  /// Contextual viewfinder instruction per physical mode. Only the three
  /// camera-driven modes are addressed; `standard` never reaches the Camera.
  static const _modeInstructions = <ReadingMode, String>{
    ReadingMode.quickScan: 'POINT AT YOUR SPREAD ON THE TABLE',
    ReadingMode.guidedSpread: 'ALIGN EACH CARD TO A GUIDED SLOT',
    ReadingMode.liveOracle: 'HOLD A CARD FOR THE LIVE ORACLE',
  };

  String get _modeInstruction =>
      _modeInstructions[_mode] ?? 'POINT AT YOUR SPREAD ON THE TABLE';

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
    // The camera opens ONLY when this tab is actually active.
    if (_mobileCameraAvailable && widget.isActiveTab) _initCamera();
  }

  @override
  void didUpdateWidget(covariant CameraScanScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActiveTab == oldWidget.isActiveTab) return;
    if (widget.isActiveTab) {
      if (_camera == null && _mobileCameraAvailable) _initCamera();
    } else {
      // Leaving the CAMERA tab kills the hardware camera IMMEDIATELY —
      // the green OS privacy indicator goes dark right away.
      _releaseCamera();
    }
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      // The user may have left the tab while the hardware was opening.
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
        // Tab left mid-initialization: drop the hardware immediately.
        await controller.dispose();
        return;
      }
      _camera = controller;
      if (mounted) setState(() => _initError = false);
    } catch (_) {
      if (mounted && widget.isActiveTab) setState(() => _initError = true);
    }
  }

  /// Disposes the hardware camera and resets all capture UI state. Safe to
  /// call repeatedly — an already-disposed controller is ignored.
  Future<void> _releaseCamera() async {
    final camera = _camera;
    _camera = null;
    if (camera != null) {
      try {
        await camera.dispose();
      } catch (_) {
        // Already disposed — nothing to release.
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
    // Backgrounding the app releases the camera exactly like leaving the tab
    // (green privacy indicator goes dark); resuming re-acquires it ONLY while
    // the CAMERA tab is still active — never while another tab is on top.
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

  /// Compress, detect, lock-on animation, then the Recognition Review and a
  /// face-up handoff to the Table. [bytes] == null runs the deterministic
  /// mock scan (desktop). When the table armed a single-card clarifier scan,
  /// only ONE card is detected and appended as Card N+1.
  ///
  /// The vision recognizer is TAROT-only: for LENORMAND/RUNES we NEVER convert
  /// a tarot result into another system — an honest manual fallback is shown.
  Future<void> _scan(Uint8List? bytes) async {
    if (_busy) return;
    final ctrl = context.read<SpreadController>();
    final clarifierScan = ctrl.clarifierScanRequested;
    setState(() => _busy = true);
    try {
      // Amendment 4: no tarot→lenormand/runes conversion (main scan AND the
      // single-card clarifier both photograph a physical TAROT deck).
      if (ctrl.system != DivinationSystem.tarot) {
        _showManualFallback(ctrl.system);
        return;
      }
      final jpeg = bytes == null
          ? Uint8List.fromList(List.generate(256, (i) => i & 0xff))
          : await VisionScannerService().compressJpeg(bytes);
      final count = clarifierScan ? 1 : ctrl.spreadType.cardCount;
      final cards = await VisionScannerService().detectSpread(
        jpeg: jpeg,
        cardCount: count,
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
        await _reviewAndHandoff(ctrl, cards);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Scan failed, try again')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Shows the Recognition Review, then places the confirmed spread on the
  /// table and hands off to the Digital Table (Face-up, Focus/Spread ready).
  Future<void> _reviewAndHandoff(
    SpreadController ctrl,
    List<DetectedCard> detected,
  ) async {
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${system.label} physical scan needs manual card entry — '
          'the camera recognizer reads TAROT only.',
        ),
      ),
    );
  }

  Future<void> _capture() async {
    if (_camera == null || !_camera!.value.isInitialized) return;
    final shot = await _camera!.takePicture();
    await _scan(await shot.readAsBytes());
  }

  Future<void> _pickFromGallery() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    await _scan(await picked.readAsBytes());
  }

  /// Restores the persisted reading mode (QUICK SCAN is the default).
  /// `standard` is the digital-table reading and never a camera mode.
  Future<void> _loadCameraMode() async {
    try {
      final stored = await LocalStorageService().loadCameraMode();
      if (!mounted || stored == null || stored == ReadingMode.standard) {
        return;
      }
      setState(() => _mode = stored);
    } catch (_) {
      // Storage unavailable — keep the QUICK SCAN default.
    }
  }

  /// Switches the reading mode. A live guided/live session must be
  /// confirmed first so the reader does not accidentally abandon it.
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
    setState(() => _mode = next);
    LocalStorageService()
        .saveCameraMode(next)
        .then((_) {}, onError: (Object _) {});
  }

  Future<bool> _confirmModeSwitch() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const ValueKey('camera-mode-confirm'),
        backgroundColor: AppColors.surface,
        title: const Text('Switch reading mode?'),
        content: const Text(
          'A guided reading is in progress. Switching modes leaves the '
          'current session.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('SWITCH'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<SpreadController>();
    final cameraReady =
        _camera != null && _camera!.value.isInitialized && !_initError;
    final simulated = !_mobileCameraAvailable || _initError;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (_mobileCameraAvailable && cameraReady)
          CameraPreview(_camera!)
        else
          const _SimulatedViewfinder(),
        SafeArea(
          child: Column(
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
                  showActions: _mobileCameraAvailable,
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
              const SizedBox(height: 14),
              Text(
                ctrl.clarifierScanRequested
                    ? 'PHOTOGRAPH YOUR NEXT PHYSICAL CARD'
                    : _modeInstruction,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 9.5,
                  letterSpacing: 2.2,
                  color: ctrl.clarifierScanRequested
                      ? AppColors.lavender
                      : AppColors.textMuted,
                ),
              ),
              const Spacer(),
              if (simulated)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Text(
                    'SIMULATED VIEWFINDER \u00b7 TAP TO RUN THE MOCK SCAN',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 8.5,
                      letterSpacing: 1.6,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(bottom: 28),
                child: _busy
                    ? const SizedBox(
                        width: 26,
                        height: 26,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.lavender,
                        ),
                      )
                    : _ShutterButton(
                        key: const ValueKey('shutter'),
                        onTap: cameraReady ? _capture : () => _scan(null),
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
    );
  }
}

class _SimulatedViewfinder extends StatelessWidget {
  const _SimulatedViewfinder();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF12121C), AppColors.canvas],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.center_focus_strong_outlined,
              size: 44,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: 12),
            Text(
              'CAMERA UNAVAILABLE\nMOCK MODE',
              textAlign: TextAlign.center,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 10,
                letterSpacing: 2,
                height: 1.8,
                color: AppColors.textMuted,
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 76,
        height: 76,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.lavender, width: 2.5),
        ),
        child: Center(
          child: Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.lavender.withValues(alpha: 0.35),
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
          ..color = AppColors.lavender.withValues(alpha: fade)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
      canvas.drawRRect(
        rrect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = AppColors.lavender.withValues(alpha: 0.9 * fade),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LockOnPainter oldDelegate) =>
      oldDelegate.t != t || oldDelegate.count != count;
}
