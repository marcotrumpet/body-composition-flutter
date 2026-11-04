import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

enum BluetoothPermissionResult { granted, denied, permanentlyDenied }

/// Checks runtime permissions before scanning. iOS Bluetooth authorization
/// is requested by CoreBluetooth/flutter_blue_plus when Bluetooth is used.
class BluetoothPermissions {
  Future<BluetoothPermissionResult> request() async {
    if (!Platform.isAndroid) return BluetoothPermissionResult.granted;

    final sdk = (await DeviceInfoPlugin().androidInfo).version.sdkInt;
    final permissions = sdk >= 31
        ? <Permission>[Permission.bluetoothScan, Permission.bluetoothConnect]
        : <Permission>[Permission.locationWhenInUse];
    final statuses = await permissions.request();
    if (statuses.values.every((status) => status.isGranted)) {
      return BluetoothPermissionResult.granted;
    }
    if (statuses.values.any((status) => status.isPermanentlyDenied)) {
      return BluetoothPermissionResult.permanentlyDenied;
    }
    return BluetoothPermissionResult.denied;
  }

  Future<bool> openSettings() => openAppSettings();
}
