import 'package:body_composition_flutter/ui/body_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('weights always use one decimal', () {
    expect(formatWeight(72.44), '72.4');
    expect(formatWeight(72), '72.0');
  });

  test('impedance is a whole number with a unit and a fallback', () {
    expect(formatImpedance(512), '512 Ω');
    expect(formatImpedance(null), '—');
  });

  test('body fat and BMI use one decimal', () {
    expect(formatBodyFat(18.24), '18.2%');
    expect(formatBodyFat(null), '—');
    expect(formatBmi(22.34), '22.3');
    expect(formatBmi(null), '—');
  });

  test('height drops a redundant decimal', () {
    expect(formatHeight(175), '175 cm');
    expect(formatHeight(175.5), '175.5 cm');
    expect(formatHeightInput(175), '175');
    expect(formatHeightInput(175.5), '175.5');
  });

  test('sex is displayed with a capital letter', () {
    expect(formatSex('male'), 'Male');
    expect(formatSex('female'), 'Female');
    expect(formatSex('Female'), 'Female');
  });

  test('delta copy is neutral and handles no change', () {
    expect(
      formatWeightDelta(72.4, 72.1),
      '0.3 kg above your previous reading',
    );
    expect(
      formatWeightDelta(72.1, 72.4),
      '0.3 kg below your previous reading',
    );
    expect(
      formatWeightDelta(72.0, 72.04),
      'Same as your previous reading',
    );
  });

  test('spoken weight uses kilograms', () {
    expect(spokenWeight(72.4), '72.4 kilograms');
  });
}
