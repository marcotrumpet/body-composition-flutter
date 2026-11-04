# Adaptive dialogs

The app uses platform-adaptive dialogs for profile editing, manual weight entry and Bluetooth permission recovery.

- iOS: CupertinoAlertDialog, CupertinoTextField and CupertinoSlidingSegmentedControl.
- Android: Material AlertDialog and Material text fields, with opaque surfaces.
- The app currently forces light ThemeMode to keep the custom light dashboard and its dialogs legible until a full dark theme is implemented.
- Native iOS 26 Liquid Glass tab bars and toolbars are provided by adaptive_platform_ui. CupertinoAlertDialog is a native-style Flutter rendering, **not** an iOS 26 native Liquid Glass UIAlertController.
- Check both platforms and both system appearance settings on physical devices before release.
