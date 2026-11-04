import '../models/measurement.dart';
import '../models/user_profile.dart';
import 'body_metrics.dart';

/// Xiaomi scale 13-byte BLE payload decoder.
/// Ignores unstable weight readings; impedance estimates only when valid.
class ScaleDecoder {
  static Measurement? decode(List<int> bytes, {required UserProfile profile}) {
    if (bytes.length < 13 || !profile.valid || (bytes[1] & 0x20) == 0)
      return null;
    final weight = ((bytes[12] << 8) | bytes[11]) / 200.0;
    if (weight <= 0 || weight > 350) return null;
    final impedance = (bytes[10] << 8) | bytes[9];
    final metrics = BodyMetrics(
        weightKg: weight,
        impedanceOhms: impedance,
        heightCm: profile.heightCm,
        ageYears: profile.ageYears,
        sex: profile.sex);
    final meters = profile.heightCm / 100;
    return Measurement(
      timestamp: DateTime.now(),
      weightKg: weight,
      impedance: metrics.valid ? impedance : null,
      bmi: weight / (meters * meters),
      bodyFatPercent: metrics.valid ? metrics.fatPercent : null,
    );
  }
}
