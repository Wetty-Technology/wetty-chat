class LoginConfig {
  LoginConfig({
    required this.username,
    required this.password,
    required this.questionId,
    required this.answer,
    this.cookieTime = true,
  });

  final String username;
  final String password;
  final String questionId;
  final String answer;
  final bool cookieTime;
}

class LoginResult {
  LoginResult({required this.cookieHeader, required this.token});

  final String cookieHeader;
  final String token;
}

class DiscuzLoginClient {
  DiscuzLoginClient(this.config);

  final LoginConfig config;

  Future<LoginResult> login() {
    throw UnsupportedError('Discuz login is only supported on desktop builds.');
  }

  void close() {}
}
