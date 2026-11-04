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
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
          ),
          child: DashboardView(
            history: history,
            profile: profile,
            loadingHistory: loadingHistory,
            loadingProfile: loadingProfile,
            phase: phase,
            notice: notice,
            onMeasure: () {},
            onManual: () {},
            onProfile: () {},
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

  testWidgets('populated home shows measurements with one decimal',
      (tester) async {
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

  testWidgets('a raw impedance reading without a profile asks for one',
      (tester) async {
    await _pumpDashboard(
      tester,
      history: [
        _measurement(
          timestamp: now,
          bmi: null,
          bodyFatPercent: null,
        ),
      ],
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

  testWidgets('trends shows chart, source labels and semantics summary',
      (tester) async {
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

  testWidgets('one reading explains that the trend needs another reading',
      (tester) async {
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
