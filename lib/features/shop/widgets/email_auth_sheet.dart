import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/services/backend_auth_service.dart';
import '../../../core/utils/email_validator.dart';
import '../../../design_system/taro.dart';
import '../../../state/app_settings_controller.dart';
import '../../../state/astral_controller.dart';
import '../../../state/backend_auth_controller.dart';
import '../../../state/store_controller.dart';
import '../../../state/user_profile_controller.dart';

enum AuthFormMode { login, register }

/// Full Email + Password sign-in / registration form (with name, password
/// confirmation, email format + domain typo check, and PRO/recovery notice).
/// No mandatory confirmation email is required on registration.
class EmailAuthForm extends StatefulWidget {
  const EmailAuthForm({
    super.key,
    this.initialMode = AuthFormMode.login,
    this.onAuthenticated,
    this.onModeChanged,
  });

  final AuthFormMode initialMode;
  final VoidCallback? onAuthenticated;
  final ValueChanged<AuthFormMode>? onModeChanged;

  @override
  State<EmailAuthForm> createState() => _EmailAuthFormState();
}

class _EmailAuthFormState extends State<EmailAuthForm> {
  late AuthFormMode _mode = widget.initialMode;

  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _receiptCtrl = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _showReceiptField = false;
  String? _typoSuggestion;
  String? _error;

  @override
  void initState() {
    super.initState();
    final existingName =
        context.read<UserProfileController?>()?.displayName.trim() ?? '';
    if (existingName.isNotEmpty) {
      _nameCtrl.text = existingName;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    _receiptCtrl.dispose();
    super.dispose();
  }

  void _setMode(AuthFormMode next) {
    if (_mode == next) return;
    setState(() {
      _mode = next;
      _error = null;
    });
    widget.onModeChanged?.call(next);
  }

  void _onEmailChanged(String value) {
    final suggestion = EmailValidator.suggestCorrection(value);
    if (suggestion != _typoSuggestion) {
      setState(() => _typoSuggestion = suggestion);
    }
  }

  void _applySuggestion(String suggestion) {
    _emailCtrl.value = TextEditingValue(
      text: suggestion,
      selection: TextSelection.collapsed(offset: suggestion.length),
    );
    setState(() {
      _typoSuggestion = null;
      _error = null;
    });
  }

  Future<void> _submit() async {
    final lang = context.read<AppSettingsController>().language;
    final auth = context.read<BackendAuthController>();
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;

    if (!EmailValidator.isValid(email)) {
      setState(() => _error = AppStrings.t(lang, 'shop.auth.invalidEmail'));
      return;
    }

    if (_mode == AuthFormMode.register) {
      final name = _nameCtrl.text.trim();
      if (name.isEmpty) {
        setState(() => _error = AppStrings.t(lang, 'auth.nameRequired'));
        return;
      }
      if (password.length < 8) {
        setState(() => _error = AppStrings.t(lang, 'auth.passwordTooShort'));
        return;
      }
      if (password != _confirmCtrl.text) {
        setState(() => _error = AppStrings.t(lang, 'auth.passwordsMismatch'));
        return;
      }
      if (!auth.isConfigured) {
        setState(() => _error = AppStrings.t(lang, 'shop.state.offline'));
        return;
      }
      setState(() => _error = null);
      try {
        final created = await auth.registerWithPassword(
          name: name,
          email: email,
          password: password,
          receiptNumber: _receiptCtrl.text.trim().isEmpty
              ? null
              : _receiptCtrl.text.trim(),
        );
        if (!mounted) return;
        context.read<AppSettingsController>().setProUnlocked(created.isPro);
        context.read<AstralController?>()?.setProUnlocked(created.isPro);
        final profile = context.read<UserProfileController?>();
        if (profile != null && name.isNotEmpty) {
          profile.setDisplayName(name);
        }
        final store = context.read<StoreController?>();
        if (store != null && store.isConfigured) {
          await store.refresh();
        }
        if (!mounted) return;
        widget.onAuthenticated?.call();
      } catch (e) {
        if (!mounted) return;
        setState(() {
          if (e is BackendApiException && e.code == 'pro_claim_required') {
            _showReceiptField = true;
          }
          _error = e.toString();
        });
      }
      return;
    }

    if (password.isEmpty) {
      setState(() => _error = AppStrings.t(lang, 'auth.passwordRequired'));
      return;
    }
    if (!auth.isConfigured) {
      setState(() => _error = AppStrings.t(lang, 'shop.state.offline'));
      return;
    }
    setState(() => _error = null);
    try {
      final session = await auth.signInWithPassword(
        email: email,
        password: password,
      );
      if (!mounted) return;
      context.read<AppSettingsController>().setProUnlocked(session.isPro);
      context.read<AstralController?>()?.setProUnlocked(session.isPro);
      final profile = context.read<UserProfileController?>();
      if (profile != null &&
          profile.displayName.trim().isEmpty &&
          (session.name?.trim().isNotEmpty ?? false)) {
        profile.setDisplayName(session.name!.trim());
      }
      final store = context.read<StoreController?>();
      if (store != null && store.isConfigured) {
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
    final isRegister = _mode == AuthFormMode.register;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_error != null) ...[
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
          const SizedBox(height: 12),
        ],
        if (isRegister) ...[
          TextField(
            key: const ValueKey('auth-name-input'),
            controller: _nameCtrl,
            textCapitalization: TextCapitalization.words,
            autofillHints: const [AutofillHints.name],
            style: const TextStyle(color: TaroColors.textPrimary, fontSize: 14),
            cursorColor: TaroColors.lavender,
            decoration: _inputDecoration(
              AppStrings.t(lang, 'auth.namePlaceholder'),
              Icons.person_outline,
            ),
          ),
          const SizedBox(height: 10),
        ],
        TextField(
          key: const ValueKey('auth-email-input'),
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          autofillHints: const [AutofillHints.email],
          style: const TextStyle(color: TaroColors.textPrimary, fontSize: 14),
          cursorColor: TaroColors.lavender,
          decoration: _inputDecoration(
            AppStrings.t(lang, 'shop.auth.emailPlaceholder'),
            Icons.mail_outline,
          ),
          onChanged: _onEmailChanged,
        ),
        if (_typoSuggestion != null) ...[
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: GestureDetector(
              key: const ValueKey('auth-email-typo-fix'),
              onTap: () => _applySuggestion(_typoSuggestion!),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: TaroColors.amber.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: TaroColors.amber.withValues(alpha: 0.5),
                  ),
                ),
                child: Text(
                  AppStrings.t(lang, 'auth.emailTypoSuggestion', {
                    'email': _typoSuggestion!,
                  }),
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: TaroColors.amber,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ],
        if (isRegister) ...[
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 1),
                child: Icon(
                  Icons.info_outline_rounded,
                  size: 14,
                  color: TaroColors.lavender,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  AppStrings.t(lang, 'auth.emailNotice'),
                  key: const ValueKey('auth-email-notice'),
                  style: const TextStyle(
                    fontSize: 11.5,
                    height: 1.4,
                    color: TaroColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 10),
        TextField(
          key: const ValueKey('auth-password-input'),
          controller: _passwordCtrl,
          obscureText: _obscurePassword,
          autofillHints: isRegister
              ? const [AutofillHints.newPassword]
              : const [AutofillHints.password],
          style: const TextStyle(color: TaroColors.textPrimary, fontSize: 14),
          cursorColor: TaroColors.lavender,
          decoration: _inputDecoration(
            AppStrings.t(lang, 'auth.passwordPlaceholder'),
            Icons.lock_outline,
            suffix: IconButton(
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                size: 18,
                color: TaroColors.textSecondary,
              ),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
          onSubmitted: isRegister ? null : (_) => _submit(),
        ),
        if (isRegister) ...[
          const SizedBox(height: 10),
          TextField(
            key: const ValueKey('auth-confirm-password-input'),
            controller: _confirmCtrl,
            obscureText: _obscureConfirm,
            autofillHints: const [AutofillHints.newPassword],
            style: const TextStyle(color: TaroColors.textPrimary, fontSize: 14),
            cursorColor: TaroColors.lavender,
            decoration: _inputDecoration(
              AppStrings.t(lang, 'auth.confirmPasswordPlaceholder'),
              Icons.lock_outline,
              suffix: IconButton(
                icon: Icon(
                  _obscureConfirm
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 18,
                  color: TaroColors.textSecondary,
                ),
                onPressed: () =>
                    setState(() => _obscureConfirm = !_obscureConfirm),
              ),
            ),
            onSubmitted: (_) => _submit(),
          ),
          if (_showReceiptField) ...[
            const SizedBox(height: 10),
            TextField(
              key: const ValueKey('auth-receipt-claim-input'),
              controller: _receiptCtrl,
              textCapitalization: TextCapitalization.characters,
              autocorrect: false,
              style: const TextStyle(color: TaroColors.textPrimary, fontSize: 14),
              cursorColor: TaroColors.lavender,
              decoration: _inputDecoration(
                AppStrings.t(lang, 'auth.receiptClaimPlaceholder'),
                Icons.receipt_long_outlined,
              ),
              onSubmitted: (_) => _submit(),
            ),
          ],
        ],
        const SizedBox(height: 14),
        TaroGlassButton(
          key: ValueKey(isRegister ? 'auth-register-submit' : 'auth-login-submit'),
          icon: isRegister ? Icons.person_add_outlined : Icons.login_outlined,
          label: auth.isBusy
              ? AppStrings.t(lang, 'shop.state.processing')
              : AppStrings.t(
                  lang,
                  isRegister ? 'auth.createAccount' : 'auth.login',
                ),
          variant: TaroGlassButtonVariant.primary,
          onPressed: auth.isBusy ? null : _submit,
        ),
        const SizedBox(height: 8),
        TextButton(
          key: const ValueKey('auth-switch-mode'),
          onPressed: auth.isBusy
              ? null
              : () => _setMode(
                    isRegister ? AuthFormMode.login : AuthFormMode.register,
                  ),
          child: Text(
            AppStrings.t(
              lang,
              isRegister ? 'auth.switchToLogin' : 'auth.switchToRegister',
            ),
            style: const TextStyle(
              fontSize: 12.5,
              color: TaroColors.lavender,
            ),
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(
    String hint,
    IconData icon, {
    Widget? suffix,
  }) =>
      InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
          fontSize: 13,
          color: TaroColors.textSecondary,
        ),
        prefixIcon: Icon(icon, size: 18, color: TaroColors.lavender),
        suffixIcon: suffix,
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

/// Modal bottom sheet wrapping [EmailAuthForm] for Sign In / Registration.
class EmailAuthSheet extends StatefulWidget {
  const EmailAuthSheet({
    super.key,
    this.initialMode = AuthFormMode.login,
  });

  final AuthFormMode initialMode;

  static Future<bool> show(
    BuildContext context, {
    AuthFormMode initialMode = AuthFormMode.login,
  }) async {
    final result = await showTaroGlassSheet<bool>(
      context: context,
      builder: (_) => EmailAuthSheet(initialMode: initialMode),
    );
    return result == true;
  }

  @override
  State<EmailAuthSheet> createState() => _EmailAuthSheetState();
}

class _EmailAuthSheetState extends State<EmailAuthSheet> {
  late AuthFormMode _mode = widget.initialMode;

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<AppSettingsController>().language;
    final titleKey =
        _mode == AuthFormMode.register ? 'auth.register' : 'auth.login';
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
              AppStrings.t(lang, titleKey),
              style: Theme.of(context).textTheme.displayMedium,
            ),
            const SizedBox(height: 14),
            EmailAuthForm(
              initialMode: widget.initialMode,
              onModeChanged: (next) => setState(() => _mode = next),
              onAuthenticated: () => Navigator.of(context).pop(true),
            ),
          ],
        ),
      ),
    );
  }
}

/// Optional post-registration email confirmation sheet ("Verify email for
/// password reset"). Never required to register or use the app.
class EmailConfirmSheet extends StatefulWidget {
  const EmailConfirmSheet({super.key, required this.email});

  final String email;

  static Future<bool> show(BuildContext context, {required String email}) async {
    final result = await showTaroGlassSheet<bool>(
      context: context,
      builder: (_) => EmailConfirmSheet(email: email),
    );
    return result == true;
  }

  @override
  State<EmailConfirmSheet> createState() => _EmailConfirmSheetState();
}

class _EmailConfirmSheetState extends State<EmailConfirmSheet> {
  final _codeCtrl = TextEditingController();
  bool _codeSent = false;
  String? _devCode;
  String? _error;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() => _error = null);
    try {
      final devCode = await context
          .read<BackendAuthController>()
          .startEmailSignIn(widget.email);
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

  Future<void> _verify() async {
    final code = _codeCtrl.text.trim();
    if (code.isEmpty) return;
    setState(() => _error = null);
    try {
      await context.read<BackendAuthController>().verifyEmailCode(code);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<BackendAuthController>();
    final lang = context.watch<AppSettingsController>().language;
    return TaroGlassSheet(
      padding: EdgeInsets.fromLTRB(
        20,
        14,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            AppStrings.t(lang, 'auth.verifyEmailOptional'),
            style: Theme.of(context).textTheme.displayMedium,
          ),
          const SizedBox(height: 8),
          Text(
            widget.email,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: TaroColors.lavender,
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              style: const TextStyle(fontSize: 12, color: TaroColors.error),
            ),
          ],
          const SizedBox(height: 14),
          if (!_codeSent)
            TaroGlassButton(
              key: const ValueKey('auth-send-code'),
              icon: Icons.send_outlined,
              label: auth.isBusy
                  ? AppStrings.t(lang, 'shop.state.processing')
                  : AppStrings.t(lang, 'shop.auth.sendCode'),
              variant: TaroGlassButtonVariant.primary,
              onPressed: auth.isBusy ? null : _send,
            )
          else ...[
            if (_devCode != null) ...[
              Text(
                '${AppStrings.t(lang, 'shop.auth.devCodeHint')}: $_devCode',
                style: const TextStyle(
                  fontSize: 11.5,
                  color: TaroColors.lavender,
                ),
              ),
              const SizedBox(height: 8),
            ],
            TextField(
              key: const ValueKey('auth-code-input'),
              controller: _codeCtrl,
              style: const TextStyle(color: TaroColors.textPrimary, fontSize: 14),
              cursorColor: TaroColors.lavender,
              decoration: InputDecoration(
                hintText: AppStrings.t(lang, 'shop.auth.codePlaceholder'),
                hintStyle: const TextStyle(
                  fontSize: 13,
                  color: TaroColors.textSecondary,
                ),
                prefixIcon: const Icon(
                  Icons.key_outlined,
                  size: 18,
                  color: TaroColors.lavender,
                ),
                filled: true,
                fillColor: TaroColors.background.withValues(alpha: 0.72),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(TaroRadii.input),
                ),
              ),
              onSubmitted: (_) => _verify(),
            ),
            const SizedBox(height: 12),
            TaroGlassButton(
              key: const ValueKey('auth-verify-code'),
              icon: Icons.verified_user_outlined,
              label: auth.isBusy
                  ? AppStrings.t(lang, 'shop.state.processing')
                  : AppStrings.t(lang, 'shop.auth.verifyCode'),
              variant: TaroGlassButtonVariant.primary,
              onPressed: auth.isBusy ? null : _verify,
            ),
          ],
        ],
      ),
    );
  }
}
