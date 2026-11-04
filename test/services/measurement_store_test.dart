import 'package:body_composition_flutter/models/measurement.dart';
import 'package:body_composition_flutter/services/measurement_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Measurement _measurement({
  required DateTime timestamp,
  double weightKg = 72.4,
}) {
  return Measurement(timestamp: timestamp, weightKg: weightKg, bmi: 22.3);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('loads an empty list when nothing was saved', () async {
    expect(await MeasurementStore().load(), isEmpty);
  });

  test('save and load sort newest first', () async {
    final store = MeasurementStore();
    final older = _measurement(
      timestamp: DateTime(2026, 11, 1, 9),
      weightKg: 72.1,
    );
    final newer = _measurement(
      timestamp: DateTime(2026, 11, 3, 9),
      weightKg: 72.4,
    );

    await store.save(older);
    await store.save(newer);

    final loaded = await store.load();
    expect(loaded, hasLength(2));
    expect(loaded.first.timestamp, newer.timestamp);
    expect(loaded.last.timestamp, older.timestamp);
  });

  test('corrupt stored JSON throws a typed storage exception', () async {
    SharedPreferences.setMockInitialValues({
      'measurements_v1': 'not valid json',
    });

    await expectLater(
      MeasurementStore().load(),
      throwsA(isA<MeasurementStorageException>()),
    );
  });

  test('clear removes saved history', () async {
    final store = MeasurementStore();
    await store.save(_measurement(timestamp: DateTime(2026, 11, 1, 9)));

    await store.clear();

    expect(await store.load(), isEmpty);
  });

  test('replaceAll persists the supplied values newest first', () async {
    final store = MeasurementStore();
    final first = _measurement(
      timestamp: DateTime(2026, 11, 1, 9),
      weightKg: 71.0,
    );
    final second = _measurement(
      timestamp: DateTime(2026, 11, 2, 9),
      weightKg: 71.5,
    );

    await store.replaceAll([first, second]);

    final loaded = await store.load();
    expect(loaded.map((item) => item.weightKg), [71.5, 71.0]);
  });
}
