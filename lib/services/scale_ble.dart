import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../models/measurement.dart';
import '../models/user_profile.dart';
import 'scale_decoder.dart';

/// Stage of a foreground BLE measurement session.
enum ScalePhase { idle, discovering, connecting, waitingForReading }

/// Recoverable failure from a scale session. The UI turns these into calm,
/// actionable copy; raw exception text is never shown.
enum ScaleFailureKind {
  bluetoothOff,
  bluetoothUnavailable,
  permissionDenied,
  scaleNotFound,
  connectionFailed,
  connectionLost,
  unsupportedScale,
  readingTimeout,
  unknown,
}

class ScaleFailure {
  const ScaleFailure(this.kind, {this.cause});

  final ScaleFailureKind kind;
  final Object? cause;
}

class _SessionCancelled implements Exception {
  const _SessionCancelled();
}

/// Foreground-only BLE session. Scan/connect requires platform runtime permissions.
class ScaleBle {
  static final Guid serviceUuid = Guid('0000181b-0000-1000-8000-00805f9b34fb');
  static final Guid measurementUuid =
      Guid('00002a9c-0000-1000-8000-00805f9b34fb');

  static const _scanTimeout = Duration(seconds: 15);
  static const _connectTimeout = Duration(seconds: 15);
  static const _readingTimeout = Duration(seconds: 45);

  // Xiaomi scales report a stable weight first and the impedance packet a
  // moment later. Keep listening briefly so body composition is not discarded
  // in favour of the first weight-only notification.
  static const _impedanceGrace = Duration(seconds: 15);

  BluetoothDevice? _device;
  StreamSubscription<List<int>>? _notificationSub;
  StreamSubscription<BluetoothConnectionState>? _connectionSub;
  Completer<BluetoothDevice>? _match;
  Timer? _readingTimer;
  int _session = 0;
  bool _expectDisconnect = false;
  bool _readingReceived = false;
  Measurement? _pendingWeightOnly;
  Timer? _graceTimer;

  final _measurements = StreamController<Measurement>.broadcast();
  final _phases = StreamController<ScalePhase>.broadcast();
  final _failures = StreamController<ScaleFailure>.broadcast();

  ScalePhase _phase = ScalePhase.idle;

  Stream<Measurement> get measurements => _measurements.stream;
  Stream<ScalePhase> get phases => _phases.stream;
  Stream<ScaleFailure> get failures => _failures.stream;
  ScalePhase get phase => _phase;

  void _emitPhase(ScalePhase value) {
    if (_phase == value) return;
    _phase = value;
    if (!_phases.isClosed) _phases.add(value);
  }

  void _emitFailure(ScaleFailureKind kind, [Object? cause]) {
    if (!_failures.isClosed) {
      _failures.add(ScaleFailure(kind, cause: cause));
    }
  }

  bool _stale(int session) => session != _session;

  Future<void> _fail(ScaleFailureKind kind, [Object? cause]) async {
    _emitFailure(kind, cause);
    await _stopSession();
  }

  /// Emits the final reading once, cancelling the grace and overall timers.
  void _finalize(int session, Measurement value) {
    if (_stale(session) || _readingReceived) return;
    _readingReceived = true;
    _graceTimer?.cancel();
    _graceTimer = null;
    _readingTimer?.cancel();
    _readingTimer = null;
    _pendingWeightOnly = null;
    if (!_measurements.isClosed) _measurements.add(value);
  }

  Future<void> _stopSession() async {
    final session = ++_session;
    await _cleanup(session);
    if (_stale(session)) return;
    _emitPhase(ScalePhase.idle);
  }

  /// Releases resources for [session]. If a newer session has begun, this
  /// returns without disturbing it; the newer session performs its own
  /// cleanup before it starts.
  Future<void> _cleanup(int session) async {
    if (_stale(session)) return;
    _readingTimer?.cancel();
    _readingTimer = null;
    _graceTimer?.cancel();
    _graceTimer = null;
    _pendingWeightOnly = null;
    _readingReceived = false;

    await _connectionSub?.cancel();
    if (_stale(session)) return;
    _connectionSub = null;
    await _notificationSub?.cancel();
    if (_stale(session)) return;
    _notificationSub = null;

    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {
      // The adapter may already be off; nothing else to clean up.
    }
    if (_stale(session)) return;

    final match = _match;
    _match = null;
    if (match != null && !match.isCompleted) {
      match.completeError(const _SessionCancelled());
    }
    if (_stale(session)) return;

    final device = _device;
    _device = null;
    if (device != null) {
      _expectDisconnect = true;
      try {
        await device.disconnect();
      } catch (_) {
        // Device may already be disconnected.
      } finally {
        _expectDisconnect = false;
      }
    }
  }

  Future<void> scanAndConnect({UserProfile? profile}) async {
    final session = ++_session;
    await _cleanup(session);
    if (_stale(session)) return;
    _phase = ScalePhase.idle;
    _readingReceived = false;
    _pendingWeightOnly = null;

    try {
      if (!await FlutterBluePlus.isSupported) {
        if (!_stale(session)) {
          await _fail(ScaleFailureKind.bluetoothUnavailable);
        }
        return;
      }
      if (_stale(session)) return;

      final BluetoothAdapterState adapterState;
      try {
        adapterState = await FlutterBluePlus.adapterState
            .where((state) =>
                state != BluetoothAdapterState.unknown &&
                state != BluetoothAdapterState.turningOn)
            .first
            .timeout(const Duration(seconds: 8));
      } on TimeoutException {
        if (!_stale(session)) {
          await _fail(ScaleFailureKind.bluetoothUnavailable);
        }
        return;
      }
      if (_stale(session)) return;

      switch (adapterState) {
        case BluetoothAdapterState.unavailable:
          await _fail(ScaleFailureKind.bluetoothUnavailable);
          return;
        case BluetoothAdapterState.unauthorized:
          await _fail(ScaleFailureKind.permissionDenied);
          return;
        case BluetoothAdapterState.off:
        case BluetoothAdapterState.turningOff:
          await _fail(ScaleFailureKind.bluetoothOff);
          return;
        case BluetoothAdapterState.unknown:
        case BluetoothAdapterState.turningOn:
        case BluetoothAdapterState.on:
          break;
      }

      _emitPhase(ScalePhase.discovering);
      final match = Completer<BluetoothDevice>();
      _match = match;
      // A Cancel can complete the match with an error while the scan is still
      // starting; ignore is registered up front so that is never unhandled.
      match.future.ignore();
      final scanSub = FlutterBluePlus.scanResults.listen(
        (results) {
          if (results.isNotEmpty && !match.isCompleted) {
            // The scan is filtered by service UUID, so the first result is
            // the scale even if the platform omits UUIDs from the payload.
            match.complete(results.first.device);
          }
        },
        onError: (Object error) {
          if (!match.isCompleted) match.completeError(error);
        },
      );
      try {
        await FlutterBluePlus.startScan(
          withServices: [serviceUuid],
          timeout: _scanTimeout,
        );
        if (_stale(session)) return;
        final device = await match.future.timeout(
          _scanTimeout + const Duration(seconds: 1),
        );
        if (_stale(session)) return;

        _emitPhase(ScalePhase.connecting);
        try {
          await device.connect(timeout: _connectTimeout);
        } catch (error) {
          if (!_stale(session)) {
            await _fail(ScaleFailureKind.connectionFailed, error);
          }
          return;
        }
        if (_stale(session)) {
          try {
            await device.disconnect();
          } catch (_) {}
          return;
        }

        _device = device;
        _connectionSub = device.connectionState.listen((state) {
          if (state != BluetoothConnectionState.disconnected ||
              _expectDisconnect ||
              _readingReceived ||
              _stale(session)) {
            return;
          }
          // Some scales disconnect immediately after their final packet. If
          // that packet was weight-only, save it instead of losing the reading.
          final pending = _pendingWeightOnly;
          if (pending != null) {
            _finalize(session, pending);
          } else {
            unawaited(_fail(ScaleFailureKind.connectionLost));
          }
        });

        final List<BluetoothService> services;
        try {
          services = await device.discoverServices();
        } catch (error) {
          if (!_stale(session)) {
            await _fail(ScaleFailureKind.unsupportedScale, error);
          }
          return;
        }
        if (_stale(session)) return;
        final characteristics = services
            .where((service) => service.uuid == serviceUuid)
            .expand((service) => service.characteristics);
        BluetoothCharacteristic? characteristic;
        for (final candidate in characteristics) {
          if (candidate.uuid == measurementUuid) {
            characteristic = candidate;
            break;
          }
        }
        if (characteristic == null) {
          await _fail(ScaleFailureKind.unsupportedScale);
          return;
        }

        _notificationSub = characteristic.onValueReceived.listen((data) {
          if (_stale(session) || _readingReceived) return;
          final value = ScaleDecoder.decode(data, profile: profile);
          if (value == null) return;
          if (value.impedance != null) {
            _finalize(session, value);
            return;
          }
          // Hold the weight-only reading while the scale completes the
          // impedance measurement. A later packet replaces it.
          _pendingWeightOnly = value;
          _graceTimer ??= Timer(_impedanceGrace, () {
            final pending = _pendingWeightOnly;
            if (pending != null) _finalize(session, pending);
          });
        });

        try {
          await characteristic.setNotifyValue(true);
        } catch (error) {
          if (!_stale(session)) {
            await _fail(ScaleFailureKind.connectionFailed, error);
          }
          return;
        }
        if (_stale(session)) return;

        _emitPhase(ScalePhase.waitingForReading);
        _readingTimer = Timer(_readingTimeout, () {
          if (_stale(session) || _readingReceived) return;
          final pending = _pendingWeightOnly;
          if (pending != null) {
            _finalize(session, pending);
          } else {
            unawaited(_fail(ScaleFailureKind.readingTimeout));
          }
        });
      } on _SessionCancelled {
        return;
      } on TimeoutException {
        if (!_stale(session)) {
          await _fail(ScaleFailureKind.scaleNotFound);
        }
      } catch (error) {
        if (!_stale(session)) {
          final kind = error is FlutterBluePlusException
              ? ScaleFailureKind.connectionFailed
              : ScaleFailureKind.unknown;
          await _fail(kind, error);
        }
      } finally {
        await scanSub.cancel();
        if (!_stale(session)) {
          try {
            await FlutterBluePlus.stopScan();
          } catch (_) {}
        }
        if (identical(_match, match)) _match = null;
      }
    } catch (error) {
      if (!_stale(session)) {
        await _fail(ScaleFailureKind.unknown, error);
      }
    }
  }

  /// Stops a session without reporting a failure (user tapped Stop).
  Future<void> cancel() => _stopSession();

  /// Quiet disconnect after a reading was saved.
  Future<void> disconnect() => _stopSession();

  Future<void> dispose() async {
    await _stopSession();
    await _measurements.close();
    await _phases.close();
    await _failures.close();
  }
}
