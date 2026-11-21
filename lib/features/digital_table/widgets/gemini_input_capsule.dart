import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';

/// The shared Gemini-style floating input capsule docked directly above
/// the bottom navigation dock — ONE component used by the Digital Table
/// (Pane 0) and the Oracle AI Chat (Pane 1).
///
/// Visual: rounded dark obsidian pill (`radius 28`, hairline border) with
/// `+` on the left, an expandable text field in the middle, and the mic +
/// circular accent send (`↑`) on the right.
class GeminiInputCapsule extends StatefulWidget {
  const GeminiInputCapsule({
    super.key,
    required this.onSend,
    required this.onPlus,
    this.hint = 'Add context or ask Oracle...',
    this.sendKey,
    this.fieldKey,
    this.controller,
    this.focusNode,
  });

  final ValueChanged<String> onSend;
  final VoidCallback onPlus;
  final String hint;
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
  bool _micListening = false;
  SpeechToText? _speech;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _speech?.stop();
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
      _stopMic();
    }
  }

  Future<void> _stopMic() async {
    if (!_micListening) return;
    setState(() => _micListening = false);
    await _speech?.stop();
  }

  void _submit() {
    final text = _text.text.trim();
    if (text.isEmpty) return;
    HapticFeedback.selectionClick();
    widget.onSend(text);
    _text.clear();
  }

  Future<void> _toggleMic() async {
    if (_micListening) {
      await _stopMic();
      return;
    }
    _speech ??= SpeechToText();
    bool ok;
    try {
      ok = await _speech!.initialize();
    } catch (_) {
      ok = false;
    }
    if (!ok) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Voice input is not available here — type your thought instead.',
            ),
          ),
        );
      }
      return;
    }
    setState(() => _micListening = true);
    await _speech!.listen(
      onResult: (r) {
        _text.text = r.recognizedWords;
        _text.selection =
            TextSelection.collapsed(offset: _text.text.length);
      },
      listenOptions: SpeechListenOptions(
        listenFor: const Duration(seconds: 20),
      ),
    );
    if (mounted) setState(() => _micListening = false);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.42),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          _CapsuleIconButton(
            icon: Icons.add,
            tooltip: 'Add context',
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
              style: AppTypography.chatUser(
                fontSize: 15,
                height: 1.4,
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: widget.hint,
                hintStyle: AppTypography.chatUser(
                  fontSize: 14.5,
                  height: 1.4,
                  color: AppColors.textMuted.withValues(alpha: 0.8),
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          _CapsuleIconButton(
            icon: _micListening ? Icons.graphic_eq : Icons.mic_none,
            tooltip: 'Voice',
            tint: _micListening ? AppColors.conflictRose : null,
            onTap: _toggleMic,
          ),
          const SizedBox(width: 6),
          GestureDetector(
            key: widget.sendKey,
            onTap: _submit,
            child: Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.lavender, AppColors.indigo],
                ),
              ),
              child: const Icon(
                Icons.arrow_upward,
                size: 18,
                color: AppColors.canvas,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CapsuleIconButton extends StatelessWidget {
  const _CapsuleIconButton({
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.tint,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? '',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.surface.withValues(alpha: 0.8),
          ),
          child: Icon(
            icon,
            size: 17,
            color: tint ?? AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}

