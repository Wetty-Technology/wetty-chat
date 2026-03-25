import 'dart:convert';
import 'dart:io';
import 'dart:math';

const String chromeUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/134.0.0.0 Safari/537.36';

final Uri fixedSiteBaseUri = Uri.parse('https://www.shireyishunjian.com/main/');
final Uri fixedLoginPageUri = fixedSiteBaseUri.resolve(
  'member.php?mod=logging&action=login',
);
final Uri fixedTokenPageUri = fixedSiteBaseUri.resolve(
  'shireyishunjian-telegram-api/chahua.php',
);

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
  DiscuzLoginClient(this.config)
    : _httpClient = HttpClient()..userAgent = chromeUserAgent;

  final LoginConfig config;
  final HttpClient _httpClient;
  final Map<String, Cookie> _cookies = <String, Cookie>{};

  Future<LoginResult> login() async {
    final loginPage = await _send('GET', fixedLoginPageUri);
    final formhash = _extractFormhash(loginPage.body);
    if (formhash == null) {
      throw StateError(
        'Failed to parse formhash from login page: ${loginPage.uri}',
      );
    }

    final submitBaseUri = _baseUriFromCurrentUri(loginPage.uri);
    final submitUri = submitBaseUri.resolve(
      'member.php?mod=logging&action=login&loginsubmit=yes&loginhash=${_randomAlphaNumeric(5)}',
    );

    final form = <String, String>{
      'formhash': formhash,
      'referer': submitBaseUri.toString(),
      'loginfield': 'username',
      'username': config.username,
      'password': config.password,
      'questionid': config.questionId,
      'answer': config.answer,
      'loginsubmit': 'true',
    };
    if (config.cookieTime) {
      form['cookietime'] = '2592000';
    }

    final loginResponse = await _send(
      'POST',
      submitUri,
      form: form,
      referer: loginPage.uri,
      origin: _origin(submitBaseUri),
    );

    if (!_hasAuthCookie()) {
      final message =
          _extractMessage(loginResponse.body) ??
          'Login failed without auth cookie.';
      throw StateError(message);
    }

    final cookieHeader = _buildReusableCookieHeader(fixedSiteBaseUri);
    if (cookieHeader.isEmpty) {
      throw StateError('Login succeeded but reusable cookie header is empty.');
    }

    final tokenResponse = await _send(
      'GET',
      fixedTokenPageUri,
      referer: submitBaseUri,
      origin: _origin(fixedSiteBaseUri),
    );
    final token = _extractToken(tokenResponse.body);
    if (token == null || token.isEmpty) {
      throw StateError('Failed to extract token from ${tokenResponse.uri}.');
    }

    return LoginResult(cookieHeader: cookieHeader, token: token);
  }

  void close() {
    _httpClient.close(force: true);
  }

  Future<_HttpResult> _send(
    String method,
    Uri uri, {
    Map<String, String>? form,
    Uri? referer,
    String? origin,
  }) async {
    var currentMethod = method;
    var currentUri = uri;
    var currentForm = form;
    var nextReferer = referer;
    var nextOrigin = origin;

    for (var redirectCount = 0; redirectCount < 5; redirectCount++) {
      final request = await _httpClient.openUrl(currentMethod, currentUri);
      request.headers.set(HttpHeaders.userAgentHeader, chromeUserAgent);
      request.headers.set(
        HttpHeaders.acceptHeader,
        'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
      );
      request.headers.set(
        HttpHeaders.acceptLanguageHeader,
        'zh-CN,zh;q=0.9,en;q=0.8',
      );
      request.followRedirects = false;

      if (nextReferer != null) {
        request.headers.set(HttpHeaders.refererHeader, nextReferer.toString());
      }
      if (nextOrigin != null) {
        request.headers.set('origin', nextOrigin);
      }

      for (final cookie in _cookies.values) {
        if (_cookieMatches(cookie, currentUri)) {
          request.cookies.add(_cloneCookie(cookie));
        }
      }

      if (currentForm != null) {
        request.headers.contentType = ContentType(
          'application',
          'x-www-form-urlencoded',
          charset: 'utf-8',
        );
        request.write(Uri(queryParameters: currentForm).query);
      }

      final response = await request.close();
      _storeCookies(currentUri, response.cookies);
      final body = await response.transform(utf8.decoder).join();
      final location = response.headers.value(HttpHeaders.locationHeader);

      if (location == null ||
          response.statusCode < 300 ||
          response.statusCode >= 400) {
        return _HttpResult(uri: currentUri, body: body);
      }

      final previousUri = currentUri;
      currentUri = currentUri.resolve(location);
      nextReferer = previousUri;
      nextOrigin = _origin(previousUri);

      if (response.statusCode == HttpStatus.movedPermanently ||
          response.statusCode == HttpStatus.movedTemporarily ||
          response.statusCode == HttpStatus.seeOther) {
        currentMethod = 'GET';
        currentForm = null;
      }
    }

    throw StateError('Too many redirects while requesting $uri');
  }

  void _storeCookies(Uri uri, List<Cookie> cookies) {
    for (final cookie in cookies) {
      final stored = _cloneCookie(cookie);
      stored.domain ??= uri.host;
      stored.path ??= '/';
      _cookies[stored.name] = stored;
    }
  }

  bool _hasAuthCookie() {
    return _cookies.entries.any(
      (entry) =>
          entry.key.endsWith('_auth') &&
          _isReusableCookieValue(entry.value.value),
    );
  }

  String _buildReusableCookieHeader(Uri uri) {
    return _cookies.values
        .where((cookie) => _cookieMatches(cookie, uri))
        .where((cookie) => _isReusableCookieValue(cookie.value))
        .map((cookie) => '${cookie.name}=${cookie.value}')
        .join('; ');
  }

  bool _cookieMatches(Cookie cookie, Uri uri) {
    final domain = cookie.domain;
    if (domain != null && domain.isNotEmpty) {
      final normalized = domain.startsWith('.') ? domain.substring(1) : domain;
      if (uri.host != normalized && !uri.host.endsWith('.$normalized')) {
        return false;
      }
    }

    final path = (cookie.path == null || cookie.path!.isEmpty)
        ? '/'
        : cookie.path!;
    if (!uri.path.startsWith(path)) {
      return false;
    }

    if (cookie.secure && uri.scheme != 'https') {
      return false;
    }

    return true;
  }

  Cookie _cloneCookie(Cookie cookie) {
    final clone = Cookie(cookie.name, cookie.value);
    clone.domain = cookie.domain;
    clone.path = cookie.path;
    clone.httpOnly = cookie.httpOnly;
    clone.secure = cookie.secure;
    clone.expires = cookie.expires;
    clone.maxAge = cookie.maxAge;
    return clone;
  }
}

class _HttpResult {
  _HttpResult({required this.uri, required this.body});

  final Uri uri;
  final String body;
}

String? _extractFormhash(String html) {
  final patterns = <RegExp>[
    RegExp(
      r'''<input[^>]*name=["']formhash["'][^>]*value=["']([^"']+)["']''',
      caseSensitive: false,
    ),
    RegExp(
      r'''<input[^>]*value=["']([^"']+)["'][^>]*name=["']formhash["']''',
      caseSensitive: false,
    ),
    RegExp(
      r'''<input[^>]*name=formhash[^>]*value=(["']?)([^"' >]+)\1''',
      caseSensitive: false,
    ),
    RegExp(
      r'''<input[^>]*value=(["']?)([^"' >]+)\1[^>]*name=formhash''',
      caseSensitive: false,
    ),
  ];

  for (final pattern in patterns) {
    final match = pattern.firstMatch(html);
    if (match == null) {
      continue;
    }
    for (var i = 1; i <= match.groupCount; i++) {
      final value = match.group(i);
      if (value != null && value.isNotEmpty && value != '"' && value != "'") {
        return value;
      }
    }
  }
  return null;
}

String? _extractMessage(String html) {
  final patterns = <RegExp>[
    RegExp(r'''<div[^>]*id=["']messagetext["'][^>]*>([\s\S]*?)</div>'''),
    RegExp(r'''<p[^>]*class=["']alert_error["'][^>]*>([\s\S]*?)</p>'''),
    RegExp(r'''<em[^>]*id=["']returnmessage_[^"']+["'][^>]*>([\s\S]*?)</em>'''),
  ];

  for (final pattern in patterns) {
    final match = pattern.firstMatch(html);
    if (match != null) {
      return _stripTags(match.group(1)!);
    }
  }
  return null;
}

String? _extractToken(String body) {
  final urlPattern = RegExp(r'''https?://[^\s"'<>]+''', caseSensitive: false);
  for (final match in urlPattern.allMatches(body)) {
    final candidate = match.group(0);
    if (candidate == null) {
      continue;
    }
    final uri = Uri.tryParse(candidate);
    final token = uri?.queryParameters['token'];
    if (token != null && token.isNotEmpty) {
      return token;
    }
  }

  final tokenPattern = RegExp(r'''[?&]token=([A-Za-z0-9._-]+)''');
  final tokenMatch = tokenPattern.firstMatch(body);
  return tokenMatch?.group(1);
}

String _origin(Uri uri) {
  final hasDefaultPort =
      (uri.scheme == 'http' && uri.port == 80) ||
      (uri.scheme == 'https' && uri.port == 443);
  final port = uri.hasPort && !hasDefaultPort ? ':${uri.port}' : '';
  return '${uri.scheme}://${uri.host}$port';
}

Uri _baseUriFromCurrentUri(Uri uri) {
  final pathSegments = uri.pathSegments
      .where((segment) => segment.isNotEmpty)
      .toList();
  if (pathSegments.isNotEmpty &&
      pathSegments.last.toLowerCase().endsWith('.php')) {
    pathSegments.removeLast();
  }
  final path = pathSegments.isEmpty ? '/' : '/${pathSegments.join('/')}/';
  return Uri(
    scheme: uri.scheme,
    userInfo: uri.userInfo,
    host: uri.host,
    port: uri.hasPort ? uri.port : null,
    path: path,
  );
}

bool _isReusableCookieValue(String value) {
  final normalized = value.trim().toLowerCase();
  return normalized.isNotEmpty && normalized != 'deleted';
}

String _randomAlphaNumeric(int length) {
  const chars =
      'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  final random = Random.secure();
  return List.generate(
    length,
    (_) => chars[random.nextInt(chars.length)],
  ).join();
}

String _stripTags(String input) {
  return input
      .replaceAll(RegExp(r'<[^>]+>'), ' ')
      .replaceAll(RegExp(r'&nbsp;?', caseSensitive: false), ' ')
      .replaceAll(RegExp(r'&[a-zA-Z]+;'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
