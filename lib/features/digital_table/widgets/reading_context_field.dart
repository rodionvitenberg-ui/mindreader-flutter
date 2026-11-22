import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../design_system/taro.dart';

/// The table and its chat pane can both edit the same draft. Wait for the
/// active editor's final speech result before starting the first synthesis.
class ReadingDictation {
  Future<void> Function()? _stop;
  Future<void> finish() async => await _stop?.call();
}

/// One editable draft. Each partial dictation result replaces the same
/// selection in the original text, so partial words are never duplicated.
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
  final _speech = SpeechToText();
  int _request = 0;
  bool _dictating = false;
  SpeechStatusListener? _previousStatus;
  SpeechErrorListener? _previousError;
  SpeechStatusListener? _status;
  late final _session = context.read<ReadingDictation>();
  Completer<void>? _done;
  bool _stopping = false;

  String _label(String key) => AppStrings.t(widget.language, key);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didUpdateWidget(ReadingContextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _text.text) {
      _cancel();
      _text.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  bool _current(int request) => mounted && _dictating && request == _request;

  // The speech plugin is shared with chat and card notes. Return its
  // listeners to their owner when this dictation ends.
  void _release() {
    if (_status != null && identical(_speech.statusListener, _status)) {
      _speech.statusListener = _previousStatus;
      _speech.errorListener = _previousError;
    }
    _status = null;
    if (_session._stop == _stopWithFinalResult) _session._stop = null;
    _done?.complete();
    _done = null;
    _stopping = false;
    _dictating = false;
    _request++;
  }

  void _cancel() {
    if (!_dictating) return;
    final ownsMic =
        _status != null && identical(_speech.statusListener, _status);
    _release();
    if (ownsMic) unawaited(_speech.cancel().catchError((Object _) {}));
  }

  void _finish({bool unavailable = false}) {
    setState(_release);
    if (unavailable) {
      ScaffoldMessenger.maybeOf(context)
          ?.showSnackBar(SnackBar(content: Text(_label('table.noDictation'))));
    }
  }

  Future<void> _stopWithFinalResult() async {
    final done = _done;
    if (done == null) return;
    if (_status == null) {
      // Permission is still being requested. Recording has not started.
      setState(_cancel);
      return;
    }
    final request = _request;
    if (!_stopping) {
      _stopping = true;
      try {
        await _speech.stop();
      } catch (_) {
        if (_current(request)) _finish(unavailable: true);
      }
    }
    // Some recognizers send no final event after silence or disconnection.
    // Keep the last visible transcript in that case.
    await done.future.timeout(
      SpeechToText.defaultFinalTimeout + const Duration(milliseconds: 300),
      onTimeout: () {
        if (_current(request)) _finish();
      },
    );
  }

  Future<void> _toggleDictation() async {
    if (_dictating) {
      await _stopWithFinalResult();
      return;
    }
    final request = ++_request;
    final base = _text.value;
    final selection = base.selection.isValid
        ? base.selection
        : TextSelection.collapsed(offset: base.text.length);
    _done = Completer<void>();
    _session._stop = _stopWithFinalResult;
    setState(() => _dictating = true);
    try {
      if (_speech.isListening || !await _speech.initialize()) {
        if (_current(request)) _finish(unavailable: true);
        return;
      }
      if (!_current(request)) return;
      _previousStatus = _speech.statusListener;
      _previousError = _speech.errorListener;
      _status = (status) {
        if (_current(request) && status == SpeechToText.doneStatus) _finish();
      };
      _speech.statusListener = _status;
      _speech.errorListener = (_) {
        if (_current(request)) _finish(unavailable: true);
      };
      await _speech.listen(
        listenOptions: SpeechListenOptions(
          listenMode: ListenMode.dictation,
          cancelOnError: true,
          localeId: widget.language == AppLanguage.ru ? AppStrings.g('ui.reading_context_field.ru_ru') : AppStrings.g('ui.reading_context_field.en_us'),
        ),
        onResult: (result) {
          if (!_current(request)) return;
          final words = result.recognizedWords.trim();
          if (words.isNotEmpty) {
            final before = base.text.substring(0, selection.start);
            final after = base.text.substring(selection.end);
            final prefix = before.isEmpty || before.trimRight() != before
                ? before
                : '$before ';
            final suffix = after.isEmpty || after.trimLeft() != after
                ? after
                : ' $after';
            final text = '$prefix$words$suffix';
            _text.value = TextEditingValue(
              text: text,
              selection: TextSelection.collapsed(
                offset: prefix.length + words.length,
              ),
            );
            widget.onChanged(text);
          }
          if (result.finalResult) _finish();
        },
      );
    } catch (_) {
      if (_current(request)) _finish(unavailable: true);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_dictating &&
        (state == AppLifecycleState.paused ||
            state == AppLifecycleState.detached)) {
      setState(_cancel);
    }
  }

  @override
  void dispose() {
    _cancel();
    WidgetsBinding.instance.removeObserver(this);
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final micLabel = _label(
      _dictating ? 'table.stopDictation' : 'table.dictate',
    );
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(TaroRadii.input),
      borderSide: BorderSide(
        color: TaroColors.mist.withValues(alpha: TaroOpacity.border),
      ),
    );
    return TapRegion(
      onTapOutside: (_) {
        if (_dictating) unawaited(_stopWithFinalResult());
      },
      child: TextField(
        key: const ValueKey('reading-context'),
        controller: _text,
        onChanged: (value) {
          if (_dictating) setState(_cancel);
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
          suffixIcon: IconButton(
            tooltip: micLabel,
            visualDensity: VisualDensity.compact,
            onPressed: _toggleDictation,
            icon: Icon(
              _dictating ? Icons.stop_circle_outlined : Icons.mic_none,
              size: 19,
              color: _dictating ? TaroColors.rose : TaroColors.lavender,
            ),
          ),
        ),
      ),
    );
  }
}
