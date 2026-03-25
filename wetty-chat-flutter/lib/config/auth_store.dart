import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthStore extends ChangeNotifier {
  AuthStore._();

  static final AuthStore instance = AuthStore._();

  static const String _tokenStorageKey = 'jwt_token';
  static final RegExp _jwtPattern = RegExp(
    r'[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+',
  );
  static final RegExp _tokenQueryPattern = RegExp(
    r'[?&]token=([A-Za-z0-9._-]+)',
  );
  static final RegExp _urlPattern = RegExp(
    r'https?://\S+',
    caseSensitive: false,
  );
  static final RegExp _bearerPrefixPattern = RegExp(
    r'^bearer\s+',
    caseSensitive: false,
  );

  SharedPreferences? _prefs;
  String? _token;
  int? _currentUserId;

  String? get token => _token;
  int? get currentUserId => _currentUserId;
  bool get hasToken => _token != null;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _applyToken(_prefs!.getString(_tokenStorageKey));
  }

  Future<int?> importFromText(String input) async {
    final extractedToken = extractToken(input);
    if (extractedToken == null) {
      return null;
    }

    await setToken(extractedToken);
    return _currentUserId;
  }

  Future<void> setToken(String? token) async {
    _prefs ??= await SharedPreferences.getInstance();

    final normalized = _normalizeToken(token);
    _applyToken(normalized);

    if (normalized == null) {
      await _prefs!.remove(_tokenStorageKey);
    } else {
      await _prefs!.setString(_tokenStorageKey, normalized);
    }

    notifyListeners();
  }

  Future<void> clearToken() async {
    await setToken(null);
  }

  String? extractToken(String rawInput) {
    final normalizedInput = rawInput.trim();
    if (normalizedInput.isEmpty) {
      return null;
    }

    final directCandidate = _normalizeDirectToken(normalizedInput);
    if (directCandidate != null) {
      return directCandidate;
    }

    final jsonCandidate = _extractTokenFromJson(normalizedInput);
    if (jsonCandidate != null) {
      return jsonCandidate;
    }

    for (final match in _urlPattern.allMatches(normalizedInput)) {
      final candidate = match.group(0);
      if (candidate == null) {
        continue;
      }
      final uri = Uri.tryParse(candidate);
      final token = _normalizeDirectToken(uri?.queryParameters['token']);
      if (token != null) {
        return token;
      }
    }

    final queryTokenMatch = _tokenQueryPattern.firstMatch(normalizedInput);
    final queryToken = _normalizeDirectToken(queryTokenMatch?.group(1));
    if (queryToken != null) {
      return queryToken;
    }

    final jwtMatch = _jwtPattern.firstMatch(normalizedInput);
    return _normalizeDirectToken(jwtMatch?.group(0));
  }

  void _applyToken(String? token) {
    _token = _normalizeToken(token);
    _currentUserId = _parseUidFromJwt(_token);
  }

  String? _normalizeDirectToken(String? token) {
    final normalized = _normalizeToken(token);
    if (normalized == null) {
      return null;
    }

    final stripped = normalized.replaceFirst(_bearerPrefixPattern, '').trim();
    final jwtMatch = _jwtPattern.firstMatch(stripped);
    if (jwtMatch == null || jwtMatch.group(0) != stripped) {
      return null;
    }
    if (_parseUidFromJwt(stripped) == null) {
      return null;
    }
    return stripped;
  }

  String? _extractTokenFromJson(String rawInput) {
    try {
      final decoded = jsonDecode(rawInput);
      if (decoded is Map<String, dynamic>) {
        final token = decoded['token'];
        if (token is String) {
          return _normalizeDirectToken(token);
        }
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  String? _normalizeToken(String? token) {
    final normalized = token?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  int? _parseUidFromJwt(String? token) {
    if (token == null) {
      return null;
    }

    final parts = token.split('.');
    if (parts.length < 2) {
      return null;
    }

    try {
      final payload = base64Url.decode(base64Url.normalize(parts[1]));
      final decoded = jsonDecode(utf8.decode(payload));
      if (decoded is! Map<String, dynamic>) {
        return null;
      }

      final uid = decoded['uid'];
      if (uid is int) {
        return uid;
      }
      if (uid is String) {
        return int.tryParse(uid);
      }
    } catch (_) {
      return null;
    }

    return null;
  }
}
