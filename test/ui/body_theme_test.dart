import 'package:body_composition_flutter/ui/body_theme.dart';
import 'package:body_composition_flutter/ui/body_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

double _contrast(Color foreground, Color background) {
  final first = foreground.computeLuminance();
  final second = background.computeLuminance();
  final lighter = first > second ? first : second;
  final darker = first > second ? second : first;
  return (lighter + 0.05) / (darker + 0.05);
}

void _expectContrast(
  Color foreground,
  Color background,
  double minimum,
  String label,
) {
  final ratio = _contrast(foreground, background);
  expect(
    ratio,
    greaterThanOrEqualTo(minimum),
    reason: '$label contrast was ${ratio.toStringAsFixed(2)}:1',
  );
}

void _checkPalette(BodyColors colors, String name) {
  _expectContrast(colors.ink, colors.surface, 7, '$name ink/surface');
  _expectContrast(colors.ink, colors.canvas, 7, '$name ink/canvas');
  _expectContrast(
    colors.secondaryInk,
    colors.surface,
    4.5,
    '$name secondary/surface',
  );
  _expectContrast(
    colors.secondaryInk,
    colors.canvas,
    4.5,
    '$name secondary/canvas',
  );
  _expectContrast(
    colors.accentText,
    colors.surface,
    4.5,
    '$name accentText/surface',
  );
  _expectContrast(
    colors.accentText,
    colors.canvas,
    4.5,
    '$name accentText/canvas',
  );
  _expectContrast(
    colors.onAccent,
    colors.accent,
    4.5,
    '$name onAccent/accent',
  );
  _expectContrast(colors.success, colors.surface, 4.5, '$name success/surface');
  _expectContrast(colors.danger, colors.surface, 4.5, '$name danger/surface');
  _expectContrast(colors.bodyFat, colors.surface, 4.5, '$name bodyFat/surface');
  _expectContrast(
    colors.impedance,
    colors.surface,
    4.5,
    '$name impedance/surface',
  );
  _expectContrast(
    colors.chartLine,
    colors.surface,
    4.5,
    '$name chartLine/surface',
  );
  _expectContrast(
    colors.controlBorder,
    colors.surface,
    3,
    '$name controlBorder/surface',
  );
}

void main() {
  test('light palette meets WCAG contrast targets', () {
    _checkPalette(BodyColors.light, 'light');
  });

  test('dark palette meets WCAG contrast targets', () {
    _checkPalette(BodyColors.dark, 'dark');
  });

  test('dark filled buttons use dark text', () {
    expect(BodyColors.dark.onAccent, isNot(Colors.white));
    expect(
      _contrast(BodyColors.dark.onAccent, BodyColors.dark.accent),
      greaterThanOrEqualTo(4.5),
    );
  });

  test('light and dark themes register BodyColors', () {
    final light = BodyTheme.light();
    final dark = BodyTheme.dark();
    expect(light.brightness, Brightness.light);
    expect(dark.brightness, Brightness.dark);
    expect(light.extension<BodyColors>(), isNotNull);
    expect(dark.extension<BodyColors>(), isNotNull);
    expect(light.scaffoldBackgroundColor, BodyColors.light.canvas);
    expect(dark.scaffoldBackgroundColor, BodyColors.dark.canvas);
    expect(light.colorScheme.primary, BodyColors.light.accent);
    expect(dark.colorScheme.onPrimary, BodyColors.dark.onAccent);
  });

  test('cupertino override follows the same brightness', () {
    expect(
      BodyTheme.cupertino(Brightness.dark).brightness,
      Brightness.dark,
    );
    expect(
      BodyTheme.cupertino(Brightness.light).scaffoldBackgroundColor,
      BodyColors.light.canvas,
    );
  });
}
