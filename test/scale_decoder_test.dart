import 'package:flutter_test/flutter_test.dart';
import 'package:body_composition_flutter/services/scale_decoder.dart';

void main() {
  test('decodes stable weight and impedance', () {
    final bytes = List<int>.filled(13, 0);
    bytes[1] = 0x20;
    bytes[11] = 0x50;
    bytes[12] = 0x46; // 18000 / 200 = 90kg
    bytes[9] = 0xF4;
    bytes[10] = 0x01; // 500 ohms
    final result = ScaleDecoder.decode(bytes, heightCm: 180);
    expect(result?.weightKg, 90);
    expect(result?.impedance, 500);
    expect(result?.bmi, closeTo(27.7778, 0.001));
  });
  test('ignores unstable packets', () {
    expect(ScaleDecoder.decode(List.filled(13, 0), heightCm: 180), isNull);
  });
}
