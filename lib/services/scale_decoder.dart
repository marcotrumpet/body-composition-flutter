import '../models/measurement.dart';

/// Decoder for the 13-byte Xiaomi body composition measurement payload.
/// Byte offsets follow the upstream WebBodyComposition BLE implementation.
class ScaleDecoder {
  static Measurement? decode(List<int> bytes, {required double heightCm}) {
    if (bytes.length < 13 || heightCm <= 0) return null;
    final stabilized = (bytes[1] & 0x20) != 0;
    if (!stabilized) return null;
    final weight = ((bytes[12] << 8) | bytes[11]) / 200.0;
    if (weight <= 0 || weight > 350) return null;
    final impedance = (bytes[10] << 8) | bytes[9];
    final meters = heightCm / 100;
    return Measurement(
      timestamp: DateTime.now(),
      weightKg: weight,
      impedance: impedance > 0 && impedance < 3000 ? impedance : null,
      bmi: weight / (meters * meters),
    );
  }
}
