import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class UserProfile {
  const UserProfile({required this.heightCm, required this.ageYears, required this.sex});
  final double heightCm;
  final int ageYears;
  final String sex;
  bool get valid => heightCm >= 100 && heightCm <= 250 && ageYears >= 10 && ageYears <= 100 && (sex == 'male' || sex == 'female');
  Map<String, dynamic> toJson() => {'heightCm': heightCm, 'ageYears': ageYears, 'sex': sex};
  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    heightCm: (json['heightCm'] as num).toDouble(),
    ageYears: (json['ageYears'] as num).toInt(),
    sex: json['sex'] as String,
  );
}

class UserProfileStore {
  static const key = 'profile_v1';
  Future<UserProfile?> load() async {
    final raw = (await SharedPreferences.getInstance()).getString(key);
    if (raw == null) return null;
    try {
      final value = UserProfile.fromJson(Map<String, dynamic>.from(jsonDecode(raw) as Map));
      return value.valid ? value : null;
    } catch (_) { return null; }
  }
  Future<void> save(UserProfile profile) async {
    if (!profile.valid) throw ArgumentError('Invalid profile');
    await (await SharedPreferences.getInstance()).setString(key, jsonEncode(profile.toJson()));
  }
}
