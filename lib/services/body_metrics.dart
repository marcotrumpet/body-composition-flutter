import 'dart:math' as math;

/// Estimated metrics derived from Xiaomi impedance and demographic inputs.
/// These are consumer-device estimates, not clinical measurements.
class BodyMetrics {
  const BodyMetrics(
      {required this.weightKg,
      required this.impedanceOhms,
      required this.heightCm,
      required this.ageYears,
      required this.sex});
  final double weightKg;
  final int impedanceOhms;
  final double heightCm;
  final int ageYears;
  final String sex;

  bool get valid =>
      weightKg > 0 &&
      weightKg < 350 &&
      impedanceOhms > 0 &&
      impedanceOhms < 3000 &&
      heightCm >= 100 &&
      heightCm <= 250 &&
      ageYears >= 10 &&
      ageYears <= 100 &&
      (sex == 'male' || sex == 'female');

  double _clamp(double value, double low, double high) =>
      value.clamp(low, high).toDouble();
  double get bmi => weightKg / math.pow(heightCm / 100, 2);
  double get leanBodyCoefficient =>
      (heightCm * 9.058 / 100) * (heightCm / 100) +
      weightKg * 0.32 +
      12.226 -
      impedanceOhms * 0.0068 -
      ageYears * 0.0542;

  double get fatPercent {
    final value = sex == 'female' ? (ageYears <= 49 ? 9.25 : 7.25) : 0.8;
    var coefficient = 1.0;
    if (sex == 'male' && weightKg < 61) {
      coefficient = 0.98;
    } else if (sex == 'female' && weightKg > 60) {
      coefficient = heightCm > 160 ? 1.03 : 0.96;
    } else if (sex == 'female' && weightKg < 50) {
      coefficient = heightCm > 160 ? 1.03 : 1.02;
    }
    var fat =
        (1 - ((leanBodyCoefficient - value) * coefficient / weightKg)) * 100;
    if (fat > 63) fat = 75;
    return _clamp(fat, 5, 75);
  }

  double get boneMassKg {
    final base = sex == 'female' ? 0.245691014 : 0.18016894;
    var bone = (base - leanBodyCoefficient * 0.05158) * -1;
    bone += bone > 2.2 ? 0.1 : -0.1;
    if ((sex == 'female' && bone > 5.1) || (sex == 'male' && bone > 5.2)) {
      bone = 8;
    }
    return _clamp(bone, 0.5, 8);
  }

  double get muscleMassKg {
    var muscle = weightKg * (1 - fatPercent / 100) - boneMassKg;
    if ((sex == 'female' && muscle >= 84) ||
        (sex == 'male' && muscle >= 93.5)) {
      muscle = 120;
    }
    return _clamp(muscle, 10, 120);
  }

  double get waterPercent {
    var water = (100 - fatPercent) * 0.7;
    final coefficient = water <= 50 ? 1.02 : 0.98;
    if (water * coefficient >= 65) water = 75;
    return _clamp(water * coefficient, 35, 75);
  }

  double get proteinPercent =>
      _clamp(muscleMassKg / weightKg * 100 - waterPercent, 5, 32);

  double get basalMetabolicRate {
    var value = sex == 'female'
        ? 864.6 + weightKg * 10.2036 - heightCm * 0.39336 - ageYears * 6.204
        : 877.8 + weightKg * 14.916 - heightCm * 0.726 - ageYears * 8.976;
    if ((sex == 'female' && value > 2996) || (sex == 'male' && value > 2322)) {
      value = 5000;
    }
    return _clamp(value, 500, 10000);
  }
}
