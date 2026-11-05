import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'models/garmin_account.dart';
import 'models/measurement.dart';
import 'models/user_profile.dart';
import 'services/bluetooth_permissions.dart';
import 'services/garmin_client.dart';
import 'services/garmin_service.dart';
import 'services/measurement_store.dart';
import 'services/scale_ble.dart';
import 'ui/body_format.dart';
import 'ui/body_theme.dart';
import 'ui/body_tokens.dart';
import 'ui/dashboard_view.dart';
import 'ui/dialogs.dart';
import 'ui/garmin_dialogs.dart';
import 'ui/widgets/body_surface.dart';

void main() => runApp(const BodyCompositionApp());

class BodyCompositionApp extends StatelessWidget {
  const BodyCompositionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Body Composition',
      debugShowCheckedModeBanner: false,
      theme: BodyTheme.light(),
      darkTheme: BodyTheme.dark(),
      themeMode: ThemeMode.system,
      // AdaptiveScaffold owns the native toolbar and tab bar on iOS. Wrapping
      // this navigator in AdaptiveToolbarHost would place a fixed toolbar
      // above the Navigator, which stays visible over Cupertino sheets.
      //
      // Paint the app canvas behind the Navigator so Cupertino sheets, which
      // scale the previous route down, reveal the canvas instead of the
      // WidgetsApp default black background in the gap above them.
      builder: (context, child) => ColoredBox(
        color: BodyColors.of(context).canvas,
        child: CupertinoTheme(
          data: BodyTheme.cupertino(Theme.of(context).brightness),
          child: child!,
        ),
      ),
      home: const Dashboard(),
    );
  }
}

class Dashboard extends StatefulWidget {
  const Dashboard({super.key, this.scale, this.garminService});

  /// Test seams; the app uses the real services.
  final ScaleBle? scale;
  final GarminService? garminService;

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  final store = MeasurementStore();
  final profileStore = UserProfileStore();
  late final ble = widget.scale ?? ScaleBle();
  final bluetoothPermissions = BluetoothPermissions();
  late final garmin = widget.garminService ?? GarminService();

  List<Measurement> history = [];
  UserProfile? profile;
  bool loadingHistory = true;
  bool loadingProfile = true;
  ScalePhase phase = ScalePhase.idle;
  DashboardNotice? notice;
  GarminAccount? garminAccount;
  String? lastGarminEmail;
  bool loadingGarmin = true;
  bool garminBusy = false;
  bool garminSyncingReading = false;
  int garminSyncCompleted = 0;
  int garminSyncTotal = 0;

  Future<void> _garminQueue = Future<void>.value();
  Timer? _noticeTimer;
  StreamSubscription<Measurement>? _measurementSub;
  StreamSubscription<ScalePhase>? _phaseSub;
  StreamSubscription<ScaleFailure>? _failureSub;
  Measurement? _pendingSave;
  bool _handlingMeasurement = false;
  int _scanRequest = 0;
  Future<void>? _disconnecting;

  bool get scanning => phase != ScalePhase.idle;

  @override
  void initState() {
    super.initState();
    unawaited(_reload());
    unawaited(_loadProfile());
    unawaited(_loadGarmin());
    _measurementSub = ble.measurements.listen(
      (measurement) => unawaited(_onMeasurement(measurement)),
    );
    _phaseSub = ble.phases.listen((value) {
      if (!mounted) return;
      setState(() => phase = value);
    });
    _failureSub = ble.failures.listen(
      (failure) => unawaited(_onScaleFailure(failure)),
    );
  }

  Future<void> _reload() async {
    if (mounted) setState(() => loadingHistory = true);
    try {
      final items = await store.load();
      if (!mounted) return;
      setState(() {
        history = items;
        loadingHistory = false;
      });
    } on MeasurementStorageException {
      if (!mounted) return;
      setState(() => loadingHistory = false);
      _showNotice(
        DashboardNotice(
          tone: NoticeTone.danger,
          title: "Couldn't load saved readings",
          message: 'The saved history on this device is unreadable.',
          actionLabel: 'Reset history',
          onAction: () => unawaited(_confirmResetHistory()),
        ),
      );
    }
  }

  Future<void> _loadProfile() async {
    try {
      final value = await profileStore.load();
      if (!mounted) return;
      setState(() {
        profile = value;
        loadingProfile = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => loadingProfile = false);
    }
  }

  Future<void> _loadGarmin() async {
    try {
      await garmin.load();
    } catch (_) {
      // A keychain or preferences failure must not block the dashboard.
    }
    if (!mounted) return;
    setState(() {
      garminAccount = garmin.account;
      loadingGarmin = false;
    });
  }

  Future<void> _connectGarmin() async {
    if (garminBusy) return;
    final credentials = await showGarminLoginDialog(
      context,
      initialEmail: garminAccount?.email ?? lastGarminEmail,
    );
    if (credentials == null || !mounted) return;

    setState(() {
      lastGarminEmail = credentials.email;
      garminBusy = true;
      garminSyncCompleted = 0;
      garminSyncTotal = 0;
    });

    try {
      final result = await garmin.connect(
        email: credentials.email,
        password: credentials.password,
      );
      if (!mounted) return;

      if (result.requiresMfa) {
        final code = await showGarminMfaDialog(
          context,
          method: result.challenge!.method,
          email: credentials.email,
        );
        if (!mounted) return;
        if (code == null) {
          setState(() => garminBusy = false);
          return;
        }
        await garmin.completeMfa(code);
        if (!mounted) return;
      }

      setState(() {
        garminAccount = garmin.account;
        garminBusy = false;
      });
      final pending = garmin.pendingCount(history);
      _showNotice(
        DashboardNotice(
          tone: NoticeTone.success,
          title: 'Garmin connected',
          message: pending == 0
              ? 'Signed in as ${garminAccount!.email}.'
              : 'Signed in as ${garminAccount!.email}. $pending '
                    '${pending == 1 ? 'reading is' : 'readings are'} ready to sync.',
        ),
        autoDismiss: true,
      );
    } on GarminException catch (error) {
      if (!mounted) return;
      setState(() {
        garminBusy = false;
        garminAccount = garmin.account;
      });
      _showNotice(_garminNotice(error, retry: _connectGarmin));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        garminBusy = false;
        garminAccount = garmin.account;
      });
      _showNotice(
        DashboardNotice(
          tone: NoticeTone.danger,
          title: "Couldn't connect Garmin",
          message: 'Try again. If it keeps happening, restart the app.',
          actionLabel: 'Try again',
          onAction: () => unawaited(_connectGarmin()),
        ),
      );
    }
  }

  Future<void> _syncGarmin() async {
    if (garminBusy) return;
    if (garminAccount == null) {
      await _connectGarmin();
      return;
    }

    if (garmin.pendingCount(history) == 0) {
      _showNotice(
        const DashboardNotice(
          tone: NoticeTone.info,
          title: 'Everything is synced',
          message: 'New readings will appear here after your next measurement.',
        ),
        autoDismiss: true,
      );
      return;
    }

    await _enqueueGarmin(() async {
      if (garminAccount == null) return;
      final result = await _runGarminSync(
        history,
        retry: _syncGarmin,
        reconnect: _connectGarmin,
      );
      if (result == null) return;

      if (result.hadFailures) {
        final attempted = result.uploaded + result.failed;
        _showGarminNotice(
          DashboardNotice(
            tone: NoticeTone.danger,
            title: 'Some readings were not sent',
            message:
                '${result.uploaded} of $attempted readings reached Garmin. '
                '${result.firstError ?? ''}',
            actionLabel: 'Try again',
            onAction: () => unawaited(_syncGarmin()),
          ),
        );
      } else if (result.uploaded == 0) {
        _showGarminNotice(
          const DashboardNotice(
            tone: NoticeTone.info,
            title: 'Everything is synced',
            message: 'There were no new readings to send.',
          ),
          autoDismiss: true,
        );
      } else {
        _showGarminNotice(
          DashboardNotice(
            tone: NoticeTone.success,
            title: 'Sent to Garmin',
            message:
                '${result.uploaded} '
                '${result.uploaded == 1 ? 'reading was' : 'readings were'} '
                'uploaded to Garmin Connect.',
          ),
          autoDismiss: true,
        );
      }
    });
  }

  /// The last step of taking a reading: sends the saved [reading] to Garmin
  /// when an account is connected. Older unsent readings stay for Sync on the
  /// profile tab, so connecting an account never uploads a history unprompted.
  Future<void> _sendToGarmin(
    Measurement reading,
    DashboardNotice saved, {
    bool showStep = false,
  }) {
    Future<void> retry() => _sendToGarmin(reading, saved, showStep: showStep);
    final notSent = '${saved.title}, not sent to Garmin';

    return _enqueueGarmin(() async {
      // Checked when the task runs: a disconnect or an expired session may
      // have come first.
      if (garminAccount == null) return;
      final result = await _runGarminSync(
        [reading],
        showStep: showStep,
        failureTitle: notSent,
        retry: retry,
        reconnect: () async {
          await _connectGarmin();
          if (mounted && garminAccount != null) await retry();
        },
      );
      if (result == null) return;

      if (result.hadFailures) {
        _showGarminNotice(
          DashboardNotice(
            tone: NoticeTone.danger,
            title: notSent,
            message: result.firstError ?? 'Try again.',
            actionLabel: 'Try again',
            onAction: () => unawaited(retry()),
          ),
        );
      } else if (result.uploaded > 0) {
        _showGarminNotice(
          DashboardNotice(
            tone: NoticeTone.success,
            title: '${saved.title} and sent to Garmin',
            message: saved.message,
          ),
          autoDismiss: true,
        );
      }
    });
  }

  /// Runs Garmin work one task at a time. [GarminService.sync] writes the
  /// account back after each upload, so a disconnect has to queue behind
  /// uploads too.
  Future<void> _enqueueGarmin(Future<void> Function() task) {
    final run = _garminQueue.then<void>((_) async {
      if (mounted) await task();
    });
    // A task that throws must not stall the ones behind it.
    _garminQueue = run.catchError((Object _) {});
    return run;
  }

  /// Uploads [readings] and keeps the progress state in step with the run.
  /// Returns null when the run failed outright and a notice already says so.
  Future<GarminSyncResult?> _runGarminSync(
    List<Measurement> readings, {
    required Future<void> Function() retry,
    required Future<void> Function() reconnect,
    String? failureTitle,
    bool showStep = false,
  }) async {
    setState(() {
      garminBusy = true;
      garminSyncingReading = showStep;
      garminSyncCompleted = 0;
      garminSyncTotal = garmin.pendingCount(readings);
    });

    GarminSyncResult? result;
    DashboardNotice? failure;
    try {
      result = await garmin.sync(
        history: readings,
        profile: profile,
        onProgress: (completed, total) {
          if (!mounted) return;
          setState(() {
            garminSyncCompleted = completed;
            garminSyncTotal = total;
          });
        },
      );
    } on GarminException catch (error) {
      failure = _garminNotice(
        error,
        title: failureTitle,
        retry: error.requiresReconnect ? reconnect : retry,
      );
    } catch (_) {
      failure = DashboardNotice(
        tone: NoticeTone.danger,
        title: failureTitle ?? "Couldn't sync with Garmin",
        message: 'Try again. Readings that were sent will not be duplicated.',
        actionLabel: 'Try again',
        onAction: () => unawaited(retry()),
      );
    }
    if (!mounted) return null;
    setState(() {
      garminBusy = false;
      garminSyncingReading = false;
      garminAccount = garmin.account;
    });
    if (failure != null) _showGarminNotice(failure);
    return result;
  }

  /// Try again on an unsaved reading is the only way to keep it, so a Garmin
  /// result that lands while one is waiting must not replace that notice.
  void _showGarminNotice(DashboardNotice value, {bool autoDismiss = false}) {
    if (_pendingSave == null) _showNotice(value, autoDismiss: autoDismiss);
  }

  Future<void> _disconnectGarmin() async {
    if (garminBusy) return;
    await showGarminDisconnectDialog(
      context,
      onDisconnect: () => _enqueueGarmin(() async {
        try {
          await garmin.disconnect();
          if (!mounted) return;
          setState(() => garminAccount = null);
          _showNotice(
            const DashboardNotice(
              tone: NoticeTone.success,
              title: 'Garmin disconnected',
              message: 'Readings stay in your history and on this device.',
            ),
            autoDismiss: true,
          );
        } catch (_) {
          if (!mounted) return;
          _showNotice(
            const DashboardNotice(
              tone: NoticeTone.danger,
              title: "Couldn't disconnect Garmin",
              message: 'Try again.',
            ),
          );
        }
      }),
    );
  }

  DashboardNotice _garminNotice(
    GarminException error, {
    required Future<void> Function() retry,
    String? title,
  }) {
    final kindTitle = switch (error.kind) {
      GarminFailureKind.invalidCredentials => 'Garmin sign-in failed',
      GarminFailureKind.mfaFailed => 'Verification failed',
      GarminFailureKind.rateLimited => 'Garmin is limiting requests',
      GarminFailureKind.blocked => 'Garmin blocked the request',
      GarminFailureKind.network => "Couldn't reach Garmin",
      GarminFailureKind.unauthorized => 'Garmin session expired',
      GarminFailureKind.uploadRejected => 'Garmin rejected a reading',
      GarminFailureKind.unexpected => 'Garmin sync failed',
    };
    final message = error.kind == GarminFailureKind.unauthorized
        ? 'Reconnect your Garmin account to keep syncing.'
        : error.message;
    final actionLabel = error.kind == GarminFailureKind.unauthorized
        ? 'Reconnect'
        : 'Try again';

    return DashboardNotice(
      tone: NoticeTone.danger,
      title: error.requiresReconnect ? kindTitle : title ?? kindTitle,
      message: message,
      actionLabel: actionLabel,
      onAction: () => unawaited(retry()),
    );
  }

  void _showNotice(DashboardNotice value, {bool autoDismiss = false}) {
    _noticeTimer?.cancel();
    _noticeTimer = null;
    if (!mounted) return;
    setState(() => notice = value);
    if (autoDismiss) {
      _noticeTimer = Timer(const Duration(seconds: 6), () {
        if (mounted && identical(notice, value)) {
          setState(() => notice = null);
        }
      });
    }
  }

  void _clearNotice() {
    _noticeTimer?.cancel();
    _noticeTimer = null;
    if (mounted && notice != null) {
      setState(() => notice = null);
    }
  }

  Future<void> _editProfile() async {
    final result = await showProfileDialog(context, initialProfile: profile);
    if (result == null || !mounted) return;

    try {
      await profileStore.save(result);
    } catch (_) {
      if (!mounted) return;
      _showNotice(
        DashboardNotice(
          tone: NoticeTone.danger,
          title: "Couldn't save your profile",
          message: 'Try again. Your existing profile was kept.',
          actionLabel: 'Try again',
          onAction: () => unawaited(_editProfile()),
        ),
      );
      return;
    }

    final updatedHistory = history
        .map((measurement) => measurement.recomputedWith(result))
        .toList();
    var historySaved = true;
    if (updatedHistory.isNotEmpty) {
      try {
        await store.replaceAll(updatedHistory);
      } on MeasurementStorageException {
        historySaved = false;
      }
    }
    if (!mounted) return;
    setState(() {
      profile = result;
      history = updatedHistory;
    });
    _showNotice(
      DashboardNotice(
        tone: NoticeTone.success,
        title: 'Profile saved',
        message: historySaved
            ? 'Estimates were refreshed for your saved readings.'
            : 'New readings will use this profile, but saved readings could not be updated.',
      ),
      autoDismiss: historySaved,
    );
  }

  Future<void> _scan() async {
    final pendingDisconnect = _disconnecting;
    if (pendingDisconnect != null) {
      try {
        await pendingDisconnect;
      } catch (_) {
        // A failed cleanup must not block the next attempt.
      }
      if (!mounted) return;
    }
    if (scanning) return;
    final request = ++_scanRequest;
    _clearNotice();
    _pendingSave = null;
    setState(() => phase = ScalePhase.discovering);

    final permission = await bluetoothPermissions.request();
    if (!mounted || request != _scanRequest) return;
    if (permission != BluetoothPermissionResult.granted) {
      setState(() => phase = ScalePhase.idle);
      final permanent =
          permission == BluetoothPermissionResult.permanentlyDenied;
      if (permanent) {
        await showBluetoothPermissionDialog(
          context,
          permanent: true,
          openSettings: bluetoothPermissions.openSettings,
        );
      }
      if (!mounted) return;
      _showNotice(
        DashboardNotice(
          tone: NoticeTone.danger,
          title: 'Bluetooth access needed',
          message: permanent
              ? 'Allow Bluetooth access in Settings, then try again.'
              : 'Allow Bluetooth access to find your scale.',
          actionLabel: permanent ? 'Open settings' : 'Try again',
          onAction: () => permanent
              ? unawaited(bluetoothPermissions.openSettings())
              : unawaited(_scan()),
        ),
      );
      return;
    }

    try {
      await ble.scanAndConnect(profile: profile);
      if (!mounted) return;
      if (request != _scanRequest) {
        await ble.cancel();
      }
    } catch (_) {
      if (!mounted || request != _scanRequest) return;
      setState(() => phase = ScalePhase.idle);
      _showNotice(
        DashboardNotice(
          tone: NoticeTone.danger,
          title: 'Something went wrong',
          message: 'Try again. If it keeps happening, restart the app.',
          actionLabel: 'Try again',
          onAction: () => unawaited(_scan()),
        ),
      );
    }
  }

  Future<void> _cancel() async {
    _scanRequest++;
    if (mounted) setState(() => phase = ScalePhase.idle);
    final stopping = ble.cancel();
    _disconnecting = stopping;
    try {
      await stopping;
    } catch (_) {
      // Stopping is best-effort; the phase is already idle.
    }
    if (identical(_disconnecting, stopping)) _disconnecting = null;
  }

  Future<void> _onScaleFailure(ScaleFailure failure) async {
    if (!mounted) return;
    setState(() => phase = ScalePhase.idle);
    _showNotice(_noticeFor(failure));
    if (failure.kind == ScaleFailureKind.permissionDenied) {
      await showBluetoothPermissionDialog(
        context,
        permanent: true,
        openSettings: bluetoothPermissions.openSettings,
      );
    }
  }

  DashboardNotice _noticeFor(ScaleFailure failure) {
    DashboardNotice retry(String title, String message) => DashboardNotice(
      tone: NoticeTone.danger,
      title: title,
      message: message,
      actionLabel: 'Try again',
      onAction: () => unawaited(_scan()),
    );

    return switch (failure.kind) {
      ScaleFailureKind.bluetoothOff => retry(
        'Bluetooth is off',
        'Turn on Bluetooth in Settings or Control Center, then try again.',
      ),
      ScaleFailureKind.bluetoothUnavailable => const DashboardNotice(
        tone: NoticeTone.danger,
        title: "Bluetooth isn't available",
        message: "This device can't connect to Bluetooth scales.",
      ),
      ScaleFailureKind.permissionDenied => DashboardNotice(
        tone: NoticeTone.danger,
        title: 'Bluetooth access needed',
        message: 'Allow Bluetooth access in Settings to find your scale.',
        actionLabel: 'Open settings',
        onAction: () => unawaited(bluetoothPermissions.openSettings()),
      ),
      ScaleFailureKind.scaleNotFound => retry(
        'No scale found',
        'Wake the scale, keep it near your phone, and make sure it is not connected to another device.',
      ),
      ScaleFailureKind.connectionFailed => retry(
        "Couldn't connect",
        'Step off the scale, wake it, and try again.',
      ),
      ScaleFailureKind.connectionLost => retry(
        'Connection lost',
        'The scale disconnected before the reading finished.',
      ),
      ScaleFailureKind.unsupportedScale => const DashboardNotice(
        tone: NoticeTone.danger,
        title: "This scale isn't supported",
        message: 'It does not provide body-composition readings.',
      ),
      ScaleFailureKind.readingTimeout => retry(
        'No reading received',
        'Step on with bare feet and stand still, then try again.',
      ),
      ScaleFailureKind.unknown => retry(
        'Something went wrong',
        'Try again. If it keeps happening, restart the app.',
      ),
    };
  }

  Future<void> _onMeasurement(Measurement measurement) async {
    if (_handlingMeasurement) return;
    _handlingMeasurement = true;
    _pendingSave = measurement;
    try {
      await store.save(measurement);
      if (!mounted) return;
      setState(() {
        history = _withMeasurement(history, measurement);
        phase = ScalePhase.idle;
        _pendingSave = null;
      });
      final hasEstimate =
          measurement.impedance != null && measurement.bodyFatPercent != null;
      final detail = [
        '${formatWeight(measurement.weightKg)} kg',
        formatDateTime(context, measurement.timestamp),
        if (!hasEstimate)
          'Body composition was not available for this reading.',
        if (profile == null) 'Add your profile to estimate body fat.',
      ].join(' · ');
      final saved = DashboardNotice(
        tone: NoticeTone.success,
        title: 'Reading saved',
        message: detail,
      );
      _showNotice(saved, autoDismiss: true);
      unawaited(_sendToGarmin(measurement, saved, showStep: true));
    } on MeasurementStorageException {
      if (!mounted) return;
      setState(() => phase = ScalePhase.idle);
      _showNotice(
        DashboardNotice(
          tone: NoticeTone.danger,
          title: 'Reading received but not saved',
          message:
              '${formatWeight(measurement.weightKg)} kg was received, but it could not be stored.',
          actionLabel: 'Try again',
          onAction: () => unawaited(_retrySave()),
        ),
      );
    } finally {
      _handlingMeasurement = false;
      final disconnect = ble.disconnect();
      _disconnecting = disconnect;
      unawaited(
        disconnect.then(
          (_) {
            if (identical(_disconnecting, disconnect)) _disconnecting = null;
          },
          onError: (Object _) {
            if (identical(_disconnecting, disconnect)) _disconnecting = null;
          },
        ),
      );
    }
  }

  Future<void> _retrySave() async {
    final pending = _pendingSave;
    if (pending == null) return;
    try {
      await store.save(pending);
      if (!mounted) return;
      setState(() {
        history = _withMeasurement(history, pending);
        phase = ScalePhase.idle;
        _pendingSave = null;
      });
      final saved = DashboardNotice(
        tone: NoticeTone.success,
        title: 'Reading saved',
        message:
            '${formatWeight(pending.weightKg)} kg · ${formatDateTime(context, pending.timestamp)}',
      );
      _showNotice(saved, autoDismiss: true);
      unawaited(_sendToGarmin(pending, saved));
    } on MeasurementStorageException {
      if (!mounted) return;
      _showNotice(
        DashboardNotice(
          tone: NoticeTone.danger,
          title: "Couldn't save the reading",
          message: 'Check the device storage and try again.',
          actionLabel: 'Try again',
          onAction: () => unawaited(_retrySave()),
        ),
      );
    }
  }

  Future<void> _manual() async {
    if (scanning) return;
    final weight = await showManualWeightDialog(context);
    if (weight == null || !mounted) return;

    final currentProfile = profile;
    double? bmi;
    if (currentProfile != null && currentProfile.valid) {
      final meters = currentProfile.heightCm / 100;
      bmi = weight / (meters * meters);
    }
    final measurement = Measurement(
      timestamp: DateTime.now(),
      weightKg: weight,
      bmi: bmi,
    );
    _pendingSave = measurement;
    try {
      await store.save(measurement);
      if (!mounted) return;
      setState(() {
        history = _withMeasurement(history, measurement);
        _pendingSave = null;
      });
      final saved = DashboardNotice(
        tone: NoticeTone.success,
        title: 'Weight added',
        message: bmi == null
            ? '${formatWeight(weight)} kg added. Add your profile to include BMI.'
            : '${formatWeight(weight)} kg added.',
      );
      _showNotice(saved, autoDismiss: true);
      unawaited(_sendToGarmin(measurement, saved));
    } on MeasurementStorageException {
      if (!mounted) return;
      _showNotice(
        DashboardNotice(
          tone: NoticeTone.danger,
          title: "Couldn't save this weight",
          message: 'Check the device storage and try again.',
          actionLabel: 'Try again',
          onAction: () => unawaited(_retrySave()),
        ),
      );
    }
  }

  Future<void> _confirmResetHistory() async {
    await showResetHistoryDialog(
      context,
      onReset: () async {
        try {
          await store.clear();
          await _reload();
          if (!mounted) return;
          _showNotice(
            const DashboardNotice(
              tone: NoticeTone.success,
              title: 'Saved history reset',
              message: 'New readings will be saved normally.',
            ),
            autoDismiss: true,
          );
        } on MeasurementStorageException {
          if (!mounted) return;
          _showNotice(
            const DashboardNotice(
              tone: NoticeTone.danger,
              title: "Couldn't reset history",
              message: 'Restart the app and try again.',
            ),
          );
        }
      },
    );
  }

  List<Measurement> _withMeasurement(
    List<Measurement> values,
    Measurement measurement,
  ) {
    return [...values, measurement]
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  @override
  void dispose() {
    _noticeTimer?.cancel();
    _measurementSub?.cancel();
    _phaseSub?.cancel();
    _failureSub?.cancel();
    unawaited(ble.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DashboardView(
      history: history,
      profile: profile,
      loadingHistory: loadingHistory,
      loadingProfile: loadingProfile,
      phase: phase,
      notice: notice,
      onMeasure: scanning ? _cancel : _scan,
      onManual: _manual,
      onProfile: _editProfile,
      garminAccount: garminAccount,
      garminLoading: loadingGarmin,
      garminBusy: garminBusy,
      garminSyncingReading: garminSyncingReading,
      garminPendingReadings: garminAccount == null
          ? 0
          : garmin.pendingCount(history),
      garminSyncCompleted: garminBusy ? garminSyncCompleted : null,
      garminSyncTotal: garminBusy && garminSyncTotal > 0
          ? garminSyncTotal
          : null,
      onGarminConnect: () => unawaited(_connectGarmin()),
      onGarminSync: () => unawaited(_syncGarmin()),
      onGarminDisconnect: () => unawaited(_disconnectGarmin()),
    );
  }
}
