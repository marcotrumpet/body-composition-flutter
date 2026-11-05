import 'dart:async';
import 'dart:convert';

import 'package:body_composition_flutter/main.dart';
import 'package:body_composition_flutter/models/garmin_account.dart';
import 'package:body_composition_flutter/models/measurement.dart';
import 'package:body_composition_flutter/models/user_profile.dart';
import 'package:body_composition_flutter/services/garmin_client.dart';
import 'package:body_composition_flutter/services/garmin_service.dart';
import 'package:body_composition_flutter/services/scale_ble.dart';
import 'package:body_composition_flutter/ui/body_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/garmin_fakes.dart';

const _historyKey = 'measurements_v1';
const _email = 'rider@example.com';

final _now = DateTime(2026, 11, 4, 9, 41);
const _nowFilename = 'body_composition_20261104_094100.fit';

GarminAccount _account({DateTime? expiresAt}) => GarminAccount(
  email: _email,
  accessToken: 'access',
  refreshToken: 'refresh',
  clientId: 'client',
  accessTokenExpiresAt: expiresAt ?? DateTime(2100),
);

Measurement _reading(DateTime timestamp) => Measurement(
  timestamp: timestamp,
  weightKg: 72.4,
  impedance: 512,
  bmi: 23.6,
  bodyFatPercent: 21.3,
);

class _Harness {
  const _Harness(this.scale, this.api, this.storage, this.garmin);

  final _FakeScale scale;
  final FakeGarminApi api;
  final FakeGarminStorage storage;
  final GarminService garmin;
}

/// Pumps the real dashboard with the scale and Garmin network faked out.
/// [rawHistory] stores unreadable history, which makes saving a reading fail.
Future<_Harness> _pumpDashboard(
  WidgetTester tester, {
  GarminAccount? account,
  bool connected = true,
  List<Measurement> stored = const [],
  String? rawHistory,
}) async {
  tester.view.physicalSize = const Size(800, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  SharedPreferences.setMockInitialValues({
    if (rawHistory != null)
      _historyKey: rawHistory
    else if (stored.isNotEmpty)
      _historyKey: jsonEncode(stored.map((item) => item.toJson()).toList()),
  });

  final scale = _FakeScale();
  final api = FakeGarminApi(_account());
  final storage = FakeGarminStorage()
    ..account = connected ? account ?? _account() : null;
  final garmin = GarminService(client: api, storage: storage);

  await tester.pumpWidget(
    MaterialApp(
      theme: BodyTheme.light(),
      home: Dashboard(scale: scale, garminService: garmin),
    ),
  );
  await tester.pumpAndSettle();
  return _Harness(scale, api, storage, garmin);
}

/// Makes the next [MeasurementStore.save] fail, or succeed again.
Future<void> _setHistoryReadable(bool readable) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_historyKey, readable ? '[]' : 'not json');
}

Future<void> _openProfile(WidgetTester tester) async {
  await tester.tap(find.text('Profile'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a reading stays on the device when Garmin is not connected', (
    tester,
  ) async {
    final harness = await _pumpDashboard(tester, connected: false);

    harness.scale.emitReading(_reading(_now));
    await tester.pumpAndSettle();

    expect(find.text('Reading saved'), findsOneWidget);
    expect(find.text('Syncing with Garmin'), findsNothing);
    expect(harness.api.uploads, isEmpty);
  });

  testWidgets('a reading uploads as the last measuring step', (tester) async {
    final gate = Completer<void>();
    final harness = await _pumpDashboard(tester);
    harness.api.uploadGate = gate;

    harness.scale.emitReading(_reading(_now));
    await tester.pumpAndSettle();

    expect(find.text('Reading saved'), findsOneWidget);
    expect(find.text('Syncing with Garmin'), findsOneWidget);
    expect(find.text('Syncing'), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsNWidgets(3));
    expect(harness.api.uploads, hasLength(1));

    gate.complete();
    await tester.pumpAndSettle();

    expect(find.text('Syncing with Garmin'), findsNothing);
    expect(find.text('Reading saved'), findsNothing);
    expect(find.text('Reading saved and sent to Garmin'), findsOneWidget);
    // The hints from the saved notice stay, because they describe what was sent.
    expect(
      find.textContaining('Add your profile to estimate body fat.'),
      findsOneWidget,
    );

    await _openProfile(tester);
    expect(find.text('All readings are synced.'), findsOneWidget);
  });

  testWidgets('only the new reading uploads and Sync sends an older one', (
    tester,
  ) async {
    final harness = await _pumpDashboard(
      tester,
      stored: [_reading(_now.subtract(const Duration(days: 1)))],
    );

    harness.scale.emitReading(_reading(_now));
    await tester.pumpAndSettle();

    expect(harness.api.uploads.single.filename, _nowFilename);

    await _openProfile(tester);
    await tester.tap(find.text('Sync 1 reading'));
    await tester.pumpAndSettle();

    expect(harness.api.uploads, hasLength(2));
    expect(find.text('Sent to Garmin'), findsOneWidget);
    expect(find.text('All readings are synced.'), findsOneWidget);
  });

  testWidgets('a failed upload keeps the reading and Try again resends it', (
    tester,
  ) async {
    final harness = await _pumpDashboard(tester);
    harness.api.nextUploadError = const GarminException(
      GarminFailureKind.rateLimited,
      'Garmin is limiting uploads right now.',
    );

    harness.scale.emitReading(_reading(_now));
    await tester.pumpAndSettle();

    expect(find.text('Reading saved, not sent to Garmin'), findsOneWidget);
    expect(find.text('Garmin is limiting uploads right now.'), findsOneWidget);
    expect(find.text('Syncing with Garmin'), findsNothing);

    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(find.text('Reading saved and sent to Garmin'), findsOneWidget);
    expect(harness.api.uploads, hasLength(2));
  });

  testWidgets('being offline when the token needs refreshing says the '
      'reading is safe', (tester) async {
    final harness = await _pumpDashboard(
      tester,
      account: _account(expiresAt: DateTime(2020)),
    );
    harness.api.nextRefreshError = const GarminException(
      GarminFailureKind.network,
      "Couldn't reach Garmin. Check your connection and try again.",
    );

    harness.scale.emitReading(_reading(_now));
    await tester.pumpAndSettle();

    expect(find.text('Reading saved, not sent to Garmin'), findsOneWidget);
    expect(
      find.text("Couldn't reach Garmin. Check your connection and try again."),
      findsOneWidget,
    );
    expect(harness.api.uploads, isEmpty);

    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(find.text('Reading saved and sent to Garmin'), findsOneWidget);
    expect(harness.api.uploads, hasLength(1));
  });

  testWidgets('Reconnect after an expired session sends the reading', (
    tester,
  ) async {
    final harness = await _pumpDashboard(tester);
    harness.api.nextUploadError = const GarminException(
      GarminFailureKind.unauthorized,
      'Garmin session expired. Reconnect your account.',
    );

    harness.scale.emitReading(_reading(_now));
    await tester.pumpAndSettle();

    expect(find.text('Garmin session expired'), findsOneWidget);
    expect(harness.storage.account, isNull);

    await tester.tap(find.text('Reconnect'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, _email);
    await tester.enterText(find.byType(TextFormField).last, 'secret');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Reading saved and sent to Garmin'), findsOneWidget);
    expect(harness.api.uploads, hasLength(2));
  });

  testWidgets('a reading that arrives during a sync uploads after it', (
    tester,
  ) async {
    final gate = Completer<void>();
    final harness = await _pumpDashboard(
      tester,
      stored: [_reading(_now.subtract(const Duration(days: 1)))],
    );
    harness.api.uploadGate = gate;

    await _openProfile(tester);
    await tester.tap(find.text('Sync 1 reading'));
    await tester.pumpAndSettle();
    expect(find.text('Uploading 0 of 1…'), findsOneWidget);

    harness.scale.emitReading(_reading(_now));
    await tester.pumpAndSettle();
    expect(harness.api.uploads, hasLength(1));

    gate.complete();
    await tester.pumpAndSettle();

    expect(harness.api.uploads, hasLength(2));
    expect(harness.api.uploads.last.filename, _nowFilename);
    expect(find.text('Reading saved and sent to Garmin'), findsOneWidget);
    expect(find.text('All readings are synced.'), findsOneWidget);
  });

  testWidgets('a manual weight uploads without the measuring step', (
    tester,
  ) async {
    final gate = Completer<void>();
    final harness = await _pumpDashboard(tester);
    harness.api.uploadGate = gate;

    await tester.tap(find.text('Add weight manually'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '72,4');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Weight added'), findsOneWidget);
    expect(find.text('Syncing with Garmin'), findsNothing);
    expect(harness.api.uploads, hasLength(1));

    gate.complete();
    await tester.pumpAndSettle();

    expect(find.text('Weight added and sent to Garmin'), findsOneWidget);
  });

  testWidgets('a reading that could not be saved is not uploaded', (
    tester,
  ) async {
    final harness = await _pumpDashboard(tester, rawHistory: 'not json');

    harness.scale.emitReading(_reading(_now));
    await tester.pumpAndSettle();

    expect(find.text('Reading received but not saved'), findsOneWidget);
    expect(find.text('Syncing with Garmin'), findsNothing);
    expect(harness.api.uploads, isEmpty);
  });

  testWidgets('a reading uploads once Try again saves it', (tester) async {
    final harness = await _pumpDashboard(tester, rawHistory: 'not json');

    harness.scale.emitReading(_reading(_now));
    await tester.pumpAndSettle();

    await _setHistoryReadable(true);
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(find.text('Reading saved and sent to Garmin'), findsOneWidget);
    expect(harness.api.uploads, hasLength(1));
  });

  testWidgets('a Garmin result does not replace the retry for an unsaved '
      'reading', (tester) async {
    final gate = Completer<void>();
    final harness = await _pumpDashboard(tester);
    harness.api.uploadGate = gate;

    harness.scale.emitReading(_reading(_now));
    await tester.pumpAndSettle();

    await _setHistoryReadable(false);
    harness.scale.emitReading(_reading(_now.add(const Duration(minutes: 1))));
    await tester.pumpAndSettle();
    expect(find.text('Reading received but not saved'), findsOneWidget);

    gate.complete();
    await tester.pumpAndSettle();

    expect(find.text('Reading received but not saved'), findsOneWidget);
    expect(find.text('Reading saved and sent to Garmin'), findsNothing);

    harness.api.uploadGate = null;
    await _setHistoryReadable(true);
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(find.text('Reading saved and sent to Garmin'), findsOneWidget);
    expect(harness.api.uploads, hasLength(2));
  });

  group('disconnecting behind an upload', () {
    Finder confirmDisconnect() => find.descendant(
      of: find.byType(AlertDialog),
      matching: find.text('Disconnect'),
    );

    /// Opens the confirmation, then starts an upload behind it and confirms.
    Future<(_Harness, Completer<void>)> disconnectDuringUpload(
      WidgetTester tester,
    ) async {
      final gate = Completer<void>();
      final harness = await _pumpDashboard(tester);
      harness.api.uploadGate = gate;

      await _openProfile(tester);
      await tester.tap(find.text('Disconnect'));
      await tester.pumpAndSettle();
      expect(find.text('Disconnect Garmin?'), findsOneWidget);

      harness.scale.emitReading(_reading(_now));
      await tester.pumpAndSettle();
      expect(harness.api.uploads, hasLength(1));

      await tester.tap(confirmDisconnect());
      await tester.pumpAndSettle();
      return (harness, gate);
    }

    testWidgets('waits for the upload and stays disconnected', (tester) async {
      final (harness, gate) = await disconnectDuringUpload(tester);
      expect(harness.garmin.connected, isTrue);

      gate.complete();
      await tester.pumpAndSettle();

      expect(harness.garmin.connected, isFalse);
      expect(harness.storage.account, isNull);
      expect(find.text('Garmin disconnected'), findsOneWidget);
      expect(find.text('Connect Garmin'), findsOneWidget);
    });

    testWidgets('a reading queued after it does not upload or reconnect', (
      tester,
    ) async {
      final (harness, gate) = await disconnectDuringUpload(tester);

      harness.scale.emitReading(_reading(_now.add(const Duration(minutes: 1))));
      await tester.pumpAndSettle();

      gate.complete();
      await tester.pumpAndSettle();

      expect(harness.api.uploads, hasLength(1));
      expect(harness.garmin.connected, isFalse);
      expect(harness.storage.account, isNull);
      expect(find.text('Connect Garmin'), findsOneWidget);
      // The disconnect was deliberate, so the queued reading must not report
      // an expired session over it.
      expect(find.text('Garmin disconnected'), findsOneWidget);
      expect(find.text('Garmin session expired'), findsNothing);
    });
  });

  group('Sync on the profile tab', () {
    testWidgets('reports a partial failure and Try again sends the rest', (
      tester,
    ) async {
      final harness = await _pumpDashboard(
        tester,
        stored: [
          _reading(_now.subtract(const Duration(days: 2))),
          _reading(_now.subtract(const Duration(days: 1))),
        ],
      );
      harness.api.nextUploadError = const GarminException(
        GarminFailureKind.uploadRejected,
        'Garmin rejected the reading.',
      );

      await _openProfile(tester);
      await tester.tap(find.text('Sync 2 readings'));
      await tester.pumpAndSettle();

      expect(find.text('Some readings were not sent'), findsOneWidget);
      expect(find.text('Sync 1 reading'), findsOneWidget);

      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(find.text('Sent to Garmin'), findsOneWidget);
      expect(find.text('All readings are synced.'), findsOneWidget);
    });

    testWidgets('offers Reconnect when the session has expired', (
      tester,
    ) async {
      final harness = await _pumpDashboard(
        tester,
        stored: [_reading(_now.subtract(const Duration(days: 1)))],
      );
      harness.api.nextUploadError = const GarminException(
        GarminFailureKind.unauthorized,
        'Garmin session expired. Reconnect your account.',
      );

      await _openProfile(tester);
      await tester.tap(find.text('Sync 1 reading'));
      await tester.pumpAndSettle();

      expect(find.text('Garmin session expired'), findsOneWidget);
      expect(find.text('Connect Garmin'), findsOneWidget);

      await tester.tap(find.text('Reconnect'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, _email);
      await tester.enterText(find.byType(TextFormField).last, 'secret');
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();

      // Sync is a manual action, so it stays a tap away rather than resuming.
      expect(find.text('Garmin connected'), findsOneWidget);
      expect(find.text('Sync 1 reading'), findsOneWidget);
      expect(harness.api.uploads, hasLength(1));
    });

    testWidgets('does not show the measuring card', (tester) async {
      final gate = Completer<void>();
      final harness = await _pumpDashboard(
        tester,
        stored: [_reading(_now.subtract(const Duration(days: 1)))],
      );
      harness.api.uploadGate = gate;

      await _openProfile(tester);
      await tester.tap(find.text('Sync 1 reading'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();
      expect(find.text('Syncing with Garmin'), findsNothing);

      gate.complete();
      await tester.pumpAndSettle();
    });
  });

  testWidgets(
    'a new scan can start during the upload and shows its own steps',
    (tester) async {
      final gate = Completer<void>();
      final harness = await _pumpDashboard(tester);
      harness.api.uploadGate = gate;

      harness.scale.emitReading(_reading(_now));
      await tester.pumpAndSettle();
      expect(find.text('Syncing with Garmin'), findsOneWidget);

      await tester.tap(find.text('Measure on scale'));
      await tester.pumpAndSettle();
      expect(find.text('Looking for your scale'), findsOneWidget);
      expect(find.text('Syncing with Garmin'), findsNothing);

      await tester.tap(find.text('Stop measuring'));
      await tester.pumpAndSettle();
      expect(find.text('Syncing with Garmin'), findsOneWidget);

      gate.complete();
      await tester.pumpAndSettle();

      expect(find.text('Syncing with Garmin'), findsNothing);
      expect(find.text('Reading saved and sent to Garmin'), findsOneWidget);
    },
  );
}

class _FakeScale implements ScaleBle {
  final _measurements = StreamController<Measurement>.broadcast();
  final _phases = StreamController<ScalePhase>.broadcast();
  final _failures = StreamController<ScaleFailure>.broadcast();

  void emitReading(Measurement value) => _measurements.add(value);

  @override
  Stream<Measurement> get measurements => _measurements.stream;

  @override
  Stream<ScalePhase> get phases => _phases.stream;

  @override
  Stream<ScaleFailure> get failures => _failures.stream;

  @override
  ScalePhase get phase => ScalePhase.idle;

  @override
  Future<void> scanAndConnect({UserProfile? profile}) async {}

  @override
  Future<void> cancel() async {}

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> dispose() async {
    await _measurements.close();
    await _phases.close();
    await _failures.close();
  }
}
