import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/services/oracle_voice_service.dart';
import '../../../core/theme/app_typography.dart';
import '../../../design_system/taro.dart';
import '../../../state/voice_input_controller.dart';
import 'voice_mic_button.dart';

/// The shared Gemini-style floating input capsule docked directly above
/// the bottom navigation dock — ONE component used by the Digital Table
/// (Pane 0) and the Oracle AI Chat (Pane 1).
///
/// Visual: rounded dark obsidian pill (`radius 28`, hairline border) with
/// `+` on the left, an expandable text field in the middle, and the live
/// amplitude mic + circular accent send (`↑`) on the right.
class GeminiInputCapsule extends StatefulWidget {
  const GeminiInputCapsule({
    super.key,
    required this.onSend,
    required this.onPlus,
    this.hint,
    this.sendKey,
    this.fieldKey,
    this.controller,
    this.focusNode,
  });

  final ValueChanged<String> onSend;
  final VoidCallback onPlus;

  /// Optional override; when null the shared dictionary hint is used.
  final String? hint;
  final Key? sendKey;
  final Key? fieldKey;

  /// Optional EXTERNAL controller (the workspace owns it so the clarifier
  /// chip can read the typed question). When null the capsule manages its
  /// own controller.
  final TextEditingController? controller;

  /// Optional external focus node — lets the chat pane pull keyboard
  /// focus to the input bar programmatically.
  final FocusNode? focusNode;

  @override
  State<GeminiInputCapsule> createState() => _GeminiInputCapsuleState();
}

class _GeminiInputCapsuleState extends State<GeminiInputCapsule>
    with WidgetsBindingObserver {
  late final TextEditingController _text =
      widget.controller ?? TextEditingController();
  VoiceInputController? _providedVoice;
  VoiceInputController? _ownedVoice;

  VoiceInputController _resolveVoice(BuildContext context) {
    final provided = context.read<VoiceInputController?>();
    if (provided != null) {
      _providedVoice = provided;
      return provided;
    }
    return _ownedVoice ??= VoiceInputController();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _providedVoice = context.read<VoiceInputController?>();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final voice = _providedVoice ?? _ownedVoice;
    if (voice != null && voice.isOwnedBy(this)) {
      unawaited(voice.cancel(owner: this));
    }
    unawaited(_ownedVoice?.cancel());
    _ownedVoice?.dispose();
    if (widget.controller == null) _text.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Backgrounding the app must silence the live mic IMMEDIATELY — the OS
    // mic indicator goes dark; the typed text is preserved, nothing re-listens.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      final voice = _providedVoice ?? _ownedVoice;
      if (voice != null && voice.isOwnedBy(this)) {
        unawaited(voice.cancel(owner: this));
      }
    }
  }

  void _submit() {
    final text = _text.text.trim();
    if (text.isEmpty) return;
    HapticFeedback.selectionClick();
    widget.onSend(text);
    _text.clear();
  }

  Future<void> _toggleMic() async {
    final voice = _resolveVoice(context);
    if (voice.isRecordingFor(this)) {
      final result = await voice.stopAndTranscribe(owner: this);
      if (!mounted) return;
      if (result.isSuccess) {
        insertVoiceTranscript(_text, result.text!);
      } else {
        showVoiceInputFeedback(context, result);
      }
      return;
    }

    // Half-duplex: silence TTS before opening the mic.
    unawaited(context.read<OracleVoiceService?>()?.stop());
    final early = await voice.startRecording(
      owner: this,
      onAutoStop: () => unawaited(_toggleMic()),
    );
    if (!mounted || early == null) return;
    showVoiceInputFeedback(context, early);
  }

  @override
  Widget build(BuildContext context) {
    final voice = context.watch<VoiceInputController?>() ??
        (_ownedVoice ??= VoiceInputController());
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      child: TaroGlassSurface(
        radius: TaroRadii.pill,
        fillColor: TaroColors.surface,
        borderColor: TaroColors.mist.withValues(alpha: TaroOpacity.borderStrong),
        glow: TaroGlow.soft(
          TaroColors.lavender,
          alpha: 0.18,
          blur: 20,
          offset: const Offset(0, 6),
        ),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Row(
            children: [
              _CapsuleIconButton(
                icon: Icons.add,
                tooltip: AppStrings.g('ui.gemini_input_capsule.add_context'),
                onTap: () {
                  HapticFeedback.selectionClick();
                  widget.onPlus();
                },
              ),
              const SizedBox(width: 6),
              Expanded(
                child: TextField(
                  key: widget.fieldKey,
                  controller: _text,
                  focusNode: widget.focusNode,
                  minLines: 1,
                  maxLines: 3,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _submit(),
                  cursorColor: TaroColors.lavender,
                  style: AppTypography.chatUser(
                    fontSize: 15,
                    height: 1.4,
                    color: TaroColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText:
                        widget.hint ?? AppStrings.g('table.addContextHint'),
                    hintStyle: AppTypography.chatUser(
                      fontSize: 14.5,
                      height: 1.4,
                      color: TaroColors.textSecondary.withValues(
                        alpha: TaroOpacity.textMuted,
                      ),
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              VoiceMicButton(
                key: const ValueKey('capsule-voice-mic'),
                controller: voice,
                owner: this,
                variant: VoiceMicButtonVariant.capsule,
                idleTooltip: AppStrings.g('ui.gemini_input_capsule.voice'),
                onTap: _toggleMic,
              ),
              const SizedBox(width: 6),
              Semantics(
                button: true,
                label: AppStrings.g('ui.gemini_input_capsule.send'),
                child: GestureDetector(
                  key: widget.sendKey,
                  behavior: HitTestBehavior.opaque,
                  onTap: _submit,
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [TaroColors.lavender, TaroColors.indigo],
                      ),
                      boxShadow: TaroGlow.soft(
                        TaroColors.lavender,
                        alpha: 0.35,
                        blur: 10,
                      ),
                    ),
                    child: const Icon(
                      Icons.arrow_upward,
                      size: 18,
                      color: TaroColors.background,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CapsuleIconButton extends StatelessWidget {
  const _CapsuleIconButton({
    required this.icon,
    required this.onTap,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tooltip,
      child: Tooltip(
        message: tooltip ?? '',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: TaroColors.surface.withValues(alpha: 0.72),
              border: Border.all(
                color: TaroColors.mist.withValues(alpha: TaroOpacity.border),
              ),
            ),
            child: Icon(
              icon,
              size: 18,
              color: TaroColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
