import '../models/measurement.dart';
import '../models/user_profile.dart';
import 'body_metrics.dart';

/// Xiaomi scale 13-byte BLE payload decoder.
/// Ignores unstable weight readings; impedance estimates only when valid.
class ScaleDecoder {
  /// Weight is always recorded. BMI and body-fat estimates are added only
  /// when a valid profile is available; raw impedance is kept whenever the
  /// scale reports a plausible value.
  static Measurement? decode(List<int> bytes, {UserProfile? profile}) {
    if (bytes.length < 13 || (bytes[1] & 0x20) == 0) return null;
    final weight = ((bytes[12] << 8) | bytes[11]) / 200.0;
    if (weight <= 0 || weight > 350) return null;

    final rawImpedance = (bytes[10] << 8) | bytes[9];
    final impedance = rawImpedance > 0 && rawImpedance < 3000
        ? rawImpedance
        : null;

    double? bmi;
    double? bodyFat;
    if (profile != null && profile.valid) {
      final meters = profile.heightCm / 100;
      bmi = weight / (meters * meters);
      final metrics = BodyMetrics(
        weightKg: weight,
        impedanceOhms: rawImpedance,
        heightCm: profile.heightCm,
        ageYears: profile.ageYears,
        sex: profile.sex,
      );
      if (metrics.valid) bodyFat = metrics.fatPercent;
    }

    return Measurement(
      timestamp: DateTime.now(),
      weightKg: weight,
      impedance: impedance,
      bmi: bmi,
      bodyFatPercent: bodyFat,
    );
  }
}
