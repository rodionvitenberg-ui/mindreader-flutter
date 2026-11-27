import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/services/oracle_voice_service.dart';
import '../../../design_system/taro.dart';
import '../../../state/voice_input_controller.dart';
import 'voice_mic_button.dart';

/// The table and its chat pane can both edit the same draft. Wait for the
/// active editor's cloud transcription before starting the first synthesis.
class ReadingDictation {
  Future<void> Function()? _stop;
  Future<void> finish() async => await _stop?.call();
}

/// Editable spread-question draft powered by language-independent audio capture
/// and cloud transcription with natural punctuation.
class ReadingContextField extends StatefulWidget {
  const ReadingContextField({
    super.key,
    required this.value,
    required this.onChanged,
    required this.language,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final AppLanguage language;

  @override
  State<ReadingContextField> createState() => _ReadingContextFieldState();
}

class _ReadingContextFieldState extends State<ReadingContextField>
    with WidgetsBindingObserver {
  late final _text = TextEditingController(text: widget.value);
  ReadingDictation? _session;
  VoiceInputController? _providedVoice;
  VoiceInputController? _ownedVoice;
  Future<void>? _pendingStop;

  VoiceInputController _resolveVoice(BuildContext context) {
    final provided = context.read<VoiceInputController?>();
    if (provided != null) {
      _providedVoice = provided;
      return provided;
    }
    return _ownedVoice ??= VoiceInputController();
  }

  String _label(String key) => AppStrings.t(widget.language, key);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _session = context.read<ReadingDictation>();
    _providedVoice = context.read<VoiceInputController?>();
  }

  @override
  void didUpdateWidget(ReadingContextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _text.text) {
      _cancelActiveVoice();
      _text.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  void _cancelActiveVoice() {
    if (_session?._stop == _stopAndApply) _session?._stop = null;
    final voice = _providedVoice ?? _ownedVoice;
    if (voice != null && voice.isOwnedBy(this)) {
      unawaited(voice.cancel(owner: this));
    }
  }

  Future<void> _stopAndApply() {
    final inFlight = _pendingStop;
    if (inFlight != null) return inFlight;
    final future = _runStopAndApply();
    _pendingStop = future;
    return future.whenComplete(() {
      if (identical(_pendingStop, future)) _pendingStop = null;
      if (_session?._stop == _stopAndApply) _session?._stop = null;
    });
  }

  Future<void> _runStopAndApply() async {
    final voice = _resolveVoice(context);
    if (!voice.isRecordingFor(this)) return;
    final result = await voice.stopAndTranscribe(owner: this);
    if (!mounted) return;
    if (result.isSuccess) {
      final updated = insertVoiceTranscript(_text, result.text!);
      widget.onChanged(updated);
    } else {
      showVoiceInputFeedback(context, result, language: widget.language);
    }
  }

  Future<void> _toggleDictation() async {
    final voice = _resolveVoice(context);
    if (voice.isRecordingFor(this)) {
      await _stopAndApply();
      return;
    }

    unawaited(context.read<OracleVoiceService?>()?.stop());
    _session?._stop = _stopAndApply;
    final early = await voice.startRecording(
      owner: this,
      onAutoStop: () => unawaited(_stopAndApply()),
    );
    if (!mounted) return;
    if (early != null) {
      if (_session?._stop == _stopAndApply) _session?._stop = null;
      showVoiceInputFeedback(context, early, language: widget.language);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _cancelActiveVoice();
    }
  }

  @override
  void dispose() {
    _cancelActiveVoice();
    unawaited(_ownedVoice?.cancel());
    _ownedVoice?.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final voice = context.watch<VoiceInputController?>() ??
        (_ownedVoice ??= VoiceInputController());
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(TaroRadii.input),
      borderSide: BorderSide(
        color: TaroColors.mist.withValues(alpha: TaroOpacity.border),
      ),
    );
    return TapRegion(
      onTapOutside: (_) {
        if (voice.isRecordingFor(this)) unawaited(_stopAndApply());
      },
      child: TextField(
        key: const ValueKey('reading-context'),
        controller: _text,
        onChanged: (value) {
          if (voice.isRecordingFor(this)) _cancelActiveVoice();
          widget.onChanged(value);
        },
        textInputAction: TextInputAction.done,
        cursorColor: TaroColors.lavender,
        style: const TextStyle(color: TaroColors.textPrimary, fontSize: 13),
        decoration: InputDecoration(
          filled: true,
          fillColor: TaroColors.surface.withValues(alpha: 0.72),
          isDense: true,
          hintText: _label('table.question'),
          hintStyle: const TextStyle(
            color: TaroColors.textSecondary,
            fontSize: 12,
          ),
          border: border,
          enabledBorder: border,
          focusedBorder: border.copyWith(
            borderSide: const BorderSide(color: TaroColors.lavender),
          ),
          contentPadding: const EdgeInsets.symmetric(
            vertical: 8,
            horizontal: 12,
          ),
          suffixIconConstraints: const BoxConstraints(
            minWidth: 44,
            minHeight: 40,
          ),
          suffixIcon: VoiceMicButton(
            key: const ValueKey('reading-context-mic'),
            controller: voice,
            owner: this,
            variant: VoiceMicButtonVariant.inline,
            language: widget.language,
            idleTooltip: _label('table.dictate'),
            recordingTooltip: _label('table.stopDictation'),
            onTap: _toggleDictation,
          ),
        ),
      ),
    );
  }
}
