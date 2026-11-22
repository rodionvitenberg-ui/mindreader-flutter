import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../design_system/taro.dart';
import '../../../state/app_settings_controller.dart';
import '../../../state/backend_auth_controller.dart';
import '../../../state/store_controller.dart';

/// Compact 2-step passwordless Email sign-in / registration form.
/// Reused both inline inside [ProfileAccountCard] and in [EmailAuthSheet].
class EmailAuthForm extends StatefulWidget {
  const EmailAuthForm({super.key, this.onAuthenticated});

  final VoidCallback? onAuthenticated;

  @override
  State<EmailAuthForm> createState() => _EmailAuthFormState();
}

class _EmailAuthFormState extends State<EmailAuthForm> {
  final _emailCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();

  bool _codeSent = false;
  String? _devCode;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = AppStrings.g('shop.auth.invalidEmail'));
      return;
    }
    setState(() => _error = null);
    try {
      final devCode = await context
          .read<BackendAuthController>()
          .startEmailSignIn(email);
      if (!mounted) return;
      setState(() {
        _codeSent = true;
        _devCode = devCode;
        if (devCode != null && devCode.isNotEmpty) {
          _codeCtrl.text = devCode;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  Future<void> _verifyCode() async {
    final code = _codeCtrl.text.trim();
    if (code.isEmpty) return;
    setState(() => _error = null);
    try {
      await context.read<BackendAuthController>().verifyEmailCode(code);
      if (!mounted) return;
      // Refresh store ownership so all purchased/migrated items sync immediately.
      final store = context.read<StoreController>();
      if (store.isConfigured) {
        await store.refresh();
      }
      if (!mounted) return;
      widget.onAuthenticated?.call();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<BackendAuthController>();
    final lang = context.watch<AppSettingsController>().language;

    if (!auth.isConfigured) {
      return Text(
        AppStrings.t(lang, 'shop.state.offline'),
        style: const TextStyle(
          fontSize: 12,
          color: TaroColors.textSecondary,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          AppStrings.t(lang, 'shop.auth.hint'),
          style: const TextStyle(
            fontSize: 12,
            height: 1.45,
            color: TaroColors.textSecondary,
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: TaroColors.conflictRose.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: TaroColors.conflictRose.withValues(alpha: 0.45),
              ),
            ),
            child: Text(
              _error!,
              style: const TextStyle(fontSize: 12, color: TaroColors.error),
            ),
          ),
        ],
        const SizedBox(height: 12),
        if (!_codeSent) ...[
          TextField(
            key: const ValueKey('auth-email-input'),
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            style: const TextStyle(color: TaroColors.textPrimary, fontSize: 14),
            cursorColor: TaroColors.lavender,
            decoration: _inputDecoration(
              AppStrings.t(lang, 'shop.auth.emailPlaceholder'),
              Icons.mail_outline,
            ),
            onSubmitted: (_) => _sendCode(),
          ),
          const SizedBox(height: 12),
          TaroGlassButton(
            key: const ValueKey('auth-send-code'),
            icon: Icons.send_outlined,
            label: auth.isBusy
                ? AppStrings.t(lang, 'shop.state.processing')
                : AppStrings.t(lang, 'shop.auth.sendCode'),
            variant: TaroGlassButtonVariant.primary,
            onPressed: auth.isBusy ? null : _sendCode,
          ),
        ] else ...[
          if (_devCode != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: TaroColors.lavender.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: TaroColors.lavender.withValues(alpha: 0.4),
                ),
              ),
              child: Text(
                '${AppStrings.t(lang, 'shop.auth.devCodeHint')}: $_devCode',
                style: const TextStyle(
                  fontSize: 11.5,
                  color: TaroColors.lavender,
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
          TextField(
            key: const ValueKey('auth-code-input'),
            controller: _codeCtrl,
            style: const TextStyle(color: TaroColors.textPrimary, fontSize: 14),
            cursorColor: TaroColors.lavender,
            decoration: _inputDecoration(
              AppStrings.t(lang, 'shop.auth.codePlaceholder'),
              Icons.key_outlined,
            ),
            onSubmitted: (_) => _verifyCode(),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              TextButton(
                onPressed: auth.isBusy
                    ? null
                    : () => setState(() {
                          _codeSent = false;
                          _devCode = null;
                          _codeCtrl.clear();
                        }),
                child: Text(
                  AppStrings.t(lang, 'shop.auth.back'),
                  style: const TextStyle(color: TaroColors.textSecondary),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TaroGlassButton(
                  key: const ValueKey('auth-verify-code'),
                  icon: Icons.verified_user_outlined,
                  label: auth.isBusy
                      ? AppStrings.t(lang, 'shop.state.processing')
                      : AppStrings.t(lang, 'shop.auth.verifyCode'),
                  variant: TaroGlassButtonVariant.primary,
                  onPressed: auth.isBusy ? null : _verifyCode,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  InputDecoration _inputDecoration(String hint, IconData icon) =>
      InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
          fontSize: 13,
          color: TaroColors.textSecondary,
        ),
        prefixIcon: Icon(icon, size: 18, color: TaroColors.lavender),
        filled: true,
        fillColor: TaroColors.background.withValues(alpha: 0.72),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(TaroRadii.input),
          borderSide: BorderSide(
            color: TaroColors.mist.withValues(alpha: TaroOpacity.borderStrong),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(TaroRadii.input),
          borderSide: const BorderSide(color: TaroColors.lavender),
        ),
      );
}

/// Modal bottom sheet wrapping [EmailAuthForm] for compact sign-in inside the Shop.
class EmailAuthSheet extends StatelessWidget {
  const EmailAuthSheet({super.key});

  static Future<bool> show(BuildContext context) async {
    final result = await showTaroGlassSheet<bool>(
      context: context,
      builder: (_) => const EmailAuthSheet(),
    );
    return result == true;
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<AppSettingsController>().language;
    return TaroGlassSheet(
      padding: EdgeInsets.fromLTRB(
        20,
        14,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              AppStrings.t(lang, 'shop.auth.title'),
              style: Theme.of(context).textTheme.displayMedium,
            ),
            const SizedBox(height: 12),
            EmailAuthForm(
              onAuthenticated: () => Navigator.of(context).pop(true),
            ),
          ],
        ),
      ),
    );
  }
}
