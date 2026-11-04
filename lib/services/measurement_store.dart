import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/measurement.dart';

class MeasurementStore {
  static const _key = 'measurements_v1';
  Future<List<Measurement>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((e) => Measurement.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  Future<void> save(Measurement value) async {
    final all = await load();
    all.insert(0, value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _key, jsonEncode(all.map((e) => e.toJson()).toList()));
  }
}
