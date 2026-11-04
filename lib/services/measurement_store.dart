import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/measurement.dart';

class MeasurementStorageException implements Exception {
  const MeasurementStorageException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => 'MeasurementStorageException: $message';
}

class MeasurementStore {
  static const _key = 'measurements_v1';

  Future<List<Measurement>> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        throw const FormatException('Measurements are not a list');
      }
      return decoded
          .map((item) =>
              Measurement.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    } catch (error) {
      throw MeasurementStorageException(
        'Saved measurements could not be read.',
        cause: error,
      );
    }
  }

  Future<void> save(Measurement value) async {
    final all = await load();
    all.insert(0, value);
    await replaceAll(all);
  }

  Future<void> replaceAll(List<Measurement> values) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sorted = [...values]
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
      final encoded = jsonEncode(sorted.map((item) => item.toJson()).toList());
      final saved = await prefs.setString(_key, encoded);
      if (!saved) {
        throw const MeasurementStorageException('Measurements were not saved.');
      }
    } on MeasurementStorageException {
      rethrow;
    } catch (error) {
      throw MeasurementStorageException(
        'Measurements could not be saved.',
        cause: error,
      );
    }
  }

  Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final removed = await prefs.remove(_key);
      if (!removed) {
        throw const MeasurementStorageException('Measurements were not cleared.');
      }
    } on MeasurementStorageException {
      rethrow;
    } catch (error) {
      throw MeasurementStorageException(
        'Measurements could not be cleared.',
        cause: error,
      );
    }
  }
}
