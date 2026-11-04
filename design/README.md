# App icon

`app_icon.png` is the 1024×1024 master used for the iOS and Android launcher
icons. `app_icon_foreground.png` is the transparent foreground used by the
Android adaptive icon (API 26+).

The mark is a digital scale with a literal weight readout, a person silhouette
and a segmented body-composition ring: deep navy for the app's calm canvas,
white for the scale and person, and the app's accent blue, lavender and teal
for the composition segments.

Platform sizes are simple LANCZOS downscales of the master:

- iOS: `ios/Runner/Assets.xcassets/AppIcon.appiconset/`
- Android legacy: `android/app/src/main/res/mipmap-*/ic_launcher.png`
- Android adaptive: `android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml`
  with `mipmap-*/ic_launcher_foreground.png` and the
  `ic_launcher_background` color.
