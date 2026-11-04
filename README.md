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
- User profile for measurement estimates
- Adaptive iOS and Android interface using `adaptive_platform_ui`
- Native iOS Liquid Glass navigation where supported, with platform fallbacks

## Status

**Work in progress.** Bluetooth integration and composition estimates need physical-device validation. Garmin synchronization is not implemented. Health-related estimates are informational and are not medical measurements.

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

A custom branded launcher icon has **not yet been added**. The iOS and Android launcher icons currently come from the generated Flutter project.

## Credits

- **Original project:** [lswiderski/WebBodyComposition](https://github.com/lswiderski/WebBodyComposition)
- **Flutter mobile adaptation:** [marcotrumpet/body-composition-flutter](https://github.com/marcotrumpet/body-composition-flutter)

This adaptation acknowledges the original work. Review the upstream project's licensing terms before redistributing any copied source code or assets.
