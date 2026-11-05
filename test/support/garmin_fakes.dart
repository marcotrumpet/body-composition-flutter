import 'dart:async';
import 'dart:typed_data';

import 'package:body_composition_flutter/models/garmin_account.dart';
import 'package:body_composition_flutter/services/garmin_client.dart';
import 'package:body_composition_flutter/services/garmin_service.dart';

class UploadedFile {
  const UploadedFile(this.filename, this.bytes);

  final String filename;
  final Uint8List bytes;
}

class FakeGarminApi implements GarminApi {
  FakeGarminApi(this.account);

  GarminAccount account;
  GarminException? nextUploadError;
  GarminException? nextRefreshError;
  GarminMfaChallenge? mfaChallenge;

  /// When set, uploads stay in flight until it completes.
  Completer<void>? uploadGate;

  /// Every attempted upload, including ones that go on to fail.
  final List<UploadedFile> uploads = [];

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
    uploads.add(UploadedFile(filename, fitFile));
    await uploadGate?.future;
    final error = nextUploadError;
    if (error != null) {
      nextUploadError = null;
      throw error;
    }
    return GarminUploadOutcome(account: account, uploadId: uploads.length);
  }
}

class FakeGarminStorage implements GarminStorage {
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
