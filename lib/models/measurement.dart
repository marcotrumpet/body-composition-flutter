class Measurement {
  const Measurement({required this.timestamp, required this.weightKg, this.impedance, this.bmi, this.bodyFatPercent});
  final DateTime timestamp;
  final double weightKg;
  final int? impedance;
  final double? bmi;
  final double? bodyFatPercent;
  Map<String, dynamic> toJson() => {'timestamp': timestamp.toIso8601String(), 'weightKg': weightKg, 'impedance': impedance, 'bmi': bmi, 'bodyFatPercent': bodyFatPercent};
  factory Measurement.fromJson(Map<String, dynamic> json) => Measurement(
    timestamp: DateTime.parse(json['timestamp'] as String),
    weightKg: (json['weightKg'] as num).toDouble(),
    impedance: (json['impedance'] as num?)?.toInt(),
    bmi: (json['bmi'] as num?)?.toDouble(),
    bodyFatPercent: (json['bodyFatPercent'] as num?)?.toDouble(),
  );
}
