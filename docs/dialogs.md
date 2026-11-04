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

## Garmin sign-in

- iOS uses the same Cupertino sheet pattern with a `CupertinoNavigationBar`
  (Cancel / Sign in). The email field is not autofocused so the keyboard does
  not cover the sheet as soon as it opens; the MFA sheet is autofocused because
  the user is already waiting to type a code.
- Android uses a scrollable `AlertDialog` with the same validators.
- The Garmin password is only held in the dialog/controller for the lifetime of
  the sign-in request. Tokens are written to secure storage by `GarminService`.

## iOS 26 notes

- `MaterialApp.builder` paints `BodyColors.canvas` behind the Navigator. Without
  it, the scaled previous route leaves the WidgetsApp black background visible
  in the gap above a Cupertino sheet.
- Plain `AdaptiveButton` actions set `useNative: false`. The iOS 26 native
  title-mode button uses `SizedBox(width: minSize.width)`, so a `Size(0, h)`
  minimum produces a zero-width platform view that paints but cannot be tapped.
- The tab bar uses `TabBarMinimizeBehavior.never`; the default automatic
  behavior shrinks it while scrolling.

## Appearance

- The app ships full light and dark palettes via `BodyTheme` and
  `ThemeMode.system`; it no longer forces light mode.
- A `CupertinoTheme` is installed in the app builder so Cupertino sheets,
  fields and alerts follow the same brightness as the Material surfaces.
- Dialog surfaces are opaque and use the token palette; never render white text
  on a light or translucent surface.

Check both platforms and both system appearance settings before release.
