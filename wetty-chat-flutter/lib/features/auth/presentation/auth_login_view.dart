import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/style_config.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/session/dev_session_store.dart';

class AuthLoginPage extends ConsumerStatefulWidget {
  const AuthLoginPage({super.key});

  @override
  ConsumerState<AuthLoginPage> createState() => _AuthLoginPageState();
}

class _AuthLoginPageState extends ConsumerState<AuthLoginPage> {
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;
  String? _errorText;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController();
    _passwordController = TextEditingController();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    if (username.isEmpty || password.isEmpty) {
      setState(() {
        _isSubmitting = true;
        _errorText = null;
      });
      try {
        await ref.read(authSessionProvider.notifier).bootstrap();
      } catch (_) {
        if (!mounted) {
          return;
        }
        setState(() {
          _errorText = l10n.loginFailed;
        });
      } finally {
        if (mounted) {
          setState(() {
            _isSubmitting = false;
          });
        }
      }
      if (!mounted) {
        return;
      }

      final session = ref.read(authSessionProvider);
      if (!session.isAuthenticated) {
        setState(() {
          _errorText = l10n.loginFailed;
        });
      }
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });

    try {
      await ref
          .read(authSessionProvider.notifier)
          .loginWithCredentials(username, password);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorText = l10n.loginFailed;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _clearError() {
    if (_errorText == null) {
      return;
    }
    setState(() {
      _errorText = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(middle: Text(l10n.login)),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Sign in with your account. The app still tries the developer UID session first during startup.',
              style: appSecondaryTextStyle(
                context,
                fontSize: AppFontSizes.body,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              l10n.username,
              style: appTextStyle(
                context,
                fontSize: AppFontSizes.body,
                fontWeight: AppFontWeights.semibold,
              ),
            ),
            const SizedBox(height: 8),
            CupertinoTextField(
              controller: _usernameController,
              textInputAction: TextInputAction.next,
              placeholder: l10n.username,
              padding: const EdgeInsets.all(14),
              onChanged: (_) => _clearError(),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.password,
              style: appTextStyle(
                context,
                fontSize: AppFontSizes.body,
                fontWeight: AppFontWeights.semibold,
              ),
            ),
            const SizedBox(height: 8),
            CupertinoTextField(
              controller: _passwordController,
              obscureText: true,
              enableSuggestions: false,
              autocorrect: false,
              textInputAction: TextInputAction.done,
              placeholder: l10n.password,
              padding: const EdgeInsets.all(14),
              onSubmitted: (_) {
                if (!_isSubmitting) {
                  _submit();
                }
              },
              onChanged: (_) => _clearError(),
            ),
            if (_errorText != null) ...[
              const SizedBox(height: 8),
              Text(
                _errorText!,
                style: appTextStyle(
                  context,
                  fontSize: AppFontSizes.meta,
                  color: CupertinoColors.systemRed.resolveFrom(context),
                ),
              ),
            ],
            const SizedBox(height: 16),
            CupertinoButton.filled(
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const CupertinoActivityIndicator(
                      color: CupertinoColors.white,
                    )
                  : Text(l10n.login),
            ),
          ],
        ),
      ),
    );
  }
}
