import 'dart:typed_data';

import 'package:body_composition_flutter/models/garmin_account.dart';
import 'package:body_composition_flutter/models/measurement.dart';
import 'package:body_composition_flutter/models/user_profile.dart';
import 'package:body_composition_flutter/services/garmin_client.dart';
import 'package:body_composition_flutter/services/garmin_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const profile = UserProfile(heightCm: 175, ageYears: 35, sex: 'male');

  GarminAccount account(String email) => GarminAccount(
    email: email,
    accessToken: 'access',
    refreshToken: 'refresh',
    clientId: 'client',
    accessTokenExpiresAt: DateTime.now().add(const Duration(hours: 1)),
  );

  Measurement measurement(DateTime timestamp, {double weightKg = 72.4}) {
    return Measurement(
      timestamp: timestamp,
      weightKg: weightKg,
      impedance: 512,
      bmi: 23.6,
      bodyFatPercent: 21.3,
    );
  }

  test('connect stores the account and loads its sync markers', () async {
    final api = _FakeApi(account('user@example.com'));
    final storage = _FakeStorage();
    final service = GarminService(client: api, storage: storage);

    final result = await service.connect(
      email: 'user@example.com',
      password: 'secret',
    );

    expect(result.requiresMfa, isFalse);
    expect(service.connected, isTrue);
    expect(storage.account?.email, 'user@example.com');
    expect(storage.account?.accessToken, 'access');
  });

  test('connect reports MFA and completeMfa stores the account', () async {
    final api = _FakeApi(account('user@example.com'))
      ..mfaChallenge = const GarminMfaChallenge(method: 'email');
    final storage = _FakeStorage();
    final service = GarminService(client: api, storage: storage);

    final result = await service.connect(
      email: 'user@example.com',
      password: 'secret',
    );

    expect(result.requiresMfa, isTrue);
    expect(service.connected, isFalse);
    expect(storage.account, isNull);

    final authorized = await service.completeMfa('123456');

    expect(authorized.email, 'user@example.com');
    expect(service.connected, isTrue);
    expect(storage.account?.email, 'user@example.com');
  });

  test(
    'sync uploads only unsynced readings oldest first and marks them',
    () async {
      final api = _FakeApi(account('user@example.com'));
      final storage = _FakeStorage();
      final old = measurement(DateTime(2026, 11, 1, 9));
      final middle = measurement(DateTime(2026, 11, 2, 9), weightKg: 72.2);
      final newest = measurement(DateTime(2026, 11, 3, 9), weightKg: 72.0);

      storage.synced['user@example.com'] = {
        newest.timestamp.microsecondsSinceEpoch,
      };
      final service = GarminService(client: api, storage: storage);
      await service.load();
      await service.connect(email: 'user@example.com', password: 'secret');

      final progress = <List<int>>[];
      final result = await service.sync(
        history: [newest, old, middle],
        profile: profile,
        onProgress: (completed, total) => progress.add([completed, total]),
      );

      expect(result.uploaded, 2);
      expect(result.alreadySynced, 1);
      expect(result.failed, 0);
      expect(api.uploads, hasLength(2));
      expect(api.uploads[0].filename, startsWith('body_composition_20261101'));
      expect(api.uploads[1].filename, startsWith('body_composition_20261102'));
      expect(progress, [
        [0, 2],
        [1, 2],
        [2, 2],
      ]);
      expect(service.pendingCount([old, middle, newest]), 0);
      expect(storage.synced['user@example.com'], hasLength(3));
    },
  );

  test(
    'sync clears a stored account whose refresh token is rejected',
    () async {
      final expired = GarminAccount(
        email: 'user@example.com',
        accessToken: 'old',
        refreshToken: 'old-refresh',
        clientId: 'client',
        accessTokenExpiresAt: DateTime.now().subtract(const Duration(hours: 1)),
      );
      final storage = _FakeStorage()..account = expired;
      final api = _FakeApi(expired)
        ..nextRefreshError = const GarminException(
          GarminFailureKind.unauthorized,
          'expired',
        );
      final service = GarminService(client: api, storage: storage);
      await service.load();

      await expectLater(
        service.sync(
          history: [measurement(DateTime(2026, 11, 1, 9))],
          profile: profile,
        ),
        throwsA(isA<GarminException>()),
      );

      expect(service.connected, isFalse);
      expect(storage.account, isNull);
    },
  );

  test('sync clears the session when Garmin rejects the token', () async {
    final api = _FakeApi(account('user@example.com'));
    api.nextUploadError = const GarminException(
      GarminFailureKind.unauthorized,
      'expired',
    );
    final storage = _FakeStorage();
    final service = GarminService(client: api, storage: storage);
    await service.load();
    await service.connect(email: 'user@example.com', password: 'secret');

    await expectLater(
      service.sync(
        history: [measurement(DateTime(2026, 11, 1, 9))],
        profile: profile,
      ),
      throwsA(isA<GarminException>()),
    );

    expect(service.connected, isFalse);
    expect(storage.account, isNull);
  });

  test('sync returns partial results without aborting', () async {
    final api = _FakeApi(account('user@example.com'));
    api.nextUploadError = const GarminException(
      GarminFailureKind.uploadRejected,
      'Garmin rejected the reading.',
    );
    final storage = _FakeStorage();
    final service = GarminService(client: api, storage: storage);
    await service.load();
    await service.connect(email: 'user@example.com', password: 'secret');

    final result = await service.sync(
      history: [
        measurement(DateTime(2026, 11, 1, 9)),
        measurement(DateTime(2026, 11, 2, 9)),
      ],
      profile: profile,
    );

    expect(result.uploaded, 1);
    expect(result.failed, 1);
    expect(result.hadFailures, isTrue);
    expect(result.firstError, contains('rejected'));
  });

  test('sync markers are kept per Garmin account', () async {
    final storage = _FakeStorage();
    final firstApi = _FakeApi(account('first@example.com'));
    final first = GarminService(client: firstApi, storage: storage);
    await first.load();
    await first.connect(email: 'first@example.com', password: 'secret');
    final reading = measurement(DateTime(2026, 11, 1, 9));
    await first.sync(history: [reading], profile: profile);
    expect(first.pendingCount([reading]), 0);

    final secondApi = _FakeApi(account('second@example.com'));
    final second = GarminService(client: secondApi, storage: storage);
    await second.load();
    await second.connect(email: 'second@example.com', password: 'secret');

    expect(second.pendingCount([reading]), 1);
  });

  test('loading restores a stored account and markers', () async {
    final storage = _FakeStorage()
      ..account = account('user@example.com')
      ..synced = {
        'user@example.com': {123},
      };
    final service = GarminService(
      client: _FakeApi(account('x')),
      storage: storage,
    );

    await service.load();

    expect(service.connected, isTrue);
    expect(service.account?.email, 'user@example.com');
  });

  test('buildGarminFitReading derives composition when possible', () {
    final reading = buildGarminFitReading(
      Measurement(
        timestamp: DateTime(2026, 11, 1, 9),
        weightKg: 72.4,
        impedance: 512,
      ),
      profile,
    );

    expect(reading.profile, isNotNull);
    expect(reading.bmi, closeTo(23.6408, 0.0001));
    expect(reading.bodyFatPercent, closeTo(21.3321, 0.0001));
    expect(reading.waterPercent, closeTo(53.9661, 0.0001));
    expect(reading.boneMassKg, closeTo(2.8989, 0.0001));
    expect(reading.muscleMassKg, closeTo(54.0567, 0.0001));
    expect(reading.visceralFatRating, closeTo(11.6060, 0.0001));
    expect(reading.metabolicAge, closeTo(30.9242, 0.0001));
    expect(reading.physiqueRating, 4);
  });

  test('buildGarminFitReading sends weight only without a profile', () {
    final reading = buildGarminFitReading(
      Measurement(
        timestamp: DateTime(2026, 11, 1, 9),
        weightKg: 72.4,
        impedance: 512,
        bmi: 23.6,
      ),
      null,
    );

    expect(reading.profile, isNull);
    expect(reading.weightKg, 72.4);
    expect(reading.bmi, 23.6);
    expect(reading.bodyFatPercent, isNull);
    expect(reading.waterPercent, isNull);
    expect(reading.visceralFatRating, isNull);
  });
}

class _UploadedFile {
  const _UploadedFile(this.filename, this.bytes);

  final String filename;
  final Uint8List bytes;
}

class _FakeApi implements GarminApi {
  _FakeApi(this.account);

  GarminAccount account;
  GarminException? nextUploadError;
  GarminException? nextRefreshError;
  GarminMfaChallenge? mfaChallenge;
  final List<_UploadedFile> uploads = [];

  @override
  Future<GarminLoginResult> login({
    required String email,
    required String password,
  }) async {
    if (mfaChallenge != null) {
      return GarminLoginResult.mfaRequired(mfaChallenge!);
    }
    return GarminLoginResult.connected(account);
  }

  @override
  Future<GarminAccount> completeMfa(String code) async => account;

  @override
  Future<GarminAccount> refresh(GarminAccount account) async {
    final error = nextRefreshError;
    if (error != null) {
      nextRefreshError = null;
      throw error;
    }
    return account;
  }

  @override
  Future<GarminUploadOutcome> uploadWeightFit({
    required GarminAccount account,
    required Uint8List fitFile,
    required String filename,
  }) async {
    uploads.add(_UploadedFile(filename, fitFile));
    final error = nextUploadError;
    if (error != null) {
      nextUploadError = null;
      throw error;
    }
    return GarminUploadOutcome(account: account, uploadId: uploads.length);
  }
}

class _FakeStorage implements GarminStorage {
  GarminAccount? account;
  Map<String, Set<int>> synced = {};

  @override
  Future<GarminAccount?> loadAccount() async => account;

  @override
  Future<void> saveAccount(GarminAccount account) async {
    this.account = account;
  }

  @override
  Future<void> clearAccount() async {
    account = null;
  }

  @override
  Future<Map<String, Set<int>>> loadSynced() async => {
    for (final entry in synced.entries) entry.key: {...entry.value},
  };

  @override
  Future<void> saveSynced(Map<String, Set<int>> synced) async {
    this.synced = {
      for (final entry in synced.entries) entry.key: {...entry.value},
    };
  }
}
