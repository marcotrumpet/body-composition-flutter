import 'package:body_composition_flutter/services/body_metrics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('matches the upstream WebBodyComposition formulas', () {
    final metrics = BodyMetrics(
      weightKg: 72.4,
      impedanceOhms: 512,
      heightCm: 175,
      ageYears: 35,
      sex: 'male',
    );

    expect(metrics.valid, isTrue);
    expect(metrics.fatPercent, closeTo(21.3321, 0.0001));
    expect(metrics.waterPercent, closeTo(53.9661, 0.0001));
    expect(metrics.boneMassKg, closeTo(2.8989, 0.0001));
    expect(metrics.muscleMassKg, closeTo(54.0567, 0.0001));
    expect(metrics.visceralFatRating, closeTo(11.6060, 0.0001));
    expect(metrics.metabolicAge, closeTo(30.9242, 0.0001));
    expect(metrics.physiqueRating, 4);
    expect(metrics.bmi, closeTo(23.6408, 0.0001));
  });

  test('matches the upstream formulas for a female profile', () {
    final metrics = BodyMetrics(
      weightKg: 62,
      impedanceOhms: 580,
      heightCm: 165,
      ageYears: 42,
      sex: 'female',
    );

    expect(metrics.valid, isTrue);
    expect(metrics.fatPercent, closeTo(31.4618, 0.0001));
    expect(metrics.muscleMassKg, closeTo(40.0343, 0.0001));
    expect(metrics.visceralFatRating, 1);
    expect(metrics.metabolicAge, closeTo(40.3461, 0.0001));
    expect(metrics.physiqueRating, 4);
  });

  test('clamps visceral fat and metabolic age to Garmin ranges', () {
    final metrics = BodyMetrics(
      weightKg: 55,
      impedanceOhms: 650,
      heightCm: 160,
      ageYears: 28,
      sex: 'female',
    );

    expect(metrics.visceralFatRating, greaterThanOrEqualTo(1));
    expect(metrics.visceralFatRating, lessThanOrEqualTo(50));
    expect(metrics.metabolicAge, greaterThanOrEqualTo(15));
    expect(metrics.metabolicAge, lessThanOrEqualTo(80));
  });
}
