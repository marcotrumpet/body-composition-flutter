import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../models/garmin_account.dart';

enum GarminFailureKind {
  invalidCredentials,
  mfaFailed,
  rateLimited,
  blocked,
  network,
  unauthorized,
  uploadRejected,
  unexpected,
}

class GarminException implements Exception {
  const GarminException(this.kind, this.message, {this.cause});

  final GarminFailureKind kind;
  final String message;
  final Object? cause;

  bool get requiresReconnect =>
      kind == GarminFailureKind.unauthorized ||
      kind == GarminFailureKind.invalidCredentials;

  @override
  String toString() => message;
}

class GarminMfaChallenge {
  const GarminMfaChallenge({required this.method});

  /// Garmin's `mfaLastMethodUsed` value, usually `email` or `sms`.
  final String method;
}

class GarminLoginResult {
  const GarminLoginResult.connected(this.account) : challenge = null;
  const GarminLoginResult.mfaRequired(this.challenge) : account = null;

  final GarminAccount? account;
  final GarminMfaChallenge? challenge;

  bool get requiresMfa => challenge != null;
}

class GarminUploadOutcome {
  const GarminUploadOutcome({
    required this.account,
    this.uploadId,
    this.duplicate = false,
  });

  final GarminAccount account;
  final int? uploadId;
  final bool duplicate;
}

/// Network surface used by [GarminService]. Kept as an interface so tests can
/// exercise sync orchestration without HTTP.
abstract class GarminApi {
  Future<GarminLoginResult> login({
    required String email,
    required String password,
  });

  Future<GarminAccount> completeMfa(String code);

  Future<GarminAccount> refresh(GarminAccount account);

  Future<GarminUploadOutcome> uploadWeightFit({
    required GarminAccount account,
    required Uint8List fitFile,
    required String filename,
  });
}

/// Talks to Garmin Connect's own mobile sign-in and upload services. The flow
/// mirrors the current community Garmin clients: mobile SSO ticket, DI OAuth2
/// bearer token, then a multipart FIT upload.
class GarminClient implements GarminApi {
  GarminClient({
    http.Client? httpClient,
    Future<void> Function(Duration) delay = _defaultDelay,
    Duration minLoginDelay = const Duration(seconds: 2),
    Duration maxLoginDelay = const Duration(seconds: 5),
    Random? random,
    Duration timeout = const Duration(seconds: 30),
  }) : _http = httpClient ?? http.Client(),
       _delay = delay,
       _minLoginDelay = minLoginDelay,
       _maxLoginDelay = maxLoginDelay,
       _random = random ?? Random.secure(),
       _timeout = timeout;

  static Future<void> _defaultDelay(Duration duration) =>
      Future<void>.delayed(duration);

  static const _iosClientId = 'GCM_IOS_DARK';
  static const _iosService = 'https://mobile.integration.garmin.com/gcm/ios';
  static const _ssoOrigin = 'https://sso.garmin.com';
  static const _signInUrl = 'https://sso.garmin.com/mobile/sso/en_US/sign-in';
  static const _loginUrl = 'https://sso.garmin.com/mobile/api/login';
  static const _mfaUrl = 'https://sso.garmin.com/mobile/api/mfa/verifyCode';
  static const _tokenUrl =
      'https://diauth.garmin.com/di-oauth2-service/oauth/token';
  static const _uploadUrl =
      'https://connectapi.garmin.com/upload-service/upload/.fit';
  static const _grantType =
      'https://connectapi.garmin.com/di-oauth2-service/oauth/grant/service_ticket';
  static const _iosLoginUserAgent =
      'Mozilla/5.0 (iPhone; CPU iPhone OS 18_7 like Mac OS X) '
      'AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148';
  static const _uploadUserAgent = 'GCM-iOS-5.7.2.1';
  static const _nativeUserAgent = 'GCM-Android-5.23';
  static const _nativeXUserAgent =
      'com.garmin.android.apps.connectmobile/5.23; ; '
      'Google/sdk_gphone64_arm64/google; Android/33; Dalvik/2.1.0';
  static const _nativeHeaders = {
    'User-Agent': _nativeUserAgent,
    'X-Garmin-User-Agent': _nativeXUserAgent,
    'X-Garmin-Paired-App-Version': '10861',
    'X-Garmin-Client-Platform': 'Android',
    'X-App-Ver': '10861',
    'X-Lang': 'en',
    'X-GCExperience': 'GC5',
    'Accept-Language': 'en-US,en;q=0.9',
  };
  static const _clientIds = [
    'GARMIN_CONNECT_MOBILE_ANDROID_DI_2025Q2',
    'GARMIN_CONNECT_MOBILE_ANDROID_DI_2024Q4',
    'GARMIN_CONNECT_MOBILE_ANDROID_DI',
    'GARMIN_CONNECT_MOBILE_IOS_DI',
  ];

  final http.Client _http;
  final Future<void> Function(Duration) _delay;
  final Duration _minLoginDelay;
  final Duration _maxLoginDelay;
  final Random _random;
  final Duration _timeout;

  final Map<String, String> _cookies = {};
  _PendingMfa? _pendingMfa;

  @override
  Future<GarminLoginResult> login({
    required String email,
    required String password,
  }) async {
    _cookies.clear();
    _pendingMfa = null;

    final signInUri = Uri.parse(_signInUrl).replace(
      queryParameters: {'clientId': _iosClientId, 'service': _iosService},
    );

    final page = await _getFollowingRedirects(
      signInUri,
      headers: const {
        'User-Agent': _iosLoginUserAgent,
        'Accept':
            'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.9',
      },
    );
    _ensureLoginPageResponse(page, 'sign-in page');

    await _pauseBeforeLogin();

    final loginUri = Uri.parse(_loginUrl).replace(
      queryParameters: {
        'clientId': _iosClientId,
        'locale': 'en-US',
        'service': _iosService,
      },
    );
    final headers = {
      'User-Agent': _iosLoginUserAgent,
      'Accept': 'application/json, text/plain, */*',
      'Accept-Language': 'en-US,en;q=0.9',
      'Content-Type': 'application/json',
      'Origin': _ssoOrigin,
      'Referer': signInUri.toString(),
    };
    final response = await _postJson(loginUri, {
      'username': email,
      'password': password,
      'rememberMe': true,
      'captchaToken': '',
    }, headers: headers);
    _ensureNotBlocked(response, 'Garmin sign-in');
    if (response.statusCode == 401) {
      throw const GarminException(
        GarminFailureKind.invalidCredentials,
        "Garmin didn't accept that email or password.",
      );
    }

    final json = _decodeJson(response, 'Garmin sign-in');
    final type = _responseStatusType(json);
    switch (type) {
      case 'SUCCESSFUL':
        final ticket = _stringValue(json['serviceTicketId']);
        if (ticket == null || ticket.isEmpty) {
          throw const GarminException(
            GarminFailureKind.unexpected,
            'Garmin sign-in finished without a session ticket. Try again.',
          );
        }
        return GarminLoginResult.connected(
          await _exchangeTicket(ticket, email),
        );
      case 'MFA_REQUIRED':
        final method =
            _stringValue(
              _mapValue(json['customerMfaInfo'])?['mfaLastMethodUsed'],
            ) ??
            'email';
        _pendingMfa = _PendingMfa(
          email: email,
          method: method,
          queryParameters: {
            'clientId': _iosClientId,
            'locale': 'en-US',
            'service': _iosService,
          },
          headers: headers,
        );
        return GarminLoginResult.mfaRequired(
          GarminMfaChallenge(method: method),
        );
      case 'INVALID_USERNAME_PASSWORD':
        throw const GarminException(
          GarminFailureKind.invalidCredentials,
          "Garmin didn't accept that email or password.",
        );
      case 'CAPTCHA_REQUIRED':
        throw const GarminException(
          GarminFailureKind.blocked,
          'Garmin wants a browser verification before signing in. '
          'Try again later.',
        );
      default:
        _throwIfJsonRateLimited(json, 'Garmin sign-in');
        throw GarminException(
          GarminFailureKind.unexpected,
          'Garmin sign-in failed (${type ?? 'unknown response'}).',
        );
    }
  }

  @override
  Future<GarminAccount> completeMfa(String code) async {
    final pending = _pendingMfa;
    if (pending == null) {
      throw const GarminException(
        GarminFailureKind.unexpected,
        'Start Garmin sign-in again before entering a verification code.',
      );
    }

    final uri = Uri.parse(
      _mfaUrl,
    ).replace(queryParameters: pending.queryParameters);
    final response = await _postJson(uri, {
      'mfaMethod': pending.method,
      'mfaVerificationCode': code,
      'rememberMyBrowser': true,
      'reconsentList': <Object>[],
      'mfaSetup': false,
    }, headers: pending.headers);
    _ensureNotBlocked(response, 'Garmin verification');
    if (response.statusCode == 401) {
      throw const GarminException(
        GarminFailureKind.mfaFailed,
        "Garmin didn't accept that verification code.",
      );
    }

    final json = _decodeJson(response, 'Garmin verification');
    if (_responseStatusType(json) != 'SUCCESSFUL') {
      _throwIfJsonRateLimited(json, 'Garmin verification');
      throw const GarminException(
        GarminFailureKind.mfaFailed,
        "Garmin didn't accept that verification code.",
      );
    }

    final ticket = _stringValue(json['serviceTicketId']);
    if (ticket == null || ticket.isEmpty) {
      throw const GarminException(
        GarminFailureKind.unexpected,
        'Garmin verification finished without a session ticket. Try again.',
      );
    }

    final account = await _exchangeTicket(ticket, pending.email);
    _pendingMfa = null;
    return account;
  }

  @override
  Future<GarminAccount> refresh(GarminAccount account) async {
    if (!account.canRefresh) {
      throw const GarminException(
        GarminFailureKind.unauthorized,
        'Garmin session expired. Reconnect your account.',
      );
    }

    final response = await _postForm(Uri.parse(_tokenUrl), {
      'grant_type': 'refresh_token',
      'client_id': account.clientId,
      'refresh_token': account.refreshToken,
    }, headers: _tokenHeaders(account.clientId));

    if (response.statusCode == 429) {
      throw const GarminException(
        GarminFailureKind.rateLimited,
        'Garmin is limiting requests right now. Try again in a few minutes.',
      );
    }
    if (response.statusCode == 400 || response.statusCode == 401) {
      throw const GarminException(
        GarminFailureKind.unauthorized,
        'Garmin session expired. Reconnect your account.',
      );
    }
    if (response.statusCode == 403) {
      throw const GarminException(
        GarminFailureKind.blocked,
        'Garmin blocked the request. Try again later.',
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw GarminException(
        GarminFailureKind.unexpected,
        'Garmin session refresh failed (HTTP ${response.statusCode}).',
      );
    }

    final json = _decodeJson(response, 'Garmin session refresh');
    final accessToken = _stringValue(json['access_token']);
    if (accessToken == null || accessToken.isEmpty) {
      throw const GarminException(
        GarminFailureKind.unauthorized,
        'Garmin session expired. Reconnect your account.',
      );
    }
    final expiresIn = _intValue(json['expires_in']) ?? 3600;
    return account.copyWith(
      accessToken: accessToken,
      refreshToken: _stringValue(json['refresh_token']) ?? account.refreshToken,
      accessTokenExpiresAt: DateTime.now().add(
        Duration(seconds: expiresIn > 0 ? expiresIn : 3600),
      ),
    );
  }

  @override
  Future<GarminUploadOutcome> uploadWeightFit({
    required GarminAccount account,
    required Uint8List fitFile,
    required String filename,
  }) async {
    var current = account;
    if (current.expiresSoon()) {
      current = await refresh(current);
    }

    for (var attempt = 0; attempt < 2; attempt++) {
      final request = http.MultipartRequest('POST', Uri.parse(_uploadUrl));
      request.headers.addAll({
        ..._nativeHeaders,
        'Authorization': 'Bearer ${current.accessToken}',
        'Accept': 'application/json',
        'NK': 'NT',
        'origin': _ssoOrigin,
        'User-Agent': _uploadUserAgent,
      });
      request.files.add(
        http.MultipartFile.fromBytes('file', fitFile, filename: filename),
      );

      final response = await _send(request);

      if (response.statusCode == 401 && attempt == 0 && current.canRefresh) {
        current = await refresh(current);
        continue;
      }
      if (response.statusCode == 401) {
        throw const GarminException(
          GarminFailureKind.unauthorized,
          'Garmin session expired. Reconnect your account.',
        );
      }
      if (response.statusCode == 403) {
        throw const GarminException(
          GarminFailureKind.blocked,
          'Garmin blocked the upload. Try again later.',
        );
      }
      if (response.statusCode == 429) {
        throw const GarminException(
          GarminFailureKind.rateLimited,
          'Garmin is limiting uploads right now. Try again in a few minutes.',
        );
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw GarminException(
          GarminFailureKind.uploadRejected,
          'Garmin rejected the reading (HTTP ${response.statusCode}).',
        );
      }

      return _parseUploadResponse(response, current);
    }

    throw const GarminException(
      GarminFailureKind.unauthorized,
      'Garmin session expired. Reconnect your account.',
    );
  }

  Future<GarminAccount> _exchangeTicket(String ticket, String email) async {
    GarminException? lastFailure;
    for (final clientId in _clientIds) {
      final response = await _postForm(
        Uri.parse(_tokenUrl),
        {
          'client_id': clientId,
          'service_ticket': ticket,
          'grant_type': _grantType,
          'service_url': _iosService,
        },
        headers: _tokenHeaders(
          clientId,
          accept: 'application/json,text/html;q=0.9,*/*;q=0.8',
        ),
      );

      if (response.statusCode == 429) {
        throw const GarminException(
          GarminFailureKind.rateLimited,
          'Garmin is limiting sign-ins right now. Try again in a few minutes.',
        );
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        lastFailure = GarminException(
          GarminFailureKind.unexpected,
          'Garmin sign-in could not be completed (HTTP ${response.statusCode}).',
        );
        continue;
      }

      final json = _tryDecodeJson(response);
      final accessToken = _stringValue(json?['access_token']);
      if (accessToken == null || accessToken.isEmpty) {
        lastFailure = const GarminException(
          GarminFailureKind.unexpected,
          'Garmin sign-in could not be completed. Try again.',
        );
        continue;
      }

      final expiresIn = _intValue(json?['expires_in']) ?? 3600;
      return GarminAccount(
        email: email,
        accessToken: accessToken,
        refreshToken: _stringValue(json?['refresh_token']) ?? '',
        clientId: clientId,
        accessTokenExpiresAt: DateTime.now().add(
          Duration(seconds: expiresIn > 0 ? expiresIn : 3600),
        ),
      );
    }

    throw lastFailure ??
        const GarminException(
          GarminFailureKind.unexpected,
          'Garmin sign-in could not be completed. Try again.',
        );
  }

  Map<String, String> _tokenHeaders(
    String clientId, {
    String accept = 'application/json',
  }) {
    final basic = base64Encode(utf8.encode('$clientId:'));
    return {
      ..._nativeHeaders,
      'Authorization': 'Basic $basic',
      'Accept': accept,
      'Content-Type': 'application/x-www-form-urlencoded',
      'Cache-Control': 'no-cache',
    };
  }

  GarminUploadOutcome _parseUploadResponse(
    http.Response response,
    GarminAccount account,
  ) {
    final json = _tryDecodeJson(response);
    if (json == null) {
      return GarminUploadOutcome(account: account);
    }

    final result = _mapValue(json['detailedImportResult']);
    if (result == null) {
      return GarminUploadOutcome(account: account);
    }

    final messages = <String>[];
    var duplicate = false;
    var rejected = false;
    for (final failure in _listValue(result['failures'])) {
      final failureMap = _mapValue(failure);
      for (final message in _listValue(failureMap?['messages'])) {
        final messageMap = _mapValue(message);
        final code = _intValue(messageMap?['code']);
        final content = _stringValue(messageMap?['content']);
        if (code == 202) {
          duplicate = true;
        } else {
          rejected = true;
        }
        if (content != null && content.isNotEmpty) messages.add(content);
      }
    }

    if (rejected) {
      throw GarminException(
        GarminFailureKind.uploadRejected,
        messages.isEmpty ? 'Garmin rejected the reading.' : messages.join(' '),
      );
    }

    final uploadId = _intValue(result['uploadId']);
    return GarminUploadOutcome(
      account: account,
      uploadId: uploadId,
      duplicate: duplicate,
    );
  }

  Future<http.Response> _getFollowingRedirects(
    Uri uri, {
    Map<String, String> headers = const {},
  }) async {
    var current = uri;
    for (var hop = 0; hop <= 5; hop++) {
      final request = http.Request('GET', current)..followRedirects = false;
      request.headers.addAll(headers);
      _addCookies(request);
      final response = await _send(request);

      if (_isRedirect(response.statusCode)) {
        final location = response.headers['location'];
        if (location == null || location.isEmpty || hop == 5) {
          break;
        }
        current = current.resolve(location);
        continue;
      }
      return response;
    }

    throw const GarminException(
      GarminFailureKind.unexpected,
      'Garmin redirected the sign-in page too many times. Try again.',
    );
  }

  Future<http.Response> _postJson(
    Uri uri,
    Map<String, Object?> body, {
    Map<String, String> headers = const {},
  }) async {
    final request = http.Request('POST', uri)..followRedirects = false;
    request.headers.addAll(headers);
    request.headers['Content-Type'] = 'application/json';
    _addCookies(request);
    request.body = jsonEncode(body);
    return _send(request);
  }

  Future<http.Response> _postForm(
    Uri uri,
    Map<String, String> body, {
    Map<String, String> headers = const {},
  }) async {
    final request = http.Request('POST', uri)..followRedirects = false;
    request.headers.addAll(headers);
    request.headers.putIfAbsent(
      'Content-Type',
      () => 'application/x-www-form-urlencoded',
    );
    _addCookies(request);
    request.body = Uri(queryParameters: body).query;
    return _send(request);
  }

  Future<http.Response> _send(http.BaseRequest request) async {
    try {
      final streamed = await _http.send(request).timeout(_timeout);
      final response = await http.Response.fromStream(streamed);
      _captureCookies(response);
      return response;
    } on TimeoutException catch (error) {
      throw GarminException(
        GarminFailureKind.network,
        "Garmin didn't respond in time. Check your connection and try again.",
        cause: error,
      );
    } on http.ClientException catch (error) {
      throw GarminException(
        GarminFailureKind.network,
        "Couldn't reach Garmin. Check your connection and try again.",
        cause: error,
      );
    }
  }

  void _captureCookies(http.BaseResponse response) {
    final values =
        response.headersSplitValues['set-cookie'] ?? const <String>[];
    for (final raw in values) {
      final pair = raw.split(';').first;
      final separator = pair.indexOf('=');
      if (separator <= 0) continue;
      final name = pair.substring(0, separator).trim();
      final value = pair.substring(separator + 1).trim();
      if (name.isEmpty) continue;
      if (value.isEmpty || value == 'deleted') {
        _cookies.remove(name);
      } else {
        _cookies[name] = value;
      }
    }
  }

  void _addCookies(http.BaseRequest request) {
    if (_cookies.isEmpty) return;
    request.headers['Cookie'] = _cookies.entries
        .map((entry) => '${entry.key}=${entry.value}')
        .join('; ');
  }

  void _ensureLoginPageResponse(http.Response response, String label) {
    if (response.statusCode == 429) {
      throw GarminException(
        GarminFailureKind.rateLimited,
        'Garmin is limiting sign-ins right now. Try again in a few minutes.',
      );
    }
    if (response.statusCode == 403) {
      throw const GarminException(
        GarminFailureKind.blocked,
        'Garmin blocked the sign-in page. Try again later.',
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw GarminException(
        GarminFailureKind.unexpected,
        'Garmin $label returned HTTP ${response.statusCode}.',
      );
    }
  }

  void _ensureNotBlocked(http.Response response, String label) {
    if (response.statusCode == 429) {
      throw GarminException(
        GarminFailureKind.rateLimited,
        '$label is rate limited right now. Try again in a few minutes.',
      );
    }
    if (response.statusCode == 403) {
      throw GarminException(
        GarminFailureKind.blocked,
        '$label was blocked by Garmin. Try again later.',
      );
    }
  }

  Future<void> _pauseBeforeLogin() async {
    final minMs = _minLoginDelay.inMilliseconds;
    final maxMs = _maxLoginDelay.inMilliseconds;
    final span = maxMs - minMs;
    final ms = span <= 0 ? minMs : minMs + _random.nextInt(span + 1);
    if (ms > 0) {
      await _delay(Duration(milliseconds: ms));
    }
  }

  static bool _isRedirect(int status) =>
      status == 301 ||
      status == 302 ||
      status == 303 ||
      status == 307 ||
      status == 308;

  static Map<String, dynamic> _decodeJson(
    http.Response response,
    String label,
  ) {
    final decoded = _tryDecodeJson(response);
    if (decoded == null) {
      throw GarminException(
        GarminFailureKind.unexpected,
        '$label returned an unreadable response (HTTP ${response.statusCode}).',
      );
    }
    return decoded;
  }

  static Map<String, dynamic>? _tryDecodeJson(http.Response response) {
    if (response.bodyBytes.isEmpty) return null;
    try {
      final value = jsonDecode(utf8.decode(response.bodyBytes));
      return value is Map<String, dynamic> ? value : null;
    } catch (_) {
      return null;
    }
  }

  static String? _responseStatusType(Map<String, dynamic> json) =>
      _stringValue(_mapValue(json['responseStatus'])?['type']);

  static void _throwIfJsonRateLimited(Map<String, dynamic> json, String label) {
    final status = _stringValue(_mapValue(json['error'])?['status-code']);
    if (status == '429') {
      throw GarminException(
        GarminFailureKind.rateLimited,
        '$label is rate limited right now. Try again in a few minutes.',
      );
    }
  }

  static Map<String, dynamic>? _mapValue(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  static List<Object?> _listValue(Object? value) =>
      value is List ? value : const [];

  static String? _stringValue(Object? value) {
    if (value is String) return value;
    if (value is num) return value.toString();
    return null;
  }

  static int? _intValue(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}

class _PendingMfa {
  const _PendingMfa({
    required this.email,
    required this.method,
    required this.queryParameters,
    required this.headers,
  });

  final String email;
  final String method;
  final Map<String, String> queryParameters;
  final Map<String, String> headers;
}
