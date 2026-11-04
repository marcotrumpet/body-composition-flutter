# Platform setup

Run `flutter create --platforms=ios,android .` to generate the native Flutter runners.

## iOS
In `ios/Runner/Info.plist` add:
```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>Bluetooth is needed to read measurements from your scale.</string>
```
Enable Bluetooth on the iPhone. Test on a physical device; iOS Simulator does not provide the scale's BLE connection.

## Android
In `android/app/src/main/AndroidManifest.xml`, above the application element, add:
```xml
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" android:maxSdkVersion="30" />
```
Request runtime Bluetooth permissions (Android 12+) and location permission where required before scanning. Permission-request UI is not yet implemented in this first milestone.

## Limitations
- Only the standard Body Composition Service (0x181B) and measurement characteristic (0x2A9C) are currently implemented.
- Weight and impedance are decoded; estimated body fat and additional composition metrics are not yet implemented.
- Height is selected from preset values and is not yet persisted.
- BLE hardware testing, runtime permission handling and Garmin integration are pending.
- The native runners must be generated locally; this repository has not yet been built or tested with Flutter SDK.
