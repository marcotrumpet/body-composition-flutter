import 'dart:math' as math;

/// Estimated metrics derived from Xiaomi impedance and demographic inputs.
/// These are consumer-device estimates, not clinical measurements.
class BodyMetrics {
  const BodyMetrics({
    required this.weightKg,
    required this.impedanceOhms,
    required this.heightCm,
    required this.ageYears,
    required this.sex,
  });
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

  /// Visceral fat rating in the 1–50 range used by Xiaomi scales and Garmin.
  /// Mirrors the formula in the upstream WebBodyComposition project.
  double get visceralFatRating {
    double value;
    if (sex == 'female') {
      if (weightKg > (13 - heightCm * 0.5) * -1) {
        final divisor =
            (heightCm * 1.45) + (heightCm * 0.1158) * heightCm - 120;
        final subcalc = weightKg * 500 / divisor;
        value = (subcalc - 6) + ageYears * 0.07;
      } else {
        final subcalc = 0.691 + heightCm * -0.0024 + heightCm * -0.0024;
        value =
            ((heightCm * 0.027) - (subcalc * weightKg)) * -1 +
            ageYears * 0.07 -
            ageYears;
      }
    } else if (heightCm < weightKg * 1.6) {
      final subcalc =
          ((heightCm * 0.4) - (heightCm * (heightCm * 0.0826))) * -1;
      value = (weightKg * 305) / (subcalc + 48) - 2.9 + ageYears * 0.15;
    } else {
      final subcalc = 0.765 + heightCm * -0.0015;
      value =
          ((heightCm * 0.143) - (weightKg * subcalc)) * -1 +
          ageYears * 0.15 -
          5.0;
    }
    return _clamp(value, 1, 50);
  }

  /// Estimated metabolic age in years, clamped to the 15–80 range Garmin and
  /// Xiaomi report.
  double get metabolicAge {
    final value = sex == 'female'
        ? heightCm * -1.1165 +
              weightKg * 1.5784 +
              ageYears * 0.4615 +
              impedanceOhms * 0.0415 +
              83.2548
        : heightCm * -0.7471 +
              weightKg * 0.9161 +
              ageYears * 0.4184 +
              impedanceOhms * 0.0517 +
              54.2267;
    return _clamp(value, 15, 80);
  }

  /// Xiaomi-style physique rating (0–8), matching the upstream project's
  /// body-type calculation.
  int get physiqueRating {
    final fatScale = _fatPercentageScale;
    final int fatFactor;
    if (fatPercent > fatScale[2]) {
      fatFactor = 0;
    } else if (fatPercent < fatScale[1]) {
      fatFactor = 2;
    } else {
      fatFactor = 1;
    }

    final muscleScale = _muscleMassScale;
    if (muscleMassKg > muscleScale[1]) return 2 + fatFactor * 3;
    if (muscleMassKg < muscleScale[0]) return fatFactor * 3;
    return 1 + fatFactor * 3;
  }

  List<double> get _fatPercentageScale {
    if (sex == 'female') {
      if (ageYears < 12) return const [12, 21, 30, 34];
      if (ageYears < 14) return const [15, 24, 33, 37];
      if (ageYears < 16) return const [18, 27, 36, 40];
      if (ageYears < 18) return const [20, 28, 37, 41];
      if (ageYears < 40) return const [21, 28, 35, 40];
      if (ageYears < 60) return const [22, 29, 36, 41];
      if (ageYears < 100) return const [23, 30, 37, 42];
      return const [23, 30, 37, 42];
    }
    if (ageYears >= 18 && ageYears < 40) return const [11, 17, 22, 27];
    if (ageYears >= 40 && ageYears < 60) return const [12, 18, 23, 28];
    if (ageYears >= 60) return const [14, 20, 25, 30];
    return const [7, 16, 25, 30];
  }

  List<double> get _muscleMassScale {
    if (sex == 'female') {
      if (heightCm >= 160) return const [36.5, 42.6];
      if (heightCm >= 150) return const [32.9, 37.6];
      return const [29.1, 34.8];
    }
    if (heightCm >= 170) return const [49.4, 59.5];
    if (heightCm >= 160) return const [44.0, 52.5];
    return const [38.5, 46.6];
  }

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
