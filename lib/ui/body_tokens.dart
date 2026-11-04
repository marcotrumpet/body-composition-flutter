import 'package:flutter/material.dart';

/// Semantic colors for the light and dark Body Composition experience.
///
/// Components read [BodyColors.of] instead of hard-coded values so the
/// Material and Cupertino surfaces stay in sync in both appearances.
@immutable
class BodyColors extends ThemeExtension<BodyColors> {
  const BodyColors({
    required this.ink,
    required this.secondaryInk,
    required this.canvas,
    required this.surface,
    required this.surfaceMuted,
    required this.surfaceRaised,
    required this.border,
    required this.controlBorder,
    required this.accent,
    required this.accentText,
    required this.onAccent,
    required this.success,
    required this.danger,
    required this.bodyFat,
    required this.impedance,
    required this.chartLine,
  });

  final Color ink;
  final Color secondaryInk;
  final Color canvas;
  final Color surface;
  final Color surfaceMuted;
  final Color surfaceRaised;
  final Color border;
  final Color controlBorder;
  final Color accent;
  final Color accentText;
  final Color onAccent;
  final Color success;
  final Color danger;
  final Color bodyFat;
  final Color impedance;
  final Color chartLine;

  static const light = BodyColors(
    ink: Color(0xFF111B3A),
    secondaryInk: Color(0xFF5B6478),
    canvas: Color(0xFFF4F6FB),
    surface: Color(0xFFFFFFFF),
    surfaceMuted: Color(0xFFF7F8FC),
    surfaceRaised: Color(0xFFFFFFFF),
    border: Color(0xFFE3E7F0),
    controlBorder: Color(0xFF7A8699),
    accent: Color(0xFF3168D4),
    accentText: Color(0xFF3168D4),
    onAccent: Color(0xFFFFFFFF),
    success: Color(0xFF0F7B6C),
    danger: Color(0xFFB3263F),
    bodyFat: Color(0xFF7B4FD6),
    impedance: Color(0xFF0B7285),
    chartLine: Color(0xFF3168D4),
  );

  static const dark = BodyColors(
    ink: Color(0xFFF2F4FA),
    secondaryInk: Color(0xFFA9B2C9),
    canvas: Color(0xFF0B0F1A),
    surface: Color(0xFF171C2C),
    surfaceMuted: Color(0xFF1F2536),
    surfaceRaised: Color(0xFF1A2130),
    border: Color(0xFF2A3146),
    controlBorder: Color(0xFF5F6B7E),
    accent: Color(0xFF9DB1FF),
    accentText: Color(0xFF9DB1FF),
    onAccent: Color(0xFF101828),
    success: Color(0xFF6FE3C4),
    danger: Color(0xFFFF9AAF),
    bodyFat: Color(0xFFC3A6FF),
    impedance: Color(0xFF6ED6E8),
    chartLine: Color(0xFF9DB1FF),
  );

  static BodyColors of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<BodyColors>() ??
        (theme.brightness == Brightness.dark ? dark : light);
  }

  @override
  BodyColors copyWith({
    Color? ink,
    Color? secondaryInk,
    Color? canvas,
    Color? surface,
    Color? surfaceMuted,
    Color? surfaceRaised,
    Color? border,
    Color? controlBorder,
    Color? accent,
    Color? accentText,
    Color? onAccent,
    Color? success,
    Color? danger,
    Color? bodyFat,
    Color? impedance,
    Color? chartLine,
  }) {
    return BodyColors(
      ink: ink ?? this.ink,
      secondaryInk: secondaryInk ?? this.secondaryInk,
      canvas: canvas ?? this.canvas,
      surface: surface ?? this.surface,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      surfaceRaised: surfaceRaised ?? this.surfaceRaised,
      border: border ?? this.border,
      controlBorder: controlBorder ?? this.controlBorder,
      accent: accent ?? this.accent,
      accentText: accentText ?? this.accentText,
      onAccent: onAccent ?? this.onAccent,
      success: success ?? this.success,
      danger: danger ?? this.danger,
      bodyFat: bodyFat ?? this.bodyFat,
      impedance: impedance ?? this.impedance,
      chartLine: chartLine ?? this.chartLine,
    );
  }

  @override
  BodyColors lerp(ThemeExtension<BodyColors>? other, double t) {
    if (other is! BodyColors) return this;
    return BodyColors(
      ink: Color.lerp(ink, other.ink, t)!,
      secondaryInk: Color.lerp(secondaryInk, other.secondaryInk, t)!,
      canvas: Color.lerp(canvas, other.canvas, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceMuted: Color.lerp(surfaceMuted, other.surfaceMuted, t)!,
      surfaceRaised: Color.lerp(surfaceRaised, other.surfaceRaised, t)!,
      border: Color.lerp(border, other.border, t)!,
      controlBorder: Color.lerp(controlBorder, other.controlBorder, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentText: Color.lerp(accentText, other.accentText, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      success: Color.lerp(success, other.success, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      bodyFat: Color.lerp(bodyFat, other.bodyFat, t)!,
      impedance: Color.lerp(impedance, other.impedance, t)!,
      chartLine: Color.lerp(chartLine, other.chartLine, t)!,
    );
  }
}

/// 4/8-point spacing scale and the baseline page rhythm.
abstract final class BodySpace {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;

  static const screen = lg;
  static const card = xl;
  static const minimumTapTarget = 44.0;
  static const maxContentWidth = 640.0;
}

/// Small typography scale: four roles, regular and bold weights.
///
/// Numeric values use tabular figures so measurements do not shift while
/// animating or updating.
abstract final class BodyType {
  static const display = TextStyle(
    fontSize: 56,
    fontWeight: FontWeight.w700,
    height: 1,
    letterSpacing: -1.5,
    fontFeatures: [FontFeature.tabularFigures()],
    decoration: TextDecoration.none,
  );

  static const title = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    height: 1.2,
    fontFeatures: [FontFeature.tabularFigures()],
    decoration: TextDecoration.none,
  );

  static const body = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.4,
    fontFeatures: [FontFeature.tabularFigures()],
    decoration: TextDecoration.none,
  );

  static const caption = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.35,
    fontFeatures: [FontFeature.tabularFigures()],
    decoration: TextDecoration.none,
  );

  static const overline = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: 1.1,
    decoration: TextDecoration.none,
  );
}

abstract final class BodyRadius {
  static const card = 24.0;
  static const compact = 16.0;
  static const control = 12.0;
}

abstract final class BodyMotion {
  static const fast = Duration(milliseconds: 180);
  static const medium = Duration(milliseconds: 280);
}
