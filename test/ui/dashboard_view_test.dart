import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:body_composition_flutter/models/garmin_account.dart';
import 'package:body_composition_flutter/models/measurement.dart';
import 'package:body_composition_flutter/models/user_profile.dart';
import 'package:body_composition_flutter/services/scale_ble.dart';
import 'package:body_composition_flutter/ui/body_theme.dart';
import 'package:body_composition_flutter/ui/body_tokens.dart';
import 'package:body_composition_flutter/ui/dashboard_view.dart';
import 'package:body_composition_flutter/ui/widgets/body_surface.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _profile = UserProfile(heightCm: 175, ageYears: 35, sex: 'male');

Measurement _measurement({
  required DateTime timestamp,
  double weightKg = 72.4,
  int? impedance = 512,
  double? bmi = 22.3,
  double? bodyFatPercent = 18.2,
}) {
  return Measurement(
    timestamp: timestamp,
    weightKg: weightKg,
    impedance: impedance,
    bmi: bmi,
    bodyFatPercent: bodyFatPercent,
  );
}

Future<void> _pumpDashboard(
  WidgetTester tester, {
  required List<Measurement> history,
  UserProfile? profile,
  bool loadingHistory = false,
  bool loadingProfile = false,
  ScalePhase phase = ScalePhase.idle,
  DashboardNotice? notice,
  ThemeData? theme,
  double textScale = 1,
  Size surfaceSize = const Size(800, 1200),
  GarminAccount? garminAccount,
  bool garminLoading = false,
  bool garminBusy = false,
  int garminPendingReadings = 0,
  int? garminSyncCompleted,
  int? garminSyncTotal,
  VoidCallback? onGarminConnect,
  VoidCallback? onGarminSync,
  VoidCallback? onGarminDisconnect,
  VoidCallback? onProfile,
}) async {
  tester.view.physicalSize = surfaceSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      theme: theme ?? BodyTheme.light(),
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: DashboardView(
            history: history,
            profile: profile,
            loadingHistory: loadingHistory,
            loadingProfile: loadingProfile,
            phase: phase,
            notice: notice,
            onMeasure: () {},
            onManual: () {},
            onProfile: onProfile ?? () {},
            garminAccount: garminAccount,
            garminLoading: garminLoading,
            garminBusy: garminBusy,
            garminPendingReadings: garminPendingReadings,
            garminSyncCompleted: garminSyncCompleted,
            garminSyncTotal: garminSyncTotal,
            onGarminConnect: onGarminConnect,
            onGarminSync: onGarminSync,
            onGarminDisconnect: onGarminDisconnect,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  final now = DateTime(2026, 11, 4, 9, 41);

  testWidgets('empty state explains how to start', (tester) async {
    await _pumpDashboard(tester, history: []);

    expect(find.text('No readings yet'), findsWidgets);
    expect(find.text('Ready for your first reading'), findsOneWidget);
    expect(find.text('Measure on scale'), findsOneWidget);
    expect(find.text('Add weight manually'), findsOneWidget);
    expect(find.text('Add a profile for estimates'), findsOneWidget);
  });

  testWidgets('populated home shows measurements with one decimal', (
    tester,
  ) async {
    final history = [
      _measurement(timestamp: now),
      _measurement(
        timestamp: now.subtract(const Duration(days: 2)),
        weightKg: 72.1,
        impedance: 515,
        bmi: 22.2,
        bodyFatPercent: 18.4,
      ),
    ];
    await _pumpDashboard(tester, history: history, profile: _profile);

    expect(find.text('72.4'), findsOneWidget);
    expect(find.text('72.40'), findsNothing);
    expect(find.textContaining('BMI 22.3'), findsOneWidget);
    expect(find.text('Body fat'), findsOneWidget);
    expect(find.text('18.2%'), findsOneWidget);
    expect(find.text('512 Ω'), findsOneWidget);
    expect(find.textContaining('0.3 kg above'), findsOneWidget);
    expect(find.text('Add a profile for estimates'), findsNothing);
  });

  testWidgets('the native tab bar never minimizes while scrolling', (
    tester,
  ) async {
    await _pumpDashboard(tester, history: []);

    final scaffold = tester.widget<AdaptiveScaffold>(
      find.byType(AdaptiveScaffold),
    );
    expect(scaffold.minimizeBehavior, TabBarMinimizeBehavior.never);
  });

  testWidgets('the Set up profile action is wired to the profile editor', (
    tester,
  ) async {
    var taps = 0;
    await _pumpDashboard(tester, history: [], onProfile: () => taps++);

    await tester.tap(find.text('Set up profile'));
    await tester.pumpAndSettle();

    expect(taps, 1);
  });

  testWidgets('derived body metrics populate from a scale reading', (
    tester,
  ) async {
    await _pumpDashboard(
      tester,
      history: [_measurement(timestamp: now)],
      profile: _profile,
    );

    expect(find.text('Muscle mass'), findsOneWidget);
    expect(find.text('54.1 kg'), findsOneWidget);
    expect(find.text('Body water'), findsOneWidget);
    expect(find.text('54.0%'), findsOneWidget);
    expect(find.text('Bone mass'), findsOneWidget);
    expect(find.text('2.9 kg'), findsOneWidget);
    expect(find.text('Visceral fat'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('Metabolic age'), findsOneWidget);
    expect(find.text('31 yrs'), findsOneWidget);
  });

  testWidgets('metric tiles survive a manual-only reading', (tester) async {
    final history = [
      _measurement(
        timestamp: now,
        impedance: null,
        bmi: null,
        bodyFatPercent: null,
      ),
      _measurement(
        timestamp: now.subtract(const Duration(days: 1)),
        weightKg: 72.1,
      ),
    ];
    await _pumpDashboard(tester, history: history, profile: _profile);

    expect(find.text('18.2%'), findsOneWidget);
    expect(find.text('512 Ω'), findsOneWidget);
    expect(find.textContaining('From '), findsNWidgets(2));
  });

  testWidgets('a raw impedance reading without a profile asks for one', (
    tester,
  ) async {
    await _pumpDashboard(
      tester,
      history: [_measurement(timestamp: now, bmi: null, bodyFatPercent: null)],
    );

    expect(find.text('Add a profile'), findsOneWidget);
    expect(
      find.textContaining('Add your profile to estimate body fat'),
      findsOneWidget,
    );
    expect(find.text('512 Ω'), findsOneWidget);
  });

  testWidgets('notices are displayed with recovery actions', (tester) async {
    await _pumpDashboard(
      tester,
      history: [],
      notice: DashboardNotice(
        tone: NoticeTone.danger,
        title: 'No scale found',
        message: 'Wake the scale and try again.',
        actionLabel: 'Try again',
        onAction: () {},
      ),
    );

    expect(find.text('No scale found'), findsOneWidget);
    expect(find.text('Wake the scale and try again.'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('scanning card follows the BLE phase', (tester) async {
    await _pumpDashboard(
      tester,
      history: [],
      phase: ScalePhase.waitingForReading,
    );

    expect(find.text('Step on the scale'), findsOneWidget);
    expect(
      find.text('Stand still with bare feet until the reading is saved.'),
      findsOneWidget,
    );
    expect(find.text('Stop measuring'), findsOneWidget);
    expect(find.text('Looking'), findsOneWidget);
    expect(find.text('Connecting'), findsOneWidget);
    expect(find.text('Reading'), findsOneWidget);
  });

  testWidgets('trends shows chart, source labels and semantics summary', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final history = [
      _measurement(timestamp: now),
      _measurement(
        timestamp: now.subtract(const Duration(days: 2)),
        weightKg: 72.1,
        impedance: null,
        bmi: null,
        bodyFatPercent: null,
      ),
    ];
    await _pumpDashboard(tester, history: history, profile: _profile);

    await tester.tap(find.text('Trends'));
    await tester.pumpAndSettle();

    expect(find.text('Weight trend'), findsOneWidget);
    expect(find.text('RECENT READINGS'), findsOneWidget);
    expect(find.textContaining('Scale reading'), findsOneWidget);
    expect(find.textContaining('Manual entry'), findsOneWidget);
    expect(find.byType(LineChart), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp('Weight trend, 2 readings')),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('one reading explains that the trend needs another reading', (
    tester,
  ) async {
    await _pumpDashboard(
      tester,
      history: [_measurement(timestamp: now)],
      profile: _profile,
    );

    await tester.tap(find.text('Trends'));
    await tester.pumpAndSettle();

    expect(
      find.text('Your trend will appear after your next reading.'),
      findsOneWidget,
    );
    expect(find.byType(LineChart), findsNothing);
  });

  testWidgets('profile tab capitalizes sex and shows units', (tester) async {
    await _pumpDashboard(tester, history: [], profile: _profile);

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();

    expect(find.text('Your profile'), findsOneWidget);
    expect(find.text('175 cm'), findsOneWidget);
    expect(find.text('35 years'), findsOneWidget);
    expect(find.text('Male'), findsOneWidget);
    expect(find.text('Edit profile'), findsOneWidget);
  });

  testWidgets('profile tab invites a Garmin connection when signed out', (
    tester,
  ) async {
    await _pumpDashboard(tester, history: [], profile: _profile);

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();

    expect(find.text('Garmin Connect'), findsOneWidget);
    expect(
      find.textContaining('Send weight and body-composition readings'),
      findsOneWidget,
    );
    expect(find.text('Connect Garmin'), findsOneWidget);
  });

  testWidgets('profile tab shows Garmin account and pending readings', (
    tester,
  ) async {
    await _pumpDashboard(
      tester,
      history: [_measurement(timestamp: now)],
      profile: _profile,
      garminAccount: GarminAccount(
        email: 'rider@example.com',
        accessToken: 'access',
        refreshToken: 'refresh',
        clientId: 'client',
        accessTokenExpiresAt: DateTime(2030),
      ),
      garminPendingReadings: 2,
      onGarminSync: () {},
      onGarminDisconnect: () {},
    );

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();

    expect(find.text('Connected'), findsOneWidget);
    expect(find.text('rider@example.com'), findsOneWidget);
    expect(find.text('Sync 2 readings'), findsOneWidget);
    expect(find.text('Disconnect'), findsOneWidget);
    expect(find.textContaining('2 readings are ready to send'), findsOneWidget);
  });

  testWidgets('Garmin sync progress is announced on the profile tab', (
    tester,
  ) async {
    await _pumpDashboard(
      tester,
      history: [_measurement(timestamp: now)],
      profile: _profile,
      garminAccount: GarminAccount(
        email: 'rider@example.com',
        accessToken: 'access',
        refreshToken: 'refresh',
        clientId: 'client',
        accessTokenExpiresAt: DateTime(2030),
      ),
      garminBusy: true,
      garminSyncCompleted: 1,
      garminSyncTotal: 3,
      onGarminSync: () {},
      onGarminDisconnect: () {},
    );

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();

    expect(find.text('Uploading 1 of 3…'), findsOneWidget);
    expect(find.text('Syncing…'), findsOneWidget);
  });

  testWidgets('profile tab reports when all readings are synced', (
    tester,
  ) async {
    await _pumpDashboard(
      tester,
      history: [_measurement(timestamp: now)],
      profile: _profile,
      garminAccount: GarminAccount(
        email: 'rider@example.com',
        accessToken: 'access',
        refreshToken: 'refresh',
        clientId: 'client',
        accessTokenExpiresAt: DateTime(2030),
      ),
      garminPendingReadings: 0,
      onGarminSync: () {},
      onGarminDisconnect: () {},
    );

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();

    expect(find.text('All readings are synced.'), findsOneWidget);
    expect(find.text('Sync readings'), findsOneWidget);
  });

  testWidgets('dark theme uses the dark ink palette', (tester) async {
    await _pumpDashboard(
      tester,
      history: [_measurement(timestamp: now)],
      profile: _profile,
      theme: BodyTheme.dark(),
    );

    final weight = tester.widget<Text>(find.text('72.4'));
    expect(weight.style?.color, BodyColors.dark.ink);
  });

  testWidgets('Garmin card wraps a long account email at large text scale', (
    tester,
  ) async {
    await _pumpDashboard(
      tester,
      history: [_measurement(timestamp: now)],
      profile: _profile,
      garminAccount: GarminAccount(
        email: 'a.very.long.garmin.account.address@example.com',
        accessToken: 'access',
        refreshToken: 'refresh',
        clientId: 'client',
        accessTokenExpiresAt: DateTime(2030),
      ),
      garminPendingReadings: 3,
      onGarminSync: () {},
      onGarminDisconnect: () {},
      textScale: 2,
      surfaceSize: const Size(320, 640),
    );

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('a.very.long.garmin.account.address@example.com'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();

    expect(
      find.text('a.very.long.garmin.account.address@example.com'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('320px wide at 2x text scale does not overflow', (tester) async {
    await _pumpDashboard(
      tester,
      history: [
        _measurement(timestamp: now),
        _measurement(
          timestamp: now.subtract(const Duration(days: 2)),
          weightKg: 72.1,
        ),
      ],
      profile: _profile,
      phase: ScalePhase.waitingForReading,
      theme: BodyTheme.dark(),
      textScale: 2,
      surfaceSize: const Size(320, 640),
    );

    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Trends'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
