# Body Composition Flutter

A Flutter mobile adaptation of **[WebBodyComposition](https://github.com/lswiderski/WebBodyComposition)** by **[lswiderski](https://github.com/lswiderski)**, bringing the original project's Xiaomi body composition scale functionality to **iOS and Android**.

## Origin and attribution

This project is based on the idea and functionality of [WebBodyComposition](https://github.com/lswiderski/WebBodyComposition). The original project is a web application; this repository develops a separate Flutter mobile app inspired by it, with a mobile-focused user experience and native Bluetooth integration.

**This repository is not a GitHub-native fork of the original repository.** It is a separately created mobile adaptation. Please visit the upstream repository for the original project and its authors.

This project is not affiliated with or endorsed by Xiaomi or Garmin.

## Features

- Xiaomi Bluetooth Low Energy scale discovery and measurement reading
- Weight, BMI, impedance and estimated body composition
- Local measurement history and weight trends
- Optional user profile for measurement estimates; weight-only readings work without one
- Optional Garmin Connect sync with MFA, token refresh and duplicate-free uploads
- Adaptive iOS and Android interface using `adaptive_platform_ui`
- Light and dark palettes with contrast-checked semantic tokens
- Native iOS Liquid Glass navigation where supported, with platform fallbacks

## Status

**Work in progress.** Bluetooth integration and composition estimates need physical-device validation. Garmin sync uses Garmin Connect's mobile sign-in and upload endpoints (an unofficial API), can be rate-limited, and needs validation with a real Garmin account. Health-related estimates are informational and are not medical measurements.

## Garmin Connect sync

Open the Profile tab, tap **Connect Garmin**, and sign in with your Garmin
account. Then tap **Sync readings** to upload any readings that have not been
sent yet. The app uses the same `weight` FIT file format as the upstream
WebBodyComposition project: weight, body fat, hydration, bone mass, muscle mass,
visceral fat rating, physique rating, metabolic age and BMI.

- The Garmin password is used once to authorize the device and is never stored.
- Garmin OAuth tokens are kept in the platform Keychain/Keystore via
  `flutter_secure_storage`.
- MFA verification codes are supported.
- Successful uploads are recorded locally per Garmin account, so tapping Sync
  again only sends new readings. Garmin's "already uploaded" response is also
  treated as success.
- Without a measurement profile, only weight and BMI can be sent.

Garmin does not publish a body-composition write API. This integration uses the
same unofficial mobile endpoints as existing community clients, so Garmin may
rate-limit or change them at any time. See
[docs/garmin-sync.md](docs/garmin-sync.md) for implementation details and
troubleshooting.

The project includes native iOS and Android runners. Follow the Flutter and native platform prerequisites for your development machine.

## Getting started

```bash
git clone https://github.com/marcotrumpet/body-composition-flutter.git
cd body-composition-flutter
flutter pub get
flutter analyze
flutter test
flutter run
```

For platform permissions and setup, see [platform setup](docs/platform-setup.md) and [adaptive UI notes](docs/adaptive-ui.md).

## App icon

The launcher icon is a dark navy scale with a large weight readout (“72.4 kg”), a person and a three-colour body-composition ring, using the app’s blue/lavender/teal palette. The 1024×1024 master lives at [`design/app_icon.png`](design/app_icon.png); the iOS and Android launcher icons are generated from it at every required size.

## Credits

- **Original project:** [lswiderski/WebBodyComposition](https://github.com/lswiderski/WebBodyComposition)
- **Flutter mobile adaptation:** [marcotrumpet/body-composition-flutter](https://github.com/marcotrumpet/body-composition-flutter)

This adaptation acknowledges the original work. Review the upstream project's licensing terms before redistributing any copied source code or assets.
