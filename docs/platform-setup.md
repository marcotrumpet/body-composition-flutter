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

## Network access for Garmin sync

Android release builds need the `INTERNET` permission, which is declared in
`android/app/src/main/AndroidManifest.xml`. iOS uses HTTPS only and needs no ATS
exception.

Garmin OAuth tokens are stored with `flutter_secure_storage` (Android Keystore,
iOS Keychain); the Garmin password itself is never persisted. Test Garmin
sign-in, MFA and an upload on a physical device with a real account. See
[garmin-sync.md](garmin-sync.md) for the flow and troubleshooting.

## Validate locally
```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

Because `pubspec.yaml` has changed, regenerate and commit `pubspec.lock`
using `flutter pub get` on your Mac. A physical device is needed for BLE testing.
