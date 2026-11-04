import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/garmin_account.dart';
import '../models/measurement.dart';
import '../models/user_profile.dart';
import 'garmin_client.dart';
import 'garmin_fit.dart';

class GarminSyncResult {
  const GarminSyncResult({
    required this.uploaded,
    required this.alreadySynced,
    required this.failed,
    this.firstError,
  });

  final int uploaded;
  final int alreadySynced;
  final int failed;
  final String? firstError;

  bool get hadFailures => failed > 0;
}

/// Persistence boundary for the Garmin session and per-account sync markers.
abstract class GarminStorage {
  Future<GarminAccount?> loadAccount();

  Future<void> saveAccount(GarminAccount account);

  Future<void> clearAccount();

  Future<Map<String, Set<int>>> loadSynced();

  Future<void> saveSynced(Map<String, Set<int>> synced);
}

/// Garmin tokens live in the platform keychain/keystore. The synced-reading
/// markers are not sensitive and stay in shared preferences.
class SecureGarminStorage implements GarminStorage {
  SecureGarminStorage({FlutterSecureStorage? secureStorage})
    : _secure = secureStorage ?? const FlutterSecureStorage();

  static const _accountKey = 'garmin_account_v1';
  static const _syncedKey = 'garmin_synced_v1';

  final FlutterSecureStorage _secure;

  @override
  Future<GarminAccount?> loadAccount() async {
    final raw = await _secure.read(key: _accountKey);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return GarminAccount.fromJson(Map<String, dynamic>.from(decoded));
    } catch (_) {
      await clearAccount();
      return null;
    }
  }

  @override
  Future<void> saveAccount(GarminAccount account) =>
      _secure.write(key: _accountKey, value: jsonEncode(account.toJson()));

  @override
  Future<void> clearAccount() => _secure.delete(key: _accountKey);

  @override
  Future<Map<String, Set<int>>> loadSynced() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_syncedKey);
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      final result = <String, Set<int>>{};
      decoded.forEach((key, value) {
        if (key is String && value is List) {
          result[key] = {
            for (final item in value)
              if (item is num) item.toInt(),
          };
        }
      });
      return result;
    } catch (_) {
      return {};
    }
  }

  @override
  Future<void> saveSynced(Map<String, Set<int>> synced) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = <String, List<int>>{
      for (final entry in synced.entries)
        entry.key: entry.value.toList()..sort(),
    };
    await prefs.setString(_syncedKey, jsonEncode(encoded));
  }
}

/// Orchestrates sign-in, token refresh, FIT creation and duplicate-free
/// uploads. UI code only needs to call [connect], [completeMfa], [sync] and
/// [disconnect].
class GarminService {
  GarminService({GarminApi? client, GarminStorage? storage})
    : _client = client ?? GarminClient(),
      _storage = storage ?? SecureGarminStorage();

  final GarminApi _client;
  final GarminStorage _storage;

  GarminAccount? _account;
  Map<String, Set<int>> _syncedByEmail = {};

  GarminAccount? get account => _account;

  bool get connected => _account != null;

  int pendingCount(List<Measurement> history) =>
      history.where((measurement) => !isSynced(measurement)).length;

  bool isSynced(Measurement measurement) {
    final email = _account?.email;
    if (email == null) return false;
    return _syncedFor(email).contains(_key(measurement));
  }

  Future<void> load() async {
    _account = await _storage.loadAccount();
    _syncedByEmail = await _storage.loadSynced();
  }

  Future<GarminLoginResult> connect({
    required String email,
    required String password,
  }) async {
    final result = await _client.login(email: email, password: password);
    final account = result.account;
    if (account != null) {
      await _storeAccount(account);
    }
    return result;
  }

  Future<GarminAccount> completeMfa(String code) async {
    final account = await _client.completeMfa(code);
    await _storeAccount(account);
    return account;
  }

  Future<void> disconnect() async {
    await _storage.clearAccount();
    _account = null;
  }

  Future<GarminSyncResult> sync({
    required List<Measurement> history,
    UserProfile? profile,
    void Function(int completed, int total)? onProgress,
  }) async {
    final account = _account;
    if (account == null) {
      throw const GarminException(
        GarminFailureKind.unauthorized,
        'Connect Garmin before syncing readings.',
      );
    }

    final ordered = [...history]
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final pending = ordered
        .where((measurement) => !isSynced(measurement))
        .toList();
    final alreadySynced = ordered.length - pending.length;
    if (pending.isEmpty) {
      return GarminSyncResult(
        uploaded: 0,
        alreadySynced: alreadySynced,
        failed: 0,
      );
    }

    var current = account;
    if (current.expiresSoon()) {
      try {
        current = await _client.refresh(current);
        await _saveAccount(current);
      } on GarminException catch (error) {
        if (error.kind == GarminFailureKind.unauthorized) {
          _account = null;
          try {
            await _storage.clearAccount();
          } catch (_) {
            // Keep the reconnect error actionable.
          }
        }
        rethrow;
      }
    }

    var uploaded = 0;
    var failed = 0;
    String? firstError;
    onProgress?.call(0, pending.length);

    for (var index = 0; index < pending.length; index++) {
      final measurement = pending[index];
      try {
        final reading = buildGarminFitReading(measurement, profile);
        final fitFile = encodeGarminWeightFit(reading);
        final outcome = await _client.uploadWeightFit(
          account: current,
          fitFile: fitFile,
          filename: _fitFilename(measurement),
        );
        current = outcome.account;
        await _saveAccount(current);
        _syncedFor(current.email).add(_key(measurement));
        await _persistSynced();
        uploaded++;
      } on GarminException catch (error) {
        if (error.kind == GarminFailureKind.unauthorized) {
          _account = null;
          try {
            await _storage.clearAccount();
          } catch (_) {
            // The in-memory session is already gone; a storage failure should
            // not replace the actionable reconnect error.
          }
          rethrow;
        }
        failed++;
        firstError ??= error.message;
      } catch (_) {
        failed++;
        firstError ??= 'One reading could not be sent.';
      }
      onProgress?.call(index + 1, pending.length);
    }

    return GarminSyncResult(
      uploaded: uploaded,
      alreadySynced: alreadySynced,
      failed: failed,
      firstError: firstError,
    );
  }

  Future<void> _storeAccount(GarminAccount account) async {
    await _storage.saveAccount(account);
    _account = account;
    _syncedFor(account.email);
    await _persistSynced();
  }

  Future<void> _saveAccount(GarminAccount account) async {
    await _storage.saveAccount(account);
    _account = account;
  }

  Set<int> _syncedFor(String email) =>
      _syncedByEmail.putIfAbsent(_emailKey(email), () => <int>{});

  Future<void> _persistSynced() => _storage.saveSynced(_syncedByEmail);

  static String _emailKey(String email) => email.trim().toLowerCase();

  static int _key(Measurement measurement) =>
      measurement.timestamp.microsecondsSinceEpoch;

  static String _fitFilename(Measurement measurement) {
    final time = measurement.timestamp;
    String two(int value) => value.toString().padLeft(2, '0');
    return 'body_composition_${time.year}${two(time.month)}${two(time.day)}'
        '_${two(time.hour)}${two(time.minute)}${two(time.second)}.fit';
  }
}

/// Converts an app measurement into the values Garmin's weight-scale FIT
/// message understands. Body composition is only estimated when impedance and
/// a valid profile are available; otherwise the file contains weight/BMI only.
GarminFitReading buildGarminFitReading(
  Measurement measurement,
  UserProfile? profile,
) {
  GarminFitUserProfile? userProfile;
  if (profile != null && profile.valid) {
    userProfile = GarminFitUserProfile(
      sex: profile.sex,
      ageYears: profile.ageYears,
      heightCm: profile.heightCm,
    );
  }
  final metrics = measurement.estimatesFor(profile);

  final bmi =
      measurement.bmi ??
      (profile != null && profile.valid
          ? measurement.weightKg / math.pow(profile.heightCm / 100, 2)
          : null);

  return GarminFitReading(
    timestamp: measurement.timestamp,
    weightKg: measurement.weightKg,
    bodyFatPercent: measurement.bodyFatPercent ?? metrics?.fatPercent,
    waterPercent: metrics?.waterPercent,
    boneMassKg: metrics?.boneMassKg,
    muscleMassKg: metrics?.muscleMassKg,
    visceralFatRating: metrics?.visceralFatRating,
    physiqueRating: metrics?.physiqueRating,
    metabolicAge: metrics?.metabolicAge,
    bmi: bmi,
    profile: userProfile,
  );
}
