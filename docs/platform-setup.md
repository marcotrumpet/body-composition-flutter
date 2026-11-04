# Platform setup

Generate native runners using `flutter create --platforms=ios,android .`.

## iOS
Add to `ios/Runner/Info.plist` inside the main dict:
```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>Bluetooth is used to read measurements from your body composition scale.</string>
```
Test with a physical iPhone. iOS Simulator cannot connect to the scale.

## Android
Add to `android/app/src/main/AndroidManifest.xml` outside the application element:
```xml
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" android:usesPermissionFlags="neverForLocation" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<uses-permission android:name="android.permission.BLUETOOTH" android:maxSdkVersion="30" />
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" android:maxSdkVersion="30" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" android:maxSdkVersion="30" />
```
The FlutterBluePlus plugin requires appropriate Android runtime permission requests. **This is not implemented yet**; Android BLE scanning may fail until added. Android's `neverForLocation` flag can filter some BLE advertisements; review if your scale is not discovered.

## Status and safety
- Native runners have not been committed; run Flutter create locally.
- Weight, BMI and Xiaomi-impedance-based fat estimation implemented.
- These estimates are not clinical measurements.
- Profile is saved locally; historical measurements are stored unencrypted using shared_preferences.
- Garmin synchronization is not implemented.
- No physical-device testing or Flutter build has been performed.
