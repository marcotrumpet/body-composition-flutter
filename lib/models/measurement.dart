import '../services/body_metrics.dart';
import 'user_profile.dart';

class Measurement {
  const Measurement({
    required this.timestamp,
    required this.weightKg,
    this.impedance,
    this.bmi,
    this.bodyFatPercent,
  });
  final DateTime timestamp;
  final double weightKg;
  final int? impedance;
  final double? bmi;
  final double? bodyFatPercent;
  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'weightKg': weightKg,
    'impedance': impedance,
    'bmi': bmi,
    'bodyFatPercent': bodyFatPercent,
  };
  factory Measurement.fromJson(Map<String, dynamic> json) => Measurement(
    timestamp: DateTime.parse(json['timestamp'] as String),
    weightKg: (json['weightKg'] as num).toDouble(),
    impedance: (json['impedance'] as num?)?.toInt(),
    bmi: (json['bmi'] as num?)?.toDouble(),
    bodyFatPercent: (json['bodyFatPercent'] as num?)?.toDouble(),
  );

  /// Body-composition estimates for this reading, when impedance and a valid
  /// profile are available. Shared by the dashboard, profile edits and the
  /// Garmin upload so every surface uses the same numbers.
  BodyMetrics? estimatesFor(UserProfile? profile) {
    final ohms = impedance;
    if (profile == null || !profile.valid || ohms == null) return null;
    final metrics = BodyMetrics(
      weightKg: weightKg,
      impedanceOhms: ohms,
      heightCm: profile.heightCm,
      ageYears: profile.ageYears,
      sex: profile.sex,
    );
    return metrics.valid ? metrics : null;
  }

  /// Recomputes derived values for the current profile. Used after a profile
  /// edit so historical estimates do not silently reflect an old height/age.
  Measurement recomputedWith(UserProfile? profile) {
    double? nextBmi;
    double? nextBodyFat;
    if (profile != null && profile.valid) {
      final meters = profile.heightCm / 100;
      nextBmi = weightKg / (meters * meters);
      nextBodyFat = estimatesFor(profile)?.fatPercent;
    }
    return Measurement(
      timestamp: timestamp,
      weightKg: weightKg,
      impedance: impedance,
      bmi: nextBmi,
      bodyFatPercent: nextBodyFat,
    );
  }
}
