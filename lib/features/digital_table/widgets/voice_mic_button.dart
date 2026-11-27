import 'package:flutter/material.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../design_system/taro.dart';
import '../../../state/voice_input_controller.dart';

/// Visual presentation style of [VoiceMicButton].
enum VoiceMicButtonVariant {
  /// 38x38 circular obsidian pill inside [GeminiInputCapsule].
  capsule,

  /// Compact icon button inside form fields (context, card note, custom spread,
  /// reflection journal).
  inline,
}

/// Reusable microphone trigger that drives live amplitude pulse visualization
/// while recording and a compact spinner while the cloud AI transcribes.
class VoiceMicButton extends StatelessWidget {
  const VoiceMicButton({
    super.key,
    required this.controller,
    required this.owner,
    required this.onTap,
    this.variant = VoiceMicButtonVariant.inline,
    this.language,
    this.idleTooltip,
    this.recordingTooltip,
  });

  final VoiceInputController controller;
  final Object owner;
  final VoidCallback onTap;
  final VoiceMicButtonVariant variant;
  final AppLanguage? language;
  final String? idleTooltip;
  final String? recordingTooltip;

  @override
  Widget build(BuildContext context) {
    final lang = language ?? AppStrings.current;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final recording = controller.isRecordingFor(owner);
        final transcribing = controller.isTranscribingFor(owner);
        final level = recording ? controller.amplitudeLevel : 0.0;
        final tooltip = transcribing
            ? AppStrings.t(lang, 'voice.transcribing')
            : recording
            ? (recordingTooltip ?? AppStrings.t(lang, 'voice.stopRecording'))
            : (idleTooltip ?? AppStrings.t(lang, 'voice.tapToSpeak'));

        final Widget inner;
        if (transcribing) {
          inner = const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(TaroColors.lavender),
            ),
          );
        } else if (recording) {
          inner = _LiveAmplitudeGlyph(level: level);
        } else {
          inner = Icon(
            Icons.mic_none,
            size: variant == VoiceMicButtonVariant.capsule ? 18 : 19,
            color: variant == VoiceMicButtonVariant.capsule
                ? TaroColors.textSecondary
                : TaroColors.lavender,
          );
        }

        if (variant == VoiceMicButtonVariant.capsule) {
          return Semantics(
            button: true,
            label: tooltip,
            child: Tooltip(
              message: tooltip,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: transcribing ? null : onTap,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 90),
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: recording
                        ? TaroColors.rose.withValues(alpha: 0.16 + level * 0.18)
                        : TaroColors.surface.withValues(alpha: 0.72),
                    border: Border.all(
                      color: recording
                          ? TaroColors.rose.withValues(alpha: 0.75)
                          : TaroColors.mist.withValues(alpha: TaroOpacity.border),
                    ),
                    boxShadow: recording
                        ? [
                            BoxShadow(
                              color: TaroColors.rose.withValues(
                                alpha: 0.25 + level * 0.35,
                              ),
                              blurRadius: 8 + level * 12,
                              spreadRadius: level * 2.5,
                            ),
                          ]
                        : null,
                  ),
                  child: inner,
                ),
              ),
            ),
          );
        }

        return Tooltip(
          message: tooltip,
          child: Semantics(
            button: true,
            label: tooltip,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: transcribing ? null : onTap,
              child: SizedBox(
                width: 40,
                height: 40,
                child: Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 90),
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: recording
                        ? BoxDecoration(
                            shape: BoxShape.circle,
                            color: TaroColors.rose.withValues(
                              alpha: 0.16 + level * 0.20,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: TaroColors.rose.withValues(
                                  alpha: 0.22 + level * 0.32,
                                ),
                                blurRadius: 6 + level * 10,
                              ),
                            ],
                          )
                        : null,
                    child: inner,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Live 3-bar equalizer driven by real microphone amplitude (`0.0..1.0`).
class _LiveAmplitudeGlyph extends StatelessWidget {
  const _LiveAmplitudeGlyph({required this.level});

  final double level;

  @override
  Widget build(BuildContext context) {
    final sideH = (6.0 + level * 8.0).clamp(5.0, 15.0);
    final midH = (9.0 + level * 11.0).clamp(8.0, 20.0);
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _bar(sideH),
        const SizedBox(width: 2.5),
        _bar(midH),
        const SizedBox(width: 2.5),
        _bar(sideH * 0.9),
      ],
    );
  }

  Widget _bar(double height) => AnimatedContainer(
    duration: const Duration(milliseconds: 70),
    width: 3,
    height: height,
    decoration: BoxDecoration(
      color: TaroColors.rose,
      borderRadius: BorderRadius.circular(2),
    ),
  );
}

/// Shows clean localized snackbar feedback for non-success voice outcomes
/// (permission denied, accidental short tap, silence, network/API failure).
void showVoiceInputFeedback(
  BuildContext context,
  VoiceInputResult result, {
  AppLanguage? language,
}) {
  if (result.isSuccess || result.kind == VoiceInputOutcomeKind.cancelled) {
    return;
  }
  final lang = language ?? AppStrings.current;
  final key = switch (result.kind) {
    VoiceInputOutcomeKind.permissionDenied => 'voice.permissionDenied',
    VoiceInputOutcomeKind.tooShort => 'voice.tooShort',
    VoiceInputOutcomeKind.tooQuiet ||
    VoiceInputOutcomeKind.emptyTranscript => 'voice.tooQuiet',
    VoiceInputOutcomeKind.notConfigured => 'voice.notConfigured',
    VoiceInputOutcomeKind.networkError => 'voice.networkError',
    VoiceInputOutcomeKind.transcribed ||
    VoiceInputOutcomeKind.cancelled => null,
  };
  if (key == null) return;
  ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(AppStrings.t(lang, key))));
}
