import 'dart:convert';
import 'dart:typed_data';

import 'package:body_composition_flutter/services/garmin_fit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const profile = GarminFitUserProfile(
    sex: 'male',
    ageYears: 35,
    heightCm: 175,
  );

  GarminFitReading reading({GarminFitUserProfile? userProfile = profile}) {
    return GarminFitReading(
      timestamp: DateTime.utc(2026, 11, 4, 9, 41),
      weightKg: 72.4,
      bodyFatPercent: 21.3,
      waterPercent: 54.0,
      boneMassKg: 2.9,
      muscleMassKg: 54.1,
      visceralFatRating: 11.6,
      physiqueRating: 4,
      metabolicAge: 30.9,
      bmi: 23.6,
      profile: userProfile,
    );
  }

  test('writes a parseable weight FIT file with scaled values', () {
    final bytes = encodeGarminWeightFit(
      reading(),
      createdAt: DateTime.utc(2026, 11, 4, 10),
    );
    final messages = _parseFit(bytes);

    expect(messages, hasLength(3));

    final fileId = messages[0];
    expect(fileId.globalNumber, 0);
    expect(fileId.values[0], 9); // weight file
    expect(fileId.values[1], 1); // Garmin
    expect(fileId.values[2], 2429);
    expect(fileId.values[3], 1234);
    expect(fileId.values[4], fitTimestamp(DateTime.utc(2026, 11, 4, 10)));

    final userProfile = messages[1];
    expect(userProfile.globalNumber, 3);
    expect(userProfile.values[254], 0);
    expect(userProfile.values[1], 1); // male
    expect(userProfile.values[2], 35);
    expect(userProfile.values[3], 175); // metres * 100
    expect(userProfile.values[4], 724); // kg * 10
    expect(userProfile.values[17], 90);

    final weightScale = messages[2];
    expect(weightScale.globalNumber, 30);
    expect(
      weightScale.values[253],
      fitTimestamp(DateTime.utc(2026, 11, 4, 9, 41)),
    );
    expect(weightScale.values[0], 7240); // kg * 100
    expect(weightScale.values[1], 2130); // % * 100
    expect(weightScale.values[2], 5400);
    expect(weightScale.values[4], 290);
    expect(weightScale.values[5], 5410);
    expect(weightScale.values[8], 4);
    expect(weightScale.values[10], 31);
    expect(weightScale.values[11], 12);
    expect(weightScale.values[12], 0);
    expect(weightScale.values[13], 236); // BMI * 10
  });

  test('omits the user profile when no profile is available', () {
    final bytes = encodeGarminWeightFit(
      reading(userProfile: null),
      createdAt: DateTime.utc(2026, 11, 4, 10),
    );
    final messages = _parseFit(bytes);

    expect(messages, hasLength(2));
    expect(messages[0].globalNumber, 0);
    expect(messages[1].globalNumber, 30);
    expect(messages[1].values.containsKey(12), isFalse);
  });

  test('rejects a non-positive weight', () {
    expect(
      () => encodeGarminWeightFit(
        GarminFitReading(timestamp: DateTime.utc(2026, 11, 4), weightKg: 0),
      ),
      throwsArgumentError,
    );
  });

  test('converts timestamps to the FIT epoch', () {
    expect(fitTimestamp(DateTime.utc(1989, 12, 31)), 0);
    expect(fitTimestamp(DateTime.utc(1990, 1, 1)), 86400);
  });
}

class _ParsedMessage {
  const _ParsedMessage(this.globalNumber, this.values);

  final int globalNumber;
  final Map<int, int> values;
}

class _Definition {
  const _Definition(this.globalNumber, this.fields);

  final int globalNumber;
  final List<_FieldDefinition> fields;
}

class _FieldDefinition {
  const _FieldDefinition(this.number, this.size);

  final int number;
  final int size;
}

List<_ParsedMessage> _parseFit(Uint8List bytes) {
  expect(bytes[0], 14);
  expect(bytes[1], 0x20);
  expect(ascii.decode(bytes.sublist(8, 12)), '.FIT');

  final data = ByteData.sublistView(bytes);
  final dataSize = data.getUint32(4, Endian.little);
  final headerCrc = _crc(bytes.sublist(0, 12));
  expect(bytes[12] | (bytes[13] << 8), headerCrc);

  final fileCrc = _crc(bytes.sublist(0, bytes.length - 2));
  expect(bytes[bytes.length - 2] | (bytes[bytes.length - 1] << 8), fileCrc);

  final end = 14 + dataSize;
  expect(end, bytes.length - 2);

  final definitions = <int, _Definition>{};
  final messages = <_ParsedMessage>[];
  var offset = 14;

  while (offset < end) {
    final header = bytes[offset++];
    expect(header & 0x80, 0, reason: 'compressed timestamps are not used');
    final localType = header & 0x0F;

    if (header & 0x40 != 0) {
      offset++; // reserved
      expect(bytes[offset++], 0); // little-endian
      final globalNumber = bytes[offset] | (bytes[offset + 1] << 8);
      offset += 2;
      final fieldCount = bytes[offset++];
      final fields = <_FieldDefinition>[];
      for (var index = 0; index < fieldCount; index++) {
        final number = bytes[offset++];
        final size = bytes[offset++];
        offset++; // base type
        fields.add(_FieldDefinition(number, size));
      }
      definitions[localType] = _Definition(globalNumber, fields);
      continue;
    }

    final definition = definitions[localType];
    expect(definition, isNotNull, reason: 'data before definition');
    final values = <int, int>{};
    for (final field in definition!.fields) {
      var value = 0;
      for (var index = 0; index < field.size; index++) {
        value |= bytes[offset + index] << (8 * index);
      }
      offset += field.size;
      values[field.number] = value;
    }
    messages.add(_ParsedMessage(definition.globalNumber, values));
  }

  expect(offset, end);
  return messages;
}

const List<int> _crcTable = [
  0x0000,
  0xCC01,
  0xD801,
  0x1400,
  0xF001,
  0x3C00,
  0x2800,
  0xE401,
  0xA001,
  0x6C00,
  0x7800,
  0xB401,
  0x5000,
  0x9C01,
  0x8801,
  0x4400,
];

int _crc(List<int> bytes) {
  var crc = 0;
  for (final byte in bytes) {
    var tmp = _crcTable[crc & 0xF];
    crc = (crc >> 4) & 0x0FFF;
    crc = crc ^ tmp ^ _crcTable[byte & 0xF];
    tmp = _crcTable[crc & 0xF];
    crc = (crc >> 4) & 0x0FFF;
    crc = crc ^ tmp ^ _crcTable[(byte >> 4) & 0xF];
  }
  return crc & 0xFFFF;
}
