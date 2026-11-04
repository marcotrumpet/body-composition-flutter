# Adaptive UI architecture

The application uses `adaptive_platform_ui ^1.0.2` for **native iOS 26+
Liquid Glass UIToolbar, UITabBar and UIButton** while Android uses Material 3
controls and older iOS versions use Cupertino fallbacks.

- `AdaptiveToolbarHost` is installed around the Material navigator.
- `AdaptiveScaffold` owns the native navigation chrome.
- `AdaptiveBottomNavigationBar(useNativeBottomBar: true)` supplies three tabs.
- `AdaptiveAppBar(useNativeToolbar: true)` supplies the title and profile action.
- Measurement and profile actions use `AdaptiveButton`.
- Data charts, the weight orb and metric panels are custom Flutter widgets;
  they are **not native Liquid Glass**.

We deliberately retain `MaterialApp` for now because existing dialogs,
theme dependencies and Material widgets are used throughout the application.
The toolbar host is the documented integration route for non-AdaptiveApp apps.

## Requirements

- Dart SDK >= 3.9.2 and a compatible Flutter SDK
- iOS deployment target >= 15.0 (Podfile updated)
- iOS 26+ for native Liquid Glass; older iOS uses fallback
- Xcode / CocoaPods or SPM support for the plugin's native code

Run `flutter pub get`, `flutter analyze`, `flutter test`, then test on
physical iOS 26 and Android devices. Regenerate and commit `pubspec.lock`.
This integration has not been built in the assistant environment.
