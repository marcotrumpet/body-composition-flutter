import 'dart:convert';
import 'dart:typed_data';

/// User details written to the FIT `user_profile` message. Garmin uses these
/// to interpret the weight-scale values.
class GarminFitUserProfile {
  const GarminFitUserProfile({
    required this.sex,
    required this.ageYears,
    required this.heightCm,
    this.activityClass = 90,
  });

  final String sex;
  final int ageYears;
  final double heightCm;
  final int activityClass;

  int get _gender => sex == 'female' ? 0 : 1;
}

/// One body-composition reading in the form Garmin's weight FIT file expects.
class GarminFitReading {
  const GarminFitReading({
    required this.timestamp,
    required this.weightKg,
    this.bodyFatPercent,
    this.waterPercent,
    this.boneMassKg,
    this.muscleMassKg,
    this.visceralFatRating,
    this.physiqueRating,
    this.metabolicAge,
    this.bmi,
    this.profile,
  });

  final DateTime timestamp;
  final double weightKg;
  final double? bodyFatPercent;
  final double? waterPercent;
  final double? boneMassKg;
  final double? muscleMassKg;
  final double? visceralFatRating;
  final int? physiqueRating;
  final double? metabolicAge;
  final double? bmi;
  final GarminFitUserProfile? profile;
}

/// Encodes the same `weight` FIT file that WebBodyComposition's backend
/// generates: a file-id, an optional user-profile, and one weight-scale
/// message. Values are scaled exactly as the FIT profile requires.
Uint8List encodeGarminWeightFit(
  GarminFitReading reading, {
  DateTime? createdAt,
}) {
  if (!reading.weightKg.isFinite || reading.weightKg <= 0) {
    throw ArgumentError.value(reading.weightKg, 'weightKg');
  }

  final writer = _FitWriter();
  final now = (createdAt ?? DateTime.now()).toUtc();
  final profile = reading.profile;

  final fileId = <_Field>[
    _Field.enumValue(0, 9), // file: weight
    _Field.uint16(1, 1), // manufacturer: garmin
    _Field.uint16(2, 2429), // product: Garmin Index scale
    _Field.uint32z(3, 1234),
    _Field.uint32(4, _fitDate(now)),
  ]..sort(_byFieldNumber);
  writer.writeDefinition(0, 0, fileId);
  writer.writeData(0, fileId);

  if (profile != null) {
    final userProfile = <_Field>[
      _Field.uint16(254, 0), // message_index
      _Field.enumValue(1, profile._gender),
      _Field.uint8(2, profile.ageYears.clamp(0, 255)),
      _Field.uint8(
        3,
        _rounded(profile.heightCm, min: 0, max: 255),
      ), // height in m * 100; 175 cm -> 1.75 m -> 175
      _Field.uint16(
        4,
        _rounded(reading.weightKg * 10, min: 0, max: 0xFFFF),
      ), // weight in kg * 10
      _Field.enumValue(17, profile.activityClass.clamp(0, 255)),
    ]..sort(_byFieldNumber);
    writer.writeDefinition(1, 3, userProfile);
    writer.writeData(1, userProfile);
  }

  final weightScale = <_Field>[
    _Field.uint32(253, _fitDate(reading.timestamp)),
    _Field.uint16(0, _rounded(reading.weightKg * 100, min: 0, max: 0xFFFF)),
    if (_isPositive(reading.bodyFatPercent))
      _Field.uint16(
        1,
        _rounded(reading.bodyFatPercent! * 100, min: 0, max: 0xFFFF),
      ),
    if (_isPositive(reading.waterPercent))
      _Field.uint16(
        2,
        _rounded(reading.waterPercent! * 100, min: 0, max: 0xFFFF),
      ),
    if (_isPositive(reading.boneMassKg))
      _Field.uint16(
        4,
        _rounded(reading.boneMassKg! * 100, min: 0, max: 0xFFFF),
      ),
    if (_isPositive(reading.muscleMassKg))
      _Field.uint16(
        5,
        _rounded(reading.muscleMassKg! * 100, min: 0, max: 0xFFFF),
      ),
    if (reading.physiqueRating != null)
      _Field.uint8(8, reading.physiqueRating!.clamp(0, 255)),
    if (_isPositive(reading.metabolicAge))
      _Field.uint8(10, _rounded(reading.metabolicAge!, min: 0, max: 255)),
    if (_isPositive(reading.visceralFatRating))
      _Field.uint8(11, _rounded(reading.visceralFatRating!, min: 0, max: 255)),
    if (profile != null) _Field.uint16(12, 0), // user_profile_index
    if (_isPositive(reading.bmi))
      _Field.uint16(13, _rounded(reading.bmi! * 10, min: 0, max: 0xFFFF)),
  ]..sort(_byFieldNumber);
  writer.writeDefinition(profile == null ? 1 : 2, 30, weightScale);
  writer.writeData(profile == null ? 1 : 2, weightScale);

  final data = writer.takeBytes();
  final header = _header(data.length);
  final fileBytes = Uint8List.fromList([...header, ...data]);
  final crc = _fitCrc(fileBytes);
  return Uint8List.fromList([...fileBytes, crc & 0xFF, (crc >> 8) & 0xFF]);
}

int _byFieldNumber(_Field a, _Field b) => a.number.compareTo(b.number);

bool _isPositive(double? value) => value != null && value.isFinite && value > 0;

int _rounded(double value, {required int min, required int max}) =>
    value.isFinite ? value.round().clamp(min, max) : min;

/// FIT timestamps count seconds from 1989-12-31 00:00:00 UTC.
final DateTime _fitEpoch = DateTime.utc(1989, 12, 31);

int _fitDate(DateTime value) {
  final seconds = value.toUtc().difference(_fitEpoch).inSeconds;
  return seconds.clamp(0, 0xFFFFFFFF);
}

Uint8List _header(int dataSize) {
  const profileVersion = 21115;
  final header = Uint8List(14);
  header[0] = 14;
  header[1] = 0x20; // protocol 2.0
  header[2] = profileVersion & 0xFF;
  header[3] = (profileVersion >> 8) & 0xFF;
  header[4] = dataSize & 0xFF;
  header[5] = (dataSize >> 8) & 0xFF;
  header[6] = (dataSize >> 16) & 0xFF;
  header[7] = (dataSize >> 24) & 0xFF;
  header.setAll(8, ascii.encode('.FIT'));
  final crc = _fitCrc(header.sublist(0, 12));
  header[12] = crc & 0xFF;
  header[13] = (crc >> 8) & 0xFF;
  return header;
}

class _FitWriter {
  final BytesBuilder _bytes = BytesBuilder();

  void writeDefinition(int localType, int globalNumber, List<_Field> fields) {
    assert(localType >= 0 && localType <= 15);
    _bytes.addByte(0x40 | localType);
    _bytes.addByte(0); // reserved
    _bytes.addByte(0); // little-endian
    _bytes.add(_u16(globalNumber));
    _bytes.addByte(fields.length);
    for (final field in fields) {
      _bytes.addByte(field.number);
      _bytes.addByte(field.bytes.length);
      _bytes.addByte(field.baseType);
    }
  }

  void writeData(int localType, List<_Field> fields) {
    _bytes.addByte(localType);
    for (final field in fields) {
      _bytes.add(field.bytes);
    }
  }

  Uint8List takeBytes() => _bytes.takeBytes();
}

class _Field {
  _Field._(this.number, this.baseType, this.bytes);

  factory _Field.enumValue(int number, int value) =>
      _Field._(number, 0x00, [value.clamp(0, 0xFF)]);

  factory _Field.uint8(int number, int value) =>
      _Field._(number, 0x02, [value.clamp(0, 0xFF)]);

  factory _Field.uint16(int number, int value) =>
      _Field._(number, 0x84, _u16(value.clamp(0, 0xFFFF)));

  factory _Field.uint32(int number, int value) =>
      _Field._(number, 0x86, _u32(value.clamp(0, 0xFFFFFFFF)));

  factory _Field.uint32z(int number, int value) =>
      _Field._(number, 0x8C, _u32(value.clamp(1, 0xFFFFFFFF)));

  final int number;
  final int baseType;
  final List<int> bytes;
}

List<int> _u16(int value) => [value & 0xFF, (value >> 8) & 0xFF];

List<int> _u32(int value) => [
  value & 0xFF,
  (value >> 8) & 0xFF,
  (value >> 16) & 0xFF,
  (value >> 24) & 0xFF,
];

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

int _fitCrc(List<int> bytes) {
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

/// Seconds between the FIT epoch (1989-12-31 UTC) and [value]. Exposed for
/// tests and for callers that need to inspect file timestamps.
int fitTimestamp(DateTime value) => _fitDate(value);
