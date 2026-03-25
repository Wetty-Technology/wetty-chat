import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../../config/auth_store.dart';
import 'discuz_login_client.dart';

class SecurityQuestionOption {
  const SecurityQuestionOption(this.value, this.label);

  final String value;
  final String label;
}

const List<SecurityQuestionOption> securityQuestions = <SecurityQuestionOption>[
  SecurityQuestionOption('0', 'No security question'),
  SecurityQuestionOption('1', 'Mother name'),
  SecurityQuestionOption('2', 'Grandfather name'),
  SecurityQuestionOption('3', 'Father birth city'),
  SecurityQuestionOption('4', 'One teacher name'),
  SecurityQuestionOption('5', 'Personal computer model'),
  SecurityQuestionOption('6', 'Favorite restaurant'),
  SecurityQuestionOption('7', 'Driver license last four digits'),
];

class TokenImportPage extends StatefulWidget {
  const TokenImportPage({super.key, this.allowClose = false});

  final bool allowClose;

  @override
  State<TokenImportPage> createState() => _TokenImportPageState();
}

class _TokenImportPageState extends State<TokenImportPage> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _answerController = TextEditingController();

  String _questionId = '0';
  bool _isLoggingIn = false;
  String _statusTitle = 'Ready';
  String _statusMessage =
      'Sign in with Discuz to fetch and save a fresh token for this desktop client.';
  LoginResult? _lastLoginResult;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _answerController.dispose();
    super.dispose();
  }

  SecurityQuestionOption get _selectedQuestion {
    return securityQuestions.firstWhere(
      (item) => item.value == _questionId,
      orElse: () => securityQuestions.first,
    );
  }

  Future<void> _submitDiscuzLogin() async {
    FocusScope.of(context).unfocus();

    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    final answer = _answerController.text.trim();
    if (username.isEmpty || password.isEmpty) {
      setState(() {
        _statusTitle = 'Missing fields';
        _statusMessage = 'Username and password are required.';
      });
      return;
    }

    setState(() {
      _isLoggingIn = true;
      _statusTitle = 'Working';
      _statusMessage = 'Signing in to Discuz and fetching token...';
      _lastLoginResult = null;
    });

    final client = DiscuzLoginClient(
      LoginConfig(
        username: username,
        password: password,
        questionId: _questionId,
        answer: answer,
      ),
    );

    try {
      final result = await client.login();
      await AuthStore.instance.setToken(result.token);
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoggingIn = false;
        _lastLoginResult = result;
        _statusTitle = 'Success';
        _statusMessage = 'Discuz login succeeded and the token has been saved.';
      });
      if (widget.allowClose) {
        Navigator.pop(context, true);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoggingIn = false;
        _statusTitle = 'Failed';
        _statusMessage = '$error';
      });
    } finally {
      client.close();
    }
  }

  Future<void> _copyText(String text, String label) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) {
      return;
    }
    setState(() {
      _statusTitle = 'Copied';
      _statusMessage = '$label copied to clipboard.';
    });
  }

  Future<void> _pickQuestion() async {
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Security Question'),
        actions: [
          for (final question in securityQuestions)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(context);
                setState(() {
                  _questionId = question.value;
                });
              },
              child: Text(question.label),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = AuthStore.instance.currentUserId;

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        leading: widget.allowClose
            ? CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Close'),
              )
            : null,
        middle: const Text('Discuz Login'),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            _InfoCard(
              title: currentUid == null
                  ? 'Login required'
                  : 'Already signed in',
              body: currentUid == null
                  ? 'Use your Discuz credentials to fetch a fresh token for this desktop client.'
                  : 'Current saved token belongs to uid $currentUid.',
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Discuz Login',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Site: https://www.shireyishunjian.com/main/'),
                  const SizedBox(height: 12),
                  CupertinoTextField(
                    controller: _usernameController,
                    placeholder: 'Username',
                    padding: const EdgeInsets.all(14),
                  ),
                  const SizedBox(height: 12),
                  CupertinoTextField(
                    controller: _passwordController,
                    placeholder: 'Password',
                    obscureText: true,
                    padding: const EdgeInsets.all(14),
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: _pickQuestion,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemGrey6.resolveFrom(context),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Security question: ${_selectedQuestion.label}',
                            ),
                          ),
                          const Icon(CupertinoIcons.chevron_down),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  CupertinoTextField(
                    controller: _answerController,
                    placeholder: 'Security answer (optional)',
                    padding: const EdgeInsets.all(14),
                  ),
                  if (currentUid == null) ...[
                    const SizedBox(height: 16),
                    CupertinoButton.filled(
                      onPressed: _isLoggingIn ? null : _submitDiscuzLogin,
                      child: Text(_isLoggingIn ? 'Signing in...' : 'Sign In'),
                    ),
                  ],
                  if (_lastLoginResult != null) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: () =>
                              _copyText(_lastLoginResult!.token, 'Token'),
                          child: const Text('Copy Token'),
                        ),
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: () => _copyText(
                            _lastLoginResult!.cookieHeader,
                            'Cookie header',
                          ),
                          child: const Text('Copy Cookie Header'),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            _InfoCard(title: _statusTitle, body: _statusMessage),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground.resolveFrom(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: CupertinoColors.separator.resolveFrom(context),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey6.resolveFrom(context),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: TextStyle(
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
