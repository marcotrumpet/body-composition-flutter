import 'package:flutter_test/flutter_test.dart';
import 'package:body_composition_flutter/models/user_profile.dart';
import 'package:body_composition_flutter/services/scale_decoder.dart';
import 'package:body_composition_flutter/services/body_metrics.dart';

void main() {
  const profile = UserProfile(heightCm: 180, ageYears: 35, sex: 'male');
  test('decodes stable weight and impedance', () {
    final bytes = List<int>.filled(13, 0);
    bytes[1] = 0x20;
    bytes[11] = 0x50;
    bytes[12] = 0x46; // 18000 / 200 = 90kg
    bytes[9] = 0xF4;
    bytes[10] = 0x01; // 500 ohms
    final result = ScaleDecoder.decode(bytes, profile: profile);
    expect(result?.weightKg, 90);
    expect(result?.impedance, 500);
    expect(result?.bmi, closeTo(27.7778, 0.001));
    expect(result?.bodyFatPercent, isNotNull);
  });
  test('ignores unstable packets', () {
    expect(ScaleDecoder.decode(List.filled(13, 0), profile: profile), isNull);
  });
  test('weight-only packet does not invent body fat', () {
    final bytes = List<int>.filled(13, 0);
    bytes[1] = 0x20;
    bytes[11] = 0x50;
    bytes[12] = 0x46;
    final result = ScaleDecoder.decode(bytes, profile: profile);
    expect(result?.bodyFatPercent, isNull);
    expect(result?.impedance, isNull);
  });
  test('body metrics are bounded', () {
    const metrics = BodyMetrics(
        weightKg: 90,
        impedanceOhms: 500,
        heightCm: 180,
        ageYears: 35,
        sex: 'male');
    expect(metrics.valid, isTrue);
    expect(metrics.fatPercent, inInclusiveRange(5, 75));
    expect(metrics.waterPercent, inInclusiveRange(35, 75));
    expect(metrics.muscleMassKg, greaterThan(0));
  });
}
