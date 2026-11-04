# Adaptive dialogs

Dialogs and form sheets live in `lib/ui/dialogs.dart`; no dialog UI is built in
`main.dart`.

## Profile and manual weight

- **iOS:** `showCupertinoSheet` with `scrollableBuilder`, a
  `CupertinoPageScaffold`, a `CupertinoNavigationBar` (Cancel / Save) and
  inset-grouped `CupertinoFormSection` rows.
- **Android:** `AlertDialog(scrollable: true)` on an opaque token surface with
  `TextFormField`s and a Material `SegmentedButton`.
- Both branches share a `Form` and the same field validators, so invalid input
  shows inline errors and never closes the sheet silently. Comma decimals are
  accepted.
- Fields use `initialValue` + `onSaved` rather than externally owned
  `TextEditingController`s; the form owns its state and needs no manual
  disposal after the route closes.
- A profile is optional. Without one, weight and raw impedance can still be
  recorded; BMI, body-fat and other derived values stay empty and are labelled
  as unavailable.

## Permission and reset alerts

- Permission recovery uses `AdaptiveAlertDialog.show`: a native iOS 26
  `UIAlertController`, Cupertino fallback on older iOS, Material on Android.
- The adaptive alert dismisses itself before invoking an action, so action
  callbacks must not call `Navigator.pop` themselves. "Open settings" only
  performs the side effect.
- The permission action intentionally uses the native tinted-button style, not
  `AlertActionStyle.primary`: the native iOS 26 preferred action is filled with
  the app tint and forces white text, which is unreadable on the light
  dark-mode accent.
- History reset uses the same adaptive alert with a destructive action.

## Appearance

- The app ships full light and dark palettes via `BodyTheme` and
  `ThemeMode.system`; it no longer forces light mode.
- A `CupertinoTheme` is installed in the app builder so Cupertino sheets,
  fields and alerts follow the same brightness as the Material surfaces.
- Dialog surfaces are opaque and use the token palette; never render white text
  on a light or translucent surface.

Check both platforms and both system appearance settings before release.
