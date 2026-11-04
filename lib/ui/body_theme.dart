import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'body_tokens.dart';

/// Light and dark Material themes plus the matching Cupertino overrides.
///
/// Cupertino widgets resolve colors from the ambient [CupertinoTheme], which
/// [MaterialApp] does not install by itself. [cupertino] is used in the app
/// builder so sheets and native-style controls follow the same appearance as
/// the Material surfaces.
abstract final class BodyTheme {
  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static CupertinoThemeData cupertino(Brightness brightness) {
    final colors =
        brightness == Brightness.dark ? BodyColors.dark : BodyColors.light;
    return CupertinoThemeData(
      brightness: brightness,
      primaryColor: colors.accent,
      primaryContrastingColor: colors.onAccent,
      scaffoldBackgroundColor: colors.canvas,
    );
  }

  static ThemeData _build(Brightness brightness) {
    final colors =
        brightness == Brightness.dark ? BodyColors.dark : BodyColors.light;
    final scheme = ColorScheme.fromSeed(
      seedColor: colors.accent,
      brightness: brightness,
    ).copyWith(
      primary: colors.accent,
      onPrimary: colors.onAccent,
      surface: colors.surface,
      onSurface: colors.ink,
      onSurfaceVariant: colors.secondaryInk,
      outline: colors.controlBorder,
      outlineVariant: colors.border,
      error: colors.danger,
      onError: colors.onAccent,
      surfaceTint: Colors.transparent,
    );
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
    );
    final textTheme = base.textTheme.copyWith(
      displayLarge: BodyType.display.copyWith(color: colors.ink),
      titleLarge: BodyType.title.copyWith(color: colors.ink),
      bodyMedium: BodyType.body.copyWith(color: colors.ink),
      bodySmall: BodyType.caption.copyWith(color: colors.secondaryInk),
      labelMedium: BodyType.caption.copyWith(color: colors.secondaryInk),
      labelSmall: BodyType.overline.copyWith(color: colors.secondaryInk),
    );
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(BodyRadius.control),
      borderSide: BorderSide(color: colors.controlBorder),
    );
    final focusedBorder = inputBorder.copyWith(
      borderSide: BorderSide(color: colors.accent, width: 2),
    );
    final errorBorder = inputBorder.copyWith(
      borderSide: BorderSide(color: colors.danger),
    );

    return base.copyWith(
      scaffoldBackgroundColor: colors.canvas,
      canvasColor: colors.canvas,
      textTheme: textTheme,
      extensions: [colors],
      appBarTheme: AppBarThemeData(
        backgroundColor: colors.canvas,
        foregroundColor: colors.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle:
            (brightness == Brightness.dark
                    ? SystemUiOverlayStyle.light
                    : SystemUiOverlayStyle.dark)
                .copyWith(
                  statusBarColor: colors.canvas,
                  systemNavigationBarColor: colors.canvas,
                  systemNavigationBarIconBrightness: brightness ==
                          Brightness.dark
                      ? Brightness.light
                      : Brightness.dark,
                ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BodyRadius.card),
        ),
        titleTextStyle: BodyType.title.copyWith(color: colors.ink),
        contentTextStyle: BodyType.body.copyWith(color: colors.secondaryInk),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: colors.surfaceMuted,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: BodySpace.lg,
          vertical: BodySpace.md,
        ),
        labelStyle: BodyType.body.copyWith(color: colors.secondaryInk),
        hintStyle: BodyType.body.copyWith(color: colors.secondaryInk),
        errorStyle: BodyType.caption.copyWith(color: colors.danger),
        border: inputBorder,
        enabledBorder: inputBorder,
        focusedBorder: focusedBorder,
        errorBorder: errorBorder,
        focusedErrorBorder: focusedBorder.copyWith(
          borderSide: BorderSide(color: colors.danger, width: 2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(0, 48),
          backgroundColor: colors.accent,
          foregroundColor: colors.onAccent,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(BodyRadius.control),
          ),
          textStyle: BodyType.body.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 48),
          backgroundColor: colors.accent,
          foregroundColor: colors.onAccent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(BodyRadius.control),
          ),
          textStyle: BodyType.body.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(0, BodySpace.minimumTapTarget),
          foregroundColor: colors.accentText,
          textStyle: BodyType.body.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(0, 48)),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            return states.contains(WidgetState.selected)
                ? colors.onAccent
                : colors.ink;
          }),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            return states.contains(WidgetState.selected)
                ? colors.accent
                : colors.surfaceMuted;
          }),
          side: WidgetStatePropertyAll(
            BorderSide(color: colors.controlBorder),
          ),
          textStyle: WidgetStatePropertyAll(
            BodyType.body.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colors.surface,
        indicatorColor: colors.accent.withValues(alpha: 0.16),
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStatePropertyAll(
          BodyType.caption.copyWith(color: colors.ink),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colors.accent,
      ),
      cupertinoOverrideTheme: CupertinoThemeData(
        brightness: brightness,
        primaryColor: colors.accent,
        primaryContrastingColor: colors.onAccent,
        scaffoldBackgroundColor: colors.canvas,
      ),
    );
  }
}
