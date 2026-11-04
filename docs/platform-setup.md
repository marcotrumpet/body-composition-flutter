# Bluetooth permission integration

The native iOS and Android projects are now present in the repository.

## iOS
`ios/Runner/Info.plist` already includes `NSBluetoothAlwaysUsageDescription`.
CoreBluetooth requests access when the app starts Bluetooth operations.
Test permission grant, denial, and Settings recovery on a real iPhone.

## Android
`android/app/src/main/AndroidManifest.xml` already declares
`BLUETOOTH_SCAN`, `BLUETOOTH_CONNECT`, and legacy permissions.
`BluetoothPermissions.request()` uses `device_info_plus` to select:
- Android 12+ (API 31+): Bluetooth Scan + Connect.
- Android 11 and earlier: foreground Location.

The dashboard calls this service before scanning. If permission is permanently
denied, it offers to open the app's system settings.

**Note:** Android's `neverForLocation` flag can filter certain BLE advertisements.
If Xiaomi discovery fails, reassess this flag and location-related behavior.

## Validate locally
```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

Because `pubspec.yaml` has changed, regenerate and commit `pubspec.lock`
using `flutter pub get` on your Mac. A physical device is needed for BLE testing.
