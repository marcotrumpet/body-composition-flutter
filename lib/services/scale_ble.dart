import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../models/measurement.dart';
import 'scale_decoder.dart';

class ScaleBle {
  static final Guid serviceUuid = Guid('0000181b-0000-1000-8000-00805f9b34fb');
  static final Guid measurementUuid = Guid('00002a9c-0000-1000-8000-00805f9b34fb');
  BluetoothDevice? _device;
  StreamSubscription<List<int>>? _subscription;
  final _measurements = StreamController<Measurement>.broadcast();
  Stream<Measurement> get measurements => _measurements.stream;

  Future<void> scanAndConnect({required double heightCm}) async {
    if (await FlutterBluePlus.isSupported == false) throw StateError('Bluetooth LE unavailable');
    await FlutterBluePlus.adapterState.where((state) => state == BluetoothAdapterState.on).first.timeout(const Duration(seconds: 15));
    await FlutterBluePlus.startScan(withServices: [serviceUuid], timeout: const Duration(seconds: 12));
    try {
      final results = await FlutterBluePlus.scanResults
          .map((items) => items.where((r) => r.advertisementData.serviceUuids.contains(serviceUuid)).toList())
          .firstWhere((items) => items.isNotEmpty)
          .timeout(const Duration(seconds: 12));
      _device = results.first.device;
    } finally {
      await FlutterBluePlus.stopScan();
    }
    final device = _device!;
    await device.connect(timeout: const Duration(seconds: 15));
    final services = await device.discoverServices();
    final characteristics = services.where((s) => s.uuid == serviceUuid).expand((s) => s.characteristics);
    final characteristic = characteristics.firstWhere((c) => c.uuid == measurementUuid);
    _subscription = characteristic.onValueReceived.listen((data) {
      final value = ScaleDecoder.decode(data, heightCm: heightCm);
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
