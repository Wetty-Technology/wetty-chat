import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../application/auth_store.dart';
import '../data/discuz_login_client.dart';

class SecurityQuestionOption {
  const SecurityQuestionOption(this.value, this.label);

  final String value;
  final String label;
}

const List<SecurityQuestionOption> securityQuestions = <SecurityQuestionOption>[
  SecurityQuestionOption('0', '安全提问(未设置请忽略)'),
  SecurityQuestionOption('1', '母亲的名字'),
  SecurityQuestionOption('2', '爷爷的名字'),
  SecurityQuestionOption('3', '父亲出生的城市'),
  SecurityQuestionOption('4', '您其中一位老师的名字'),
  SecurityQuestionOption('5', '您个人计算机的型号'),
  SecurityQuestionOption('6', '您最喜欢的餐馆名称'),
  SecurityQuestionOption('7', '驾驶执照最后四位数字'),
];

/// Legacy login UI kept in the codebase while authentication is redesigned.
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
  String _statusTitle = '准备就绪';
  String _statusMessage = '输入用户名、密码和安全问题后开始登录。';
  LoginResult? _lastLoginResult;

  TextStyle _inputStyle(BuildContext context) {
    return TextStyle(color: CupertinoColors.label.resolveFrom(context));
  }

  TextStyle _placeholderStyle(BuildContext context) {
    return TextStyle(
      color: CupertinoColors.placeholderText.resolveFrom(context),
    );
  }

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
        _statusTitle = '缺少字段';
        _statusMessage = '用户名和密码为必填项。';
      });
      return;
    }

    setState(() {
      _isLoggingIn = true;
      _statusTitle = '处理中';
      _statusMessage = '正在登录并请求 token...';
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
        _statusTitle = '登录成功';
        _statusMessage = '已拿到可复用 Cookie Header 和 token。';
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
        _statusTitle = '登录失败';
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
      _statusTitle = '已复制';
      _statusMessage = '$label 已复制。';
    });
  }

  Future<void> _pickQuestion() async {
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('安全问题'),
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
          child: const Text('取消'),
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
                child: const Text('关闭'),
              )
            : null,
        middle: const Text('登录'),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            _InfoCard(
              title: currentUid == null ? '登录信息' : '当前已登录',
              body: currentUid == null
                  ? '输入用户名、密码和安全问题后开始登录。'
                  : '当前保存的 token 对应 uid: $currentUid。',
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: '登录信息',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CupertinoTextField(
                    controller: _usernameController,
                    placeholder: '用户名',
                    style: _inputStyle(context),
                    placeholderStyle: _placeholderStyle(context),
                    padding: const EdgeInsets.all(14),
                  ),
                  const SizedBox(height: 12),
                  CupertinoTextField(
                    controller: _passwordController,
                    placeholder: '密码',
                    style: _inputStyle(context),
                    placeholderStyle: _placeholderStyle(context),
                    obscureText: true,
                    padding: const EdgeInsets.all(14),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    '安全问题',
                    style: TextStyle(fontWeight: FontWeight.w600),
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
                          Expanded(child: Text(_selectedQuestion.label)),
                          const Icon(CupertinoIcons.chevron_down),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  CupertinoTextField(
                    controller: _answerController,
                    placeholder: '答案',
                    style: _inputStyle(context),
                    placeholderStyle: _placeholderStyle(context),
                    padding: const EdgeInsets.all(14),
                  ),
                  if (currentUid == null) ...[
                    const SizedBox(height: 20),
                    CupertinoButton.filled(
                      onPressed: _isLoggingIn ? null : _submitDiscuzLogin,
                      child: Text(_isLoggingIn ? '登录中...' : '开始登录'),
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
                          child: const Text('复制 Token'),
                        ),
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: () => _copyText(
                            _lastLoginResult!.cookieHeader,
                            'Cookie Header',
                          ),
                          child: const Text('复制 Cookie Header'),
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
