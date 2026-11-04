import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../models/measurement.dart';
import '../models/user_profile.dart';
import 'scale_decoder.dart';

/// Foreground-only BLE session. Scan/connect requires platform runtime permissions.
class ScaleBle {
  static final Guid serviceUuid = Guid('0000181b-0000-1000-8000-00805f9b34fb');
  static final Guid measurementUuid =
      Guid('00002a9c-0000-1000-8000-00805f9b34fb');
  BluetoothDevice? _device;
  StreamSubscription<List<int>>? _subscription;
  final _measurements = StreamController<Measurement>.broadcast();
  Stream<Measurement> get measurements => _measurements.stream;

  Future<void> scanAndConnect({required UserProfile profile}) async {
    if (!profile.valid) throw ArgumentError('Complete your profile first');
    if (!await FlutterBluePlus.isSupported)
      throw StateError('Bluetooth LE unavailable');
    await FlutterBluePlus.adapterState
        .where((state) => state == BluetoothAdapterState.on)
        .first
        .timeout(const Duration(seconds: 15),
            onTimeout: () => throw TimeoutException('Turn on Bluetooth'));
    final match = Completer<BluetoothDevice>();
    final scanSub = FlutterBluePlus.scanResults.listen((results) {
      for (final result in results) {
        if (result.advertisementData.serviceUuids.contains(serviceUuid) &&
            !match.isCompleted) {
          match.complete(result.device);
          break;
        }
      }
    });
    try {
      await FlutterBluePlus.startScan(
          withServices: [serviceUuid], timeout: const Duration(seconds: 15));
      _device = await match.future.timeout(const Duration(seconds: 16));
    } finally {
      await FlutterBluePlus.stopScan();
      await scanSub.cancel();
    }
    final device = _device!;
    await device.connect(timeout: const Duration(seconds: 15));
    final services = await device.discoverServices();
    final characteristics = services
        .where((s) => s.uuid == serviceUuid)
        .expand((s) => s.characteristics);
    final characteristic = characteristics.firstWhere(
        (c) => c.uuid == measurementUuid,
        orElse: () =>
            throw StateError('Body composition characteristic unavailable'));
    _subscription = characteristic.onValueReceived.listen((data) {
      final value = ScaleDecoder.decode(data, profile: profile);
      if (value != null && !_measurements.isClosed) _measurements.add(value);
    });
    await characteristic.setNotifyValue(true);
  }

  Future<void> disconnect() async {
    await _subscription?.cancel();
    _subscription = null;
    await _device?.disconnect();
    _device = null;
  }

  Future<void> dispose() async {
    await disconnect();
    await _measurements.close();
  }
}
