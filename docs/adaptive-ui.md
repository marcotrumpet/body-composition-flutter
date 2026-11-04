# Adaptive UI architecture

The application uses `adaptive_platform_ui ^1.0.2` for **native iOS 26+
Liquid Glass UIToolbar, UITabBar and UIButton** while Android uses Material 3
controls and older iOS versions use Cupertino fallbacks.

- `AdaptiveScaffold` owns the native navigation chrome inside each page route.
  Do **not** wrap the navigator in `AdaptiveToolbarHost` while using
  `AdaptiveScaffold`: the hosted fixed toolbar is drawn above the Navigator on
  iOS 26 and stays visible over Cupertino sheets.
- `AdaptiveScaffold(minimizeBehavior: TabBarMinimizeBehavior.never)` keeps the
  iOS 26 tab bar at full size while the user scrolls.
- `AdaptiveBottomNavigationBar(useNativeBottomBar: true)` supplies three tabs.
  - iOS 26 receives SF Symbol strings for the native tab bar.
  - iOS 18 and below receive a custom `CupertinoTabBar` because the package
    only maps a small set of SF Symbols to Cupertino icons.
  - Android receives `IconData` destinations; passing SF Symbol strings on
    Android would render `Icons.circle`.
- `AdaptiveAppBar(useNativeToolbar: true)` supplies the title and profile action.
- Measurement and profile actions use `AdaptiveButton` with 44pt minimum
  targets.
- Data charts and cards are custom Flutter widgets; they are **not** native
  Liquid Glass and are not described as such.

## Appearance

`BodyTheme` provides full light and dark `ThemeData`, registered as `theme` and
`darkTheme` with `ThemeMode.system`. `BodyColors` is a `ThemeExtension` with
semantic tokens (ink, canvas, surface, accent, success, danger, body-fat,
impedance, chart). A `CupertinoTheme` is installed in the `MaterialApp` builder
so sheets and Cupertino controls resolve the same brightness.

The dashboard uses a flat neutral canvas. Large blurred gradient orbs and
backdrop filters were removed for legibility and frame-time reasons.

We deliberately retain `MaterialApp` because existing dialogs, theme
dependencies and Material widgets are used throughout the application.
`AdaptiveToolbarHost` is only needed for apps that do not use
`AdaptiveScaffold`; this app lets each scaffold draw its own toolbar so sheets
and dialogs can cover it normally.

## Requirements

- Dart SDK >= 3.9.2 and a compatible Flutter SDK
- `cupertino_icons` for Cupertino glyphs and package fallbacks
- iOS deployment target >= 15.0 (Podfile updated)
- iOS 26+ for native Liquid Glass; older iOS uses the Cupertino fallback
- Xcode / CocoaPods or SPM support for the plugin's native code

Run `flutter pub get`, `flutter analyze`, `flutter test`, then test on
physical iOS 26 and Android devices. Keep `pubspec.lock` in sync. The app has
been launched on an iOS 27 simulator; BLE and Liquid Glass still need
physical-device validation.
