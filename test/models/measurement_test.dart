import 'package:body_composition_flutter/models/measurement.dart';
import 'package:body_composition_flutter/models/user_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const profile = UserProfile(heightCm: 180, ageYears: 35, sex: 'male');

  test('recomputedWith adds estimates from the current profile', () {
    final base = Measurement(
      timestamp: DateTime(2026, 11, 1, 9),
      weightKg: 90,
      impedance: 500,
    );

    final updated = base.recomputedWith(profile);

    expect(updated.weightKg, 90);
    expect(updated.impedance, 500);
    expect(updated.bmi, closeTo(27.7778, 0.001));
    expect(updated.bodyFatPercent, isNotNull);
    expect(updated.timestamp, base.timestamp);
  });

  test('recomputedWith removes derived values when the profile is gone', () {
    final base = Measurement(
      timestamp: DateTime(2026, 11, 1, 9),
      weightKg: 90,
      impedance: 500,
      bmi: 27.8,
      bodyFatPercent: 20,
    );

    final updated = base.recomputedWith(null);

    expect(updated.weightKg, 90);
    expect(updated.impedance, 500);
    expect(updated.bmi, isNull);
    expect(updated.bodyFatPercent, isNull);
  });

  test('manual readings gain BMI but not body fat after a profile edit', () {
    final base = Measurement(
      timestamp: DateTime(2026, 11, 1, 9),
      weightKg: 90,
    );

    final updated = base.recomputedWith(profile);

    expect(updated.bmi, closeTo(27.7778, 0.001));
    expect(updated.bodyFatPercent, isNull);
    expect(updated.impedance, isNull);
  });
}
