// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $AppSettingsTable extends AppSettings
    with TableInfo<$AppSettingsTable, AppSetting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppSettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 128,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<AppSetting> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  AppSetting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppSetting(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $AppSettingsTable createAlias(String alias) {
    return $AppSettingsTable(attachedDatabase, alias);
  }
}

class AppSetting extends DataClass implements Insertable<AppSetting> {
  final String key;
  final String value;
  const AppSetting({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  AppSettingsCompanion toCompanion(bool nullToAbsent) {
    return AppSettingsCompanion(key: Value(key), value: Value(value));
  }

  factory AppSetting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppSetting(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  AppSetting copyWith({String? key, String? value}) =>
      AppSetting(key: key ?? this.key, value: value ?? this.value);
  AppSetting copyWithCompanion(AppSettingsCompanion data) {
    return AppSetting(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppSetting(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppSetting &&
          other.key == this.key &&
          other.value == this.value);
}

class AppSettingsCompanion extends UpdateCompanion<AppSetting> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const AppSettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppSettingsCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<AppSetting> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppSettingsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return AppSettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppSettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ObservingLocationsTable extends ObservingLocations
    with TableInfo<$ObservingLocationsTable, ObservingLocationRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ObservingLocationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 100,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _latitudeMeta = const VerificationMeta(
    'latitude',
  );
  @override
  late final GeneratedColumn<double> latitude = GeneratedColumn<double>(
    'latitude',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _longitudeMeta = const VerificationMeta(
    'longitude',
  );
  @override
  late final GeneratedColumn<double> longitude = GeneratedColumn<double>(
    'longitude',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _elevationMetersMeta = const VerificationMeta(
    'elevationMeters',
  );
  @override
  late final GeneratedColumn<double> elevationMeters = GeneratedColumn<double>(
    'elevation_meters',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _timeZoneMeta = const VerificationMeta(
    'timeZone',
  );
  @override
  late final GeneratedColumn<String> timeZone = GeneratedColumn<String>(
    'time_zone',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isDefaultMeta = const VerificationMeta(
    'isDefault',
  );
  @override
  late final GeneratedColumn<bool> isDefault = GeneratedColumn<bool>(
    'is_default',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_default" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    latitude,
    longitude,
    elevationMeters,
    timeZone,
    isDefault,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'observing_locations';
  @override
  VerificationContext validateIntegrity(
    Insertable<ObservingLocationRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('latitude')) {
      context.handle(
        _latitudeMeta,
        latitude.isAcceptableOrUnknown(data['latitude']!, _latitudeMeta),
      );
    } else if (isInserting) {
      context.missing(_latitudeMeta);
    }
    if (data.containsKey('longitude')) {
      context.handle(
        _longitudeMeta,
        longitude.isAcceptableOrUnknown(data['longitude']!, _longitudeMeta),
      );
    } else if (isInserting) {
      context.missing(_longitudeMeta);
    }
    if (data.containsKey('elevation_meters')) {
      context.handle(
        _elevationMetersMeta,
        elevationMeters.isAcceptableOrUnknown(
          data['elevation_meters']!,
          _elevationMetersMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_elevationMetersMeta);
    }
    if (data.containsKey('time_zone')) {
      context.handle(
        _timeZoneMeta,
        timeZone.isAcceptableOrUnknown(data['time_zone']!, _timeZoneMeta),
      );
    } else if (isInserting) {
      context.missing(_timeZoneMeta);
    }
    if (data.containsKey('is_default')) {
      context.handle(
        _isDefaultMeta,
        isDefault.isAcceptableOrUnknown(data['is_default']!, _isDefaultMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ObservingLocationRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ObservingLocationRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      latitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}latitude'],
      )!,
      longitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}longitude'],
      )!,
      elevationMeters: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}elevation_meters'],
      )!,
      timeZone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}time_zone'],
      )!,
      isDefault: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_default'],
      )!,
    );
  }

  @override
  $ObservingLocationsTable createAlias(String alias) {
    return $ObservingLocationsTable(attachedDatabase, alias);
  }
}

class ObservingLocationRow extends DataClass
    implements Insertable<ObservingLocationRow> {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final double elevationMeters;
  final String timeZone;
  final bool isDefault;
  const ObservingLocationRow({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.elevationMeters,
    required this.timeZone,
    required this.isDefault,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['latitude'] = Variable<double>(latitude);
    map['longitude'] = Variable<double>(longitude);
    map['elevation_meters'] = Variable<double>(elevationMeters);
    map['time_zone'] = Variable<String>(timeZone);
    map['is_default'] = Variable<bool>(isDefault);
    return map;
  }

  ObservingLocationsCompanion toCompanion(bool nullToAbsent) {
    return ObservingLocationsCompanion(
      id: Value(id),
      name: Value(name),
      latitude: Value(latitude),
      longitude: Value(longitude),
      elevationMeters: Value(elevationMeters),
      timeZone: Value(timeZone),
      isDefault: Value(isDefault),
    );
  }

  factory ObservingLocationRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ObservingLocationRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      latitude: serializer.fromJson<double>(json['latitude']),
      longitude: serializer.fromJson<double>(json['longitude']),
      elevationMeters: serializer.fromJson<double>(json['elevationMeters']),
      timeZone: serializer.fromJson<String>(json['timeZone']),
      isDefault: serializer.fromJson<bool>(json['isDefault']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'latitude': serializer.toJson<double>(latitude),
      'longitude': serializer.toJson<double>(longitude),
      'elevationMeters': serializer.toJson<double>(elevationMeters),
      'timeZone': serializer.toJson<String>(timeZone),
      'isDefault': serializer.toJson<bool>(isDefault),
    };
  }

  ObservingLocationRow copyWith({
    String? id,
    String? name,
    double? latitude,
    double? longitude,
    double? elevationMeters,
    String? timeZone,
    bool? isDefault,
  }) => ObservingLocationRow(
    id: id ?? this.id,
    name: name ?? this.name,
    latitude: latitude ?? this.latitude,
    longitude: longitude ?? this.longitude,
    elevationMeters: elevationMeters ?? this.elevationMeters,
    timeZone: timeZone ?? this.timeZone,
    isDefault: isDefault ?? this.isDefault,
  );
  ObservingLocationRow copyWithCompanion(ObservingLocationsCompanion data) {
    return ObservingLocationRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      latitude: data.latitude.present ? data.latitude.value : this.latitude,
      longitude: data.longitude.present ? data.longitude.value : this.longitude,
      elevationMeters: data.elevationMeters.present
          ? data.elevationMeters.value
          : this.elevationMeters,
      timeZone: data.timeZone.present ? data.timeZone.value : this.timeZone,
      isDefault: data.isDefault.present ? data.isDefault.value : this.isDefault,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ObservingLocationRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('elevationMeters: $elevationMeters, ')
          ..write('timeZone: $timeZone, ')
          ..write('isDefault: $isDefault')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    latitude,
    longitude,
    elevationMeters,
    timeZone,
    isDefault,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ObservingLocationRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.latitude == this.latitude &&
          other.longitude == this.longitude &&
          other.elevationMeters == this.elevationMeters &&
          other.timeZone == this.timeZone &&
          other.isDefault == this.isDefault);
}

class ObservingLocationsCompanion
    extends UpdateCompanion<ObservingLocationRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<double> latitude;
  final Value<double> longitude;
  final Value<double> elevationMeters;
  final Value<String> timeZone;
  final Value<bool> isDefault;
  final Value<int> rowid;
  const ObservingLocationsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.latitude = const Value.absent(),
    this.longitude = const Value.absent(),
    this.elevationMeters = const Value.absent(),
    this.timeZone = const Value.absent(),
    this.isDefault = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ObservingLocationsCompanion.insert({
    required String id,
    required String name,
    required double latitude,
    required double longitude,
    required double elevationMeters,
    required String timeZone,
    this.isDefault = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       latitude = Value(latitude),
       longitude = Value(longitude),
       elevationMeters = Value(elevationMeters),
       timeZone = Value(timeZone);
  static Insertable<ObservingLocationRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<double>? latitude,
    Expression<double>? longitude,
    Expression<double>? elevationMeters,
    Expression<String>? timeZone,
    Expression<bool>? isDefault,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (elevationMeters != null) 'elevation_meters': elevationMeters,
      if (timeZone != null) 'time_zone': timeZone,
      if (isDefault != null) 'is_default': isDefault,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ObservingLocationsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<double>? latitude,
    Value<double>? longitude,
    Value<double>? elevationMeters,
    Value<String>? timeZone,
    Value<bool>? isDefault,
    Value<int>? rowid,
  }) {
    return ObservingLocationsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      elevationMeters: elevationMeters ?? this.elevationMeters,
      timeZone: timeZone ?? this.timeZone,
      isDefault: isDefault ?? this.isDefault,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (latitude.present) {
      map['latitude'] = Variable<double>(latitude.value);
    }
    if (longitude.present) {
      map['longitude'] = Variable<double>(longitude.value);
    }
    if (elevationMeters.present) {
      map['elevation_meters'] = Variable<double>(elevationMeters.value);
    }
    if (timeZone.present) {
      map['time_zone'] = Variable<String>(timeZone.value);
    }
    if (isDefault.present) {
      map['is_default'] = Variable<bool>(isDefault.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ObservingLocationsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('elevationMeters: $elevationMeters, ')
          ..write('timeZone: $timeZone, ')
          ..write('isDefault: $isDefault, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $EquipmentItemsTable extends EquipmentItems
    with TableInfo<$EquipmentItemsTable, EquipmentItemRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EquipmentItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 120,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sensorWidthMmMeta = const VerificationMeta(
    'sensorWidthMm',
  );
  @override
  late final GeneratedColumn<double> sensorWidthMm = GeneratedColumn<double>(
    'sensor_width_mm',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sensorHeightMmMeta = const VerificationMeta(
    'sensorHeightMm',
  );
  @override
  late final GeneratedColumn<double> sensorHeightMm = GeneratedColumn<double>(
    'sensor_height_mm',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _resolutionXMeta = const VerificationMeta(
    'resolutionX',
  );
  @override
  late final GeneratedColumn<int> resolutionX = GeneratedColumn<int>(
    'resolution_x',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _resolutionYMeta = const VerificationMeta(
    'resolutionY',
  );
  @override
  late final GeneratedColumn<int> resolutionY = GeneratedColumn<int>(
    'resolution_y',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _focalLengthMmMeta = const VerificationMeta(
    'focalLengthMm',
  );
  @override
  late final GeneratedColumn<double> focalLengthMm = GeneratedColumn<double>(
    'focal_length_mm',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _apertureMmMeta = const VerificationMeta(
    'apertureMm',
  );
  @override
  late final GeneratedColumn<double> apertureMm = GeneratedColumn<double>(
    'aperture_mm',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _payloadCapacityKgMeta = const VerificationMeta(
    'payloadCapacityKg',
  );
  @override
  late final GeneratedColumn<double> payloadCapacityKg =
      GeneratedColumn<double>(
        'payload_capacity_kg',
        aliasedName,
        true,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    kind,
    sensorWidthMm,
    sensorHeightMm,
    resolutionX,
    resolutionY,
    focalLengthMm,
    apertureMm,
    payloadCapacityKg,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'equipment_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<EquipmentItemRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('sensor_width_mm')) {
      context.handle(
        _sensorWidthMmMeta,
        sensorWidthMm.isAcceptableOrUnknown(
          data['sensor_width_mm']!,
          _sensorWidthMmMeta,
        ),
      );
    }
    if (data.containsKey('sensor_height_mm')) {
      context.handle(
        _sensorHeightMmMeta,
        sensorHeightMm.isAcceptableOrUnknown(
          data['sensor_height_mm']!,
          _sensorHeightMmMeta,
        ),
      );
    }
    if (data.containsKey('resolution_x')) {
      context.handle(
        _resolutionXMeta,
        resolutionX.isAcceptableOrUnknown(
          data['resolution_x']!,
          _resolutionXMeta,
        ),
      );
    }
    if (data.containsKey('resolution_y')) {
      context.handle(
        _resolutionYMeta,
        resolutionY.isAcceptableOrUnknown(
          data['resolution_y']!,
          _resolutionYMeta,
        ),
      );
    }
    if (data.containsKey('focal_length_mm')) {
      context.handle(
        _focalLengthMmMeta,
        focalLengthMm.isAcceptableOrUnknown(
          data['focal_length_mm']!,
          _focalLengthMmMeta,
        ),
      );
    }
    if (data.containsKey('aperture_mm')) {
      context.handle(
        _apertureMmMeta,
        apertureMm.isAcceptableOrUnknown(data['aperture_mm']!, _apertureMmMeta),
      );
    }
    if (data.containsKey('payload_capacity_kg')) {
      context.handle(
        _payloadCapacityKgMeta,
        payloadCapacityKg.isAcceptableOrUnknown(
          data['payload_capacity_kg']!,
          _payloadCapacityKgMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  EquipmentItemRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EquipmentItemRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      sensorWidthMm: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}sensor_width_mm'],
      ),
      sensorHeightMm: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}sensor_height_mm'],
      ),
      resolutionX: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}resolution_x'],
      ),
      resolutionY: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}resolution_y'],
      ),
      focalLengthMm: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}focal_length_mm'],
      ),
      apertureMm: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}aperture_mm'],
      ),
      payloadCapacityKg: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}payload_capacity_kg'],
      ),
    );
  }

  @override
  $EquipmentItemsTable createAlias(String alias) {
    return $EquipmentItemsTable(attachedDatabase, alias);
  }
}

class EquipmentItemRow extends DataClass
    implements Insertable<EquipmentItemRow> {
  final String id;
  final String name;
  final String kind;
  final double? sensorWidthMm;
  final double? sensorHeightMm;
  final int? resolutionX;
  final int? resolutionY;
  final double? focalLengthMm;
  final double? apertureMm;
  final double? payloadCapacityKg;
  const EquipmentItemRow({
    required this.id,
    required this.name,
    required this.kind,
    this.sensorWidthMm,
    this.sensorHeightMm,
    this.resolutionX,
    this.resolutionY,
    this.focalLengthMm,
    this.apertureMm,
    this.payloadCapacityKg,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['kind'] = Variable<String>(kind);
    if (!nullToAbsent || sensorWidthMm != null) {
      map['sensor_width_mm'] = Variable<double>(sensorWidthMm);
    }
    if (!nullToAbsent || sensorHeightMm != null) {
      map['sensor_height_mm'] = Variable<double>(sensorHeightMm);
    }
    if (!nullToAbsent || resolutionX != null) {
      map['resolution_x'] = Variable<int>(resolutionX);
    }
    if (!nullToAbsent || resolutionY != null) {
      map['resolution_y'] = Variable<int>(resolutionY);
    }
    if (!nullToAbsent || focalLengthMm != null) {
      map['focal_length_mm'] = Variable<double>(focalLengthMm);
    }
    if (!nullToAbsent || apertureMm != null) {
      map['aperture_mm'] = Variable<double>(apertureMm);
    }
    if (!nullToAbsent || payloadCapacityKg != null) {
      map['payload_capacity_kg'] = Variable<double>(payloadCapacityKg);
    }
    return map;
  }

  EquipmentItemsCompanion toCompanion(bool nullToAbsent) {
    return EquipmentItemsCompanion(
      id: Value(id),
      name: Value(name),
      kind: Value(kind),
      sensorWidthMm: sensorWidthMm == null && nullToAbsent
          ? const Value.absent()
          : Value(sensorWidthMm),
      sensorHeightMm: sensorHeightMm == null && nullToAbsent
          ? const Value.absent()
          : Value(sensorHeightMm),
      resolutionX: resolutionX == null && nullToAbsent
          ? const Value.absent()
          : Value(resolutionX),
      resolutionY: resolutionY == null && nullToAbsent
          ? const Value.absent()
          : Value(resolutionY),
      focalLengthMm: focalLengthMm == null && nullToAbsent
          ? const Value.absent()
          : Value(focalLengthMm),
      apertureMm: apertureMm == null && nullToAbsent
          ? const Value.absent()
          : Value(apertureMm),
      payloadCapacityKg: payloadCapacityKg == null && nullToAbsent
          ? const Value.absent()
          : Value(payloadCapacityKg),
    );
  }

  factory EquipmentItemRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EquipmentItemRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      kind: serializer.fromJson<String>(json['kind']),
      sensorWidthMm: serializer.fromJson<double?>(json['sensorWidthMm']),
      sensorHeightMm: serializer.fromJson<double?>(json['sensorHeightMm']),
      resolutionX: serializer.fromJson<int?>(json['resolutionX']),
      resolutionY: serializer.fromJson<int?>(json['resolutionY']),
      focalLengthMm: serializer.fromJson<double?>(json['focalLengthMm']),
      apertureMm: serializer.fromJson<double?>(json['apertureMm']),
      payloadCapacityKg: serializer.fromJson<double?>(
        json['payloadCapacityKg'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'kind': serializer.toJson<String>(kind),
      'sensorWidthMm': serializer.toJson<double?>(sensorWidthMm),
      'sensorHeightMm': serializer.toJson<double?>(sensorHeightMm),
      'resolutionX': serializer.toJson<int?>(resolutionX),
      'resolutionY': serializer.toJson<int?>(resolutionY),
      'focalLengthMm': serializer.toJson<double?>(focalLengthMm),
      'apertureMm': serializer.toJson<double?>(apertureMm),
      'payloadCapacityKg': serializer.toJson<double?>(payloadCapacityKg),
    };
  }

  EquipmentItemRow copyWith({
    String? id,
    String? name,
    String? kind,
    Value<double?> sensorWidthMm = const Value.absent(),
    Value<double?> sensorHeightMm = const Value.absent(),
    Value<int?> resolutionX = const Value.absent(),
    Value<int?> resolutionY = const Value.absent(),
    Value<double?> focalLengthMm = const Value.absent(),
    Value<double?> apertureMm = const Value.absent(),
    Value<double?> payloadCapacityKg = const Value.absent(),
  }) => EquipmentItemRow(
    id: id ?? this.id,
    name: name ?? this.name,
    kind: kind ?? this.kind,
    sensorWidthMm: sensorWidthMm.present
        ? sensorWidthMm.value
        : this.sensorWidthMm,
    sensorHeightMm: sensorHeightMm.present
        ? sensorHeightMm.value
        : this.sensorHeightMm,
    resolutionX: resolutionX.present ? resolutionX.value : this.resolutionX,
    resolutionY: resolutionY.present ? resolutionY.value : this.resolutionY,
    focalLengthMm: focalLengthMm.present
        ? focalLengthMm.value
        : this.focalLengthMm,
    apertureMm: apertureMm.present ? apertureMm.value : this.apertureMm,
    payloadCapacityKg: payloadCapacityKg.present
        ? payloadCapacityKg.value
        : this.payloadCapacityKg,
  );
  EquipmentItemRow copyWithCompanion(EquipmentItemsCompanion data) {
    return EquipmentItemRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      kind: data.kind.present ? data.kind.value : this.kind,
      sensorWidthMm: data.sensorWidthMm.present
          ? data.sensorWidthMm.value
          : this.sensorWidthMm,
      sensorHeightMm: data.sensorHeightMm.present
          ? data.sensorHeightMm.value
          : this.sensorHeightMm,
      resolutionX: data.resolutionX.present
          ? data.resolutionX.value
          : this.resolutionX,
      resolutionY: data.resolutionY.present
          ? data.resolutionY.value
          : this.resolutionY,
      focalLengthMm: data.focalLengthMm.present
          ? data.focalLengthMm.value
          : this.focalLengthMm,
      apertureMm: data.apertureMm.present
          ? data.apertureMm.value
          : this.apertureMm,
      payloadCapacityKg: data.payloadCapacityKg.present
          ? data.payloadCapacityKg.value
          : this.payloadCapacityKg,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EquipmentItemRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('kind: $kind, ')
          ..write('sensorWidthMm: $sensorWidthMm, ')
          ..write('sensorHeightMm: $sensorHeightMm, ')
          ..write('resolutionX: $resolutionX, ')
          ..write('resolutionY: $resolutionY, ')
          ..write('focalLengthMm: $focalLengthMm, ')
          ..write('apertureMm: $apertureMm, ')
          ..write('payloadCapacityKg: $payloadCapacityKg')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    kind,
    sensorWidthMm,
    sensorHeightMm,
    resolutionX,
    resolutionY,
    focalLengthMm,
    apertureMm,
    payloadCapacityKg,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EquipmentItemRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.kind == this.kind &&
          other.sensorWidthMm == this.sensorWidthMm &&
          other.sensorHeightMm == this.sensorHeightMm &&
          other.resolutionX == this.resolutionX &&
          other.resolutionY == this.resolutionY &&
          other.focalLengthMm == this.focalLengthMm &&
          other.apertureMm == this.apertureMm &&
          other.payloadCapacityKg == this.payloadCapacityKg);
}

class EquipmentItemsCompanion extends UpdateCompanion<EquipmentItemRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> kind;
  final Value<double?> sensorWidthMm;
  final Value<double?> sensorHeightMm;
  final Value<int?> resolutionX;
  final Value<int?> resolutionY;
  final Value<double?> focalLengthMm;
  final Value<double?> apertureMm;
  final Value<double?> payloadCapacityKg;
  final Value<int> rowid;
  const EquipmentItemsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.kind = const Value.absent(),
    this.sensorWidthMm = const Value.absent(),
    this.sensorHeightMm = const Value.absent(),
    this.resolutionX = const Value.absent(),
    this.resolutionY = const Value.absent(),
    this.focalLengthMm = const Value.absent(),
    this.apertureMm = const Value.absent(),
    this.payloadCapacityKg = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EquipmentItemsCompanion.insert({
    required String id,
    required String name,
    required String kind,
    this.sensorWidthMm = const Value.absent(),
    this.sensorHeightMm = const Value.absent(),
    this.resolutionX = const Value.absent(),
    this.resolutionY = const Value.absent(),
    this.focalLengthMm = const Value.absent(),
    this.apertureMm = const Value.absent(),
    this.payloadCapacityKg = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       kind = Value(kind);
  static Insertable<EquipmentItemRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? kind,
    Expression<double>? sensorWidthMm,
    Expression<double>? sensorHeightMm,
    Expression<int>? resolutionX,
    Expression<int>? resolutionY,
    Expression<double>? focalLengthMm,
    Expression<double>? apertureMm,
    Expression<double>? payloadCapacityKg,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (kind != null) 'kind': kind,
      if (sensorWidthMm != null) 'sensor_width_mm': sensorWidthMm,
      if (sensorHeightMm != null) 'sensor_height_mm': sensorHeightMm,
      if (resolutionX != null) 'resolution_x': resolutionX,
      if (resolutionY != null) 'resolution_y': resolutionY,
      if (focalLengthMm != null) 'focal_length_mm': focalLengthMm,
      if (apertureMm != null) 'aperture_mm': apertureMm,
      if (payloadCapacityKg != null) 'payload_capacity_kg': payloadCapacityKg,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EquipmentItemsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? kind,
    Value<double?>? sensorWidthMm,
    Value<double?>? sensorHeightMm,
    Value<int?>? resolutionX,
    Value<int?>? resolutionY,
    Value<double?>? focalLengthMm,
    Value<double?>? apertureMm,
    Value<double?>? payloadCapacityKg,
    Value<int>? rowid,
  }) {
    return EquipmentItemsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      kind: kind ?? this.kind,
      sensorWidthMm: sensorWidthMm ?? this.sensorWidthMm,
      sensorHeightMm: sensorHeightMm ?? this.sensorHeightMm,
      resolutionX: resolutionX ?? this.resolutionX,
      resolutionY: resolutionY ?? this.resolutionY,
      focalLengthMm: focalLengthMm ?? this.focalLengthMm,
      apertureMm: apertureMm ?? this.apertureMm,
      payloadCapacityKg: payloadCapacityKg ?? this.payloadCapacityKg,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (sensorWidthMm.present) {
      map['sensor_width_mm'] = Variable<double>(sensorWidthMm.value);
    }
    if (sensorHeightMm.present) {
      map['sensor_height_mm'] = Variable<double>(sensorHeightMm.value);
    }
    if (resolutionX.present) {
      map['resolution_x'] = Variable<int>(resolutionX.value);
    }
    if (resolutionY.present) {
      map['resolution_y'] = Variable<int>(resolutionY.value);
    }
    if (focalLengthMm.present) {
      map['focal_length_mm'] = Variable<double>(focalLengthMm.value);
    }
    if (apertureMm.present) {
      map['aperture_mm'] = Variable<double>(apertureMm.value);
    }
    if (payloadCapacityKg.present) {
      map['payload_capacity_kg'] = Variable<double>(payloadCapacityKg.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EquipmentItemsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('kind: $kind, ')
          ..write('sensorWidthMm: $sensorWidthMm, ')
          ..write('sensorHeightMm: $sensorHeightMm, ')
          ..write('resolutionX: $resolutionX, ')
          ..write('resolutionY: $resolutionY, ')
          ..write('focalLengthMm: $focalLengthMm, ')
          ..write('apertureMm: $apertureMm, ')
          ..write('payloadCapacityKg: $payloadCapacityKg, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OpticalProfilesTable extends OpticalProfiles
    with TableInfo<$OpticalProfilesTable, OpticalProfileRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OpticalProfilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 120,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cameraIdMeta = const VerificationMeta(
    'cameraId',
  );
  @override
  late final GeneratedColumn<String> cameraId = GeneratedColumn<String>(
    'camera_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES equipment_items (id) ON DELETE RESTRICT',
    ),
  );
  static const VerificationMeta _opticIdMeta = const VerificationMeta(
    'opticId',
  );
  @override
  late final GeneratedColumn<String> opticId = GeneratedColumn<String>(
    'optic_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES equipment_items (id) ON DELETE RESTRICT',
    ),
  );
  static const VerificationMeta _mountIdMeta = const VerificationMeta(
    'mountId',
  );
  @override
  late final GeneratedColumn<String> mountId = GeneratedColumn<String>(
    'mount_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES equipment_items (id) ON DELETE RESTRICT',
    ),
  );
  static const VerificationMeta _focalMultiplierMeta = const VerificationMeta(
    'focalMultiplier',
  );
  @override
  late final GeneratedColumn<double> focalMultiplier = GeneratedColumn<double>(
    'focal_multiplier',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(1.0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    cameraId,
    opticId,
    mountId,
    focalMultiplier,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'optical_profiles';
  @override
  VerificationContext validateIntegrity(
    Insertable<OpticalProfileRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('camera_id')) {
      context.handle(
        _cameraIdMeta,
        cameraId.isAcceptableOrUnknown(data['camera_id']!, _cameraIdMeta),
      );
    } else if (isInserting) {
      context.missing(_cameraIdMeta);
    }
    if (data.containsKey('optic_id')) {
      context.handle(
        _opticIdMeta,
        opticId.isAcceptableOrUnknown(data['optic_id']!, _opticIdMeta),
      );
    } else if (isInserting) {
      context.missing(_opticIdMeta);
    }
    if (data.containsKey('mount_id')) {
      context.handle(
        _mountIdMeta,
        mountId.isAcceptableOrUnknown(data['mount_id']!, _mountIdMeta),
      );
    }
    if (data.containsKey('focal_multiplier')) {
      context.handle(
        _focalMultiplierMeta,
        focalMultiplier.isAcceptableOrUnknown(
          data['focal_multiplier']!,
          _focalMultiplierMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  OpticalProfileRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OpticalProfileRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      cameraId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}camera_id'],
      )!,
      opticId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}optic_id'],
      )!,
      mountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mount_id'],
      ),
      focalMultiplier: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}focal_multiplier'],
      )!,
    );
  }

  @override
  $OpticalProfilesTable createAlias(String alias) {
    return $OpticalProfilesTable(attachedDatabase, alias);
  }
}

class OpticalProfileRow extends DataClass
    implements Insertable<OpticalProfileRow> {
  final String id;
  final String name;
  final String cameraId;
  final String opticId;
  final String? mountId;
  final double focalMultiplier;
  const OpticalProfileRow({
    required this.id,
    required this.name,
    required this.cameraId,
    required this.opticId,
    this.mountId,
    required this.focalMultiplier,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['camera_id'] = Variable<String>(cameraId);
    map['optic_id'] = Variable<String>(opticId);
    if (!nullToAbsent || mountId != null) {
      map['mount_id'] = Variable<String>(mountId);
    }
    map['focal_multiplier'] = Variable<double>(focalMultiplier);
    return map;
  }

  OpticalProfilesCompanion toCompanion(bool nullToAbsent) {
    return OpticalProfilesCompanion(
      id: Value(id),
      name: Value(name),
      cameraId: Value(cameraId),
      opticId: Value(opticId),
      mountId: mountId == null && nullToAbsent
          ? const Value.absent()
          : Value(mountId),
      focalMultiplier: Value(focalMultiplier),
    );
  }

  factory OpticalProfileRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OpticalProfileRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      cameraId: serializer.fromJson<String>(json['cameraId']),
      opticId: serializer.fromJson<String>(json['opticId']),
      mountId: serializer.fromJson<String?>(json['mountId']),
      focalMultiplier: serializer.fromJson<double>(json['focalMultiplier']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'cameraId': serializer.toJson<String>(cameraId),
      'opticId': serializer.toJson<String>(opticId),
      'mountId': serializer.toJson<String?>(mountId),
      'focalMultiplier': serializer.toJson<double>(focalMultiplier),
    };
  }

  OpticalProfileRow copyWith({
    String? id,
    String? name,
    String? cameraId,
    String? opticId,
    Value<String?> mountId = const Value.absent(),
    double? focalMultiplier,
  }) => OpticalProfileRow(
    id: id ?? this.id,
    name: name ?? this.name,
    cameraId: cameraId ?? this.cameraId,
    opticId: opticId ?? this.opticId,
    mountId: mountId.present ? mountId.value : this.mountId,
    focalMultiplier: focalMultiplier ?? this.focalMultiplier,
  );
  OpticalProfileRow copyWithCompanion(OpticalProfilesCompanion data) {
    return OpticalProfileRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      cameraId: data.cameraId.present ? data.cameraId.value : this.cameraId,
      opticId: data.opticId.present ? data.opticId.value : this.opticId,
      mountId: data.mountId.present ? data.mountId.value : this.mountId,
      focalMultiplier: data.focalMultiplier.present
          ? data.focalMultiplier.value
          : this.focalMultiplier,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OpticalProfileRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('cameraId: $cameraId, ')
          ..write('opticId: $opticId, ')
          ..write('mountId: $mountId, ')
          ..write('focalMultiplier: $focalMultiplier')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, cameraId, opticId, mountId, focalMultiplier);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OpticalProfileRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.cameraId == this.cameraId &&
          other.opticId == this.opticId &&
          other.mountId == this.mountId &&
          other.focalMultiplier == this.focalMultiplier);
}

class OpticalProfilesCompanion extends UpdateCompanion<OpticalProfileRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> cameraId;
  final Value<String> opticId;
  final Value<String?> mountId;
  final Value<double> focalMultiplier;
  final Value<int> rowid;
  const OpticalProfilesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.cameraId = const Value.absent(),
    this.opticId = const Value.absent(),
    this.mountId = const Value.absent(),
    this.focalMultiplier = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OpticalProfilesCompanion.insert({
    required String id,
    required String name,
    required String cameraId,
    required String opticId,
    this.mountId = const Value.absent(),
    this.focalMultiplier = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       cameraId = Value(cameraId),
       opticId = Value(opticId);
  static Insertable<OpticalProfileRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? cameraId,
    Expression<String>? opticId,
    Expression<String>? mountId,
    Expression<double>? focalMultiplier,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (cameraId != null) 'camera_id': cameraId,
      if (opticId != null) 'optic_id': opticId,
      if (mountId != null) 'mount_id': mountId,
      if (focalMultiplier != null) 'focal_multiplier': focalMultiplier,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OpticalProfilesCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? cameraId,
    Value<String>? opticId,
    Value<String?>? mountId,
    Value<double>? focalMultiplier,
    Value<int>? rowid,
  }) {
    return OpticalProfilesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      cameraId: cameraId ?? this.cameraId,
      opticId: opticId ?? this.opticId,
      mountId: mountId ?? this.mountId,
      focalMultiplier: focalMultiplier ?? this.focalMultiplier,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (cameraId.present) {
      map['camera_id'] = Variable<String>(cameraId.value);
    }
    if (opticId.present) {
      map['optic_id'] = Variable<String>(opticId.value);
    }
    if (mountId.present) {
      map['mount_id'] = Variable<String>(mountId.value);
    }
    if (focalMultiplier.present) {
      map['focal_multiplier'] = Variable<double>(focalMultiplier.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OpticalProfilesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('cameraId: $cameraId, ')
          ..write('opticId: $opticId, ')
          ..write('mountId: $mountId, ')
          ..write('focalMultiplier: $focalMultiplier, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CelestialCatalogEntriesTable extends CelestialCatalogEntries
    with TableInfo<$CelestialCatalogEntriesTable, CelestialCatalogEntryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CelestialCatalogEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _designationMeta = const VerificationMeta(
    'designation',
  );
  @override
  late final GeneratedColumn<String> designation = GeneratedColumn<String>(
    'designation',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceTypeMeta = const VerificationMeta(
    'sourceType',
  );
  @override
  late final GeneratedColumn<String> sourceType = GeneratedColumn<String>(
    'source_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _raDegreesMeta = const VerificationMeta(
    'raDegrees',
  );
  @override
  late final GeneratedColumn<double> raDegrees = GeneratedColumn<double>(
    'ra_degrees',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _decDegreesMeta = const VerificationMeta(
    'decDegrees',
  );
  @override
  late final GeneratedColumn<double> decDegrees = GeneratedColumn<double>(
    'dec_degrees',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _constellationMeta = const VerificationMeta(
    'constellation',
  );
  @override
  late final GeneratedColumn<String> constellation = GeneratedColumn<String>(
    'constellation',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _visualMagnitudeMeta = const VerificationMeta(
    'visualMagnitude',
  );
  @override
  late final GeneratedColumn<double> visualMagnitude = GeneratedColumn<double>(
    'visual_magnitude',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _majorAxisArcminMeta = const VerificationMeta(
    'majorAxisArcmin',
  );
  @override
  late final GeneratedColumn<double> majorAxisArcmin = GeneratedColumn<double>(
    'major_axis_arcmin',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _minorAxisArcminMeta = const VerificationMeta(
    'minorAxisArcmin',
  );
  @override
  late final GeneratedColumn<double> minorAxisArcmin = GeneratedColumn<double>(
    'minor_axis_arcmin',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _messierNumberMeta = const VerificationMeta(
    'messierNumber',
  );
  @override
  late final GeneratedColumn<int> messierNumber = GeneratedColumn<int>(
    'messier_number',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _commonNamesMeta = const VerificationMeta(
    'commonNames',
  );
  @override
  late final GeneratedColumn<String> commonNames = GeneratedColumn<String>(
    'common_names',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _aliasesMeta = const VerificationMeta(
    'aliases',
  );
  @override
  late final GeneratedColumn<String> aliases = GeneratedColumn<String>(
    'aliases',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    designation,
    category,
    sourceType,
    raDegrees,
    decDegrees,
    constellation,
    visualMagnitude,
    majorAxisArcmin,
    minorAxisArcmin,
    messierNumber,
    commonNames,
    aliases,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'celestial_catalog_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<CelestialCatalogEntryRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('designation')) {
      context.handle(
        _designationMeta,
        designation.isAcceptableOrUnknown(
          data['designation']!,
          _designationMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_designationMeta);
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryMeta);
    }
    if (data.containsKey('source_type')) {
      context.handle(
        _sourceTypeMeta,
        sourceType.isAcceptableOrUnknown(data['source_type']!, _sourceTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceTypeMeta);
    }
    if (data.containsKey('ra_degrees')) {
      context.handle(
        _raDegreesMeta,
        raDegrees.isAcceptableOrUnknown(data['ra_degrees']!, _raDegreesMeta),
      );
    } else if (isInserting) {
      context.missing(_raDegreesMeta);
    }
    if (data.containsKey('dec_degrees')) {
      context.handle(
        _decDegreesMeta,
        decDegrees.isAcceptableOrUnknown(data['dec_degrees']!, _decDegreesMeta),
      );
    } else if (isInserting) {
      context.missing(_decDegreesMeta);
    }
    if (data.containsKey('constellation')) {
      context.handle(
        _constellationMeta,
        constellation.isAcceptableOrUnknown(
          data['constellation']!,
          _constellationMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_constellationMeta);
    }
    if (data.containsKey('visual_magnitude')) {
      context.handle(
        _visualMagnitudeMeta,
        visualMagnitude.isAcceptableOrUnknown(
          data['visual_magnitude']!,
          _visualMagnitudeMeta,
        ),
      );
    }
    if (data.containsKey('major_axis_arcmin')) {
      context.handle(
        _majorAxisArcminMeta,
        majorAxisArcmin.isAcceptableOrUnknown(
          data['major_axis_arcmin']!,
          _majorAxisArcminMeta,
        ),
      );
    }
    if (data.containsKey('minor_axis_arcmin')) {
      context.handle(
        _minorAxisArcminMeta,
        minorAxisArcmin.isAcceptableOrUnknown(
          data['minor_axis_arcmin']!,
          _minorAxisArcminMeta,
        ),
      );
    }
    if (data.containsKey('messier_number')) {
      context.handle(
        _messierNumberMeta,
        messierNumber.isAcceptableOrUnknown(
          data['messier_number']!,
          _messierNumberMeta,
        ),
      );
    }
    if (data.containsKey('common_names')) {
      context.handle(
        _commonNamesMeta,
        commonNames.isAcceptableOrUnknown(
          data['common_names']!,
          _commonNamesMeta,
        ),
      );
    }
    if (data.containsKey('aliases')) {
      context.handle(
        _aliasesMeta,
        aliases.isAcceptableOrUnknown(data['aliases']!, _aliasesMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CelestialCatalogEntryRow map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CelestialCatalogEntryRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      designation: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}designation'],
      )!,
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      )!,
      sourceType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_type'],
      )!,
      raDegrees: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}ra_degrees'],
      )!,
      decDegrees: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}dec_degrees'],
      )!,
      constellation: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}constellation'],
      )!,
      visualMagnitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}visual_magnitude'],
      ),
      majorAxisArcmin: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}major_axis_arcmin'],
      ),
      minorAxisArcmin: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}minor_axis_arcmin'],
      ),
      messierNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}messier_number'],
      ),
      commonNames: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}common_names'],
      )!,
      aliases: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}aliases'],
      )!,
    );
  }

  @override
  $CelestialCatalogEntriesTable createAlias(String alias) {
    return $CelestialCatalogEntriesTable(attachedDatabase, alias);
  }
}

class CelestialCatalogEntryRow extends DataClass
    implements Insertable<CelestialCatalogEntryRow> {
  final String id;
  final String designation;
  final String category;
  final String sourceType;
  final double raDegrees;
  final double decDegrees;
  final String constellation;
  final double? visualMagnitude;
  final double? majorAxisArcmin;
  final double? minorAxisArcmin;
  final int? messierNumber;
  final String commonNames;
  final String aliases;
  const CelestialCatalogEntryRow({
    required this.id,
    required this.designation,
    required this.category,
    required this.sourceType,
    required this.raDegrees,
    required this.decDegrees,
    required this.constellation,
    this.visualMagnitude,
    this.majorAxisArcmin,
    this.minorAxisArcmin,
    this.messierNumber,
    required this.commonNames,
    required this.aliases,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['designation'] = Variable<String>(designation);
    map['category'] = Variable<String>(category);
    map['source_type'] = Variable<String>(sourceType);
    map['ra_degrees'] = Variable<double>(raDegrees);
    map['dec_degrees'] = Variable<double>(decDegrees);
    map['constellation'] = Variable<String>(constellation);
    if (!nullToAbsent || visualMagnitude != null) {
      map['visual_magnitude'] = Variable<double>(visualMagnitude);
    }
    if (!nullToAbsent || majorAxisArcmin != null) {
      map['major_axis_arcmin'] = Variable<double>(majorAxisArcmin);
    }
    if (!nullToAbsent || minorAxisArcmin != null) {
      map['minor_axis_arcmin'] = Variable<double>(minorAxisArcmin);
    }
    if (!nullToAbsent || messierNumber != null) {
      map['messier_number'] = Variable<int>(messierNumber);
    }
    map['common_names'] = Variable<String>(commonNames);
    map['aliases'] = Variable<String>(aliases);
    return map;
  }

  CelestialCatalogEntriesCompanion toCompanion(bool nullToAbsent) {
    return CelestialCatalogEntriesCompanion(
      id: Value(id),
      designation: Value(designation),
      category: Value(category),
      sourceType: Value(sourceType),
      raDegrees: Value(raDegrees),
      decDegrees: Value(decDegrees),
      constellation: Value(constellation),
      visualMagnitude: visualMagnitude == null && nullToAbsent
          ? const Value.absent()
          : Value(visualMagnitude),
      majorAxisArcmin: majorAxisArcmin == null && nullToAbsent
          ? const Value.absent()
          : Value(majorAxisArcmin),
      minorAxisArcmin: minorAxisArcmin == null && nullToAbsent
          ? const Value.absent()
          : Value(minorAxisArcmin),
      messierNumber: messierNumber == null && nullToAbsent
          ? const Value.absent()
          : Value(messierNumber),
      commonNames: Value(commonNames),
      aliases: Value(aliases),
    );
  }

  factory CelestialCatalogEntryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CelestialCatalogEntryRow(
      id: serializer.fromJson<String>(json['id']),
      designation: serializer.fromJson<String>(json['designation']),
      category: serializer.fromJson<String>(json['category']),
      sourceType: serializer.fromJson<String>(json['sourceType']),
      raDegrees: serializer.fromJson<double>(json['raDegrees']),
      decDegrees: serializer.fromJson<double>(json['decDegrees']),
      constellation: serializer.fromJson<String>(json['constellation']),
      visualMagnitude: serializer.fromJson<double?>(json['visualMagnitude']),
      majorAxisArcmin: serializer.fromJson<double?>(json['majorAxisArcmin']),
      minorAxisArcmin: serializer.fromJson<double?>(json['minorAxisArcmin']),
      messierNumber: serializer.fromJson<int?>(json['messierNumber']),
      commonNames: serializer.fromJson<String>(json['commonNames']),
      aliases: serializer.fromJson<String>(json['aliases']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'designation': serializer.toJson<String>(designation),
      'category': serializer.toJson<String>(category),
      'sourceType': serializer.toJson<String>(sourceType),
      'raDegrees': serializer.toJson<double>(raDegrees),
      'decDegrees': serializer.toJson<double>(decDegrees),
      'constellation': serializer.toJson<String>(constellation),
      'visualMagnitude': serializer.toJson<double?>(visualMagnitude),
      'majorAxisArcmin': serializer.toJson<double?>(majorAxisArcmin),
      'minorAxisArcmin': serializer.toJson<double?>(minorAxisArcmin),
      'messierNumber': serializer.toJson<int?>(messierNumber),
      'commonNames': serializer.toJson<String>(commonNames),
      'aliases': serializer.toJson<String>(aliases),
    };
  }

  CelestialCatalogEntryRow copyWith({
    String? id,
    String? designation,
    String? category,
    String? sourceType,
    double? raDegrees,
    double? decDegrees,
    String? constellation,
    Value<double?> visualMagnitude = const Value.absent(),
    Value<double?> majorAxisArcmin = const Value.absent(),
    Value<double?> minorAxisArcmin = const Value.absent(),
    Value<int?> messierNumber = const Value.absent(),
    String? commonNames,
    String? aliases,
  }) => CelestialCatalogEntryRow(
    id: id ?? this.id,
    designation: designation ?? this.designation,
    category: category ?? this.category,
    sourceType: sourceType ?? this.sourceType,
    raDegrees: raDegrees ?? this.raDegrees,
    decDegrees: decDegrees ?? this.decDegrees,
    constellation: constellation ?? this.constellation,
    visualMagnitude: visualMagnitude.present
        ? visualMagnitude.value
        : this.visualMagnitude,
    majorAxisArcmin: majorAxisArcmin.present
        ? majorAxisArcmin.value
        : this.majorAxisArcmin,
    minorAxisArcmin: minorAxisArcmin.present
        ? minorAxisArcmin.value
        : this.minorAxisArcmin,
    messierNumber: messierNumber.present
        ? messierNumber.value
        : this.messierNumber,
    commonNames: commonNames ?? this.commonNames,
    aliases: aliases ?? this.aliases,
  );
  CelestialCatalogEntryRow copyWithCompanion(
    CelestialCatalogEntriesCompanion data,
  ) {
    return CelestialCatalogEntryRow(
      id: data.id.present ? data.id.value : this.id,
      designation: data.designation.present
          ? data.designation.value
          : this.designation,
      category: data.category.present ? data.category.value : this.category,
      sourceType: data.sourceType.present
          ? data.sourceType.value
          : this.sourceType,
      raDegrees: data.raDegrees.present ? data.raDegrees.value : this.raDegrees,
      decDegrees: data.decDegrees.present
          ? data.decDegrees.value
          : this.decDegrees,
      constellation: data.constellation.present
          ? data.constellation.value
          : this.constellation,
      visualMagnitude: data.visualMagnitude.present
          ? data.visualMagnitude.value
          : this.visualMagnitude,
      majorAxisArcmin: data.majorAxisArcmin.present
          ? data.majorAxisArcmin.value
          : this.majorAxisArcmin,
      minorAxisArcmin: data.minorAxisArcmin.present
          ? data.minorAxisArcmin.value
          : this.minorAxisArcmin,
      messierNumber: data.messierNumber.present
          ? data.messierNumber.value
          : this.messierNumber,
      commonNames: data.commonNames.present
          ? data.commonNames.value
          : this.commonNames,
      aliases: data.aliases.present ? data.aliases.value : this.aliases,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CelestialCatalogEntryRow(')
          ..write('id: $id, ')
          ..write('designation: $designation, ')
          ..write('category: $category, ')
          ..write('sourceType: $sourceType, ')
          ..write('raDegrees: $raDegrees, ')
          ..write('decDegrees: $decDegrees, ')
          ..write('constellation: $constellation, ')
          ..write('visualMagnitude: $visualMagnitude, ')
          ..write('majorAxisArcmin: $majorAxisArcmin, ')
          ..write('minorAxisArcmin: $minorAxisArcmin, ')
          ..write('messierNumber: $messierNumber, ')
          ..write('commonNames: $commonNames, ')
          ..write('aliases: $aliases')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    designation,
    category,
    sourceType,
    raDegrees,
    decDegrees,
    constellation,
    visualMagnitude,
    majorAxisArcmin,
    minorAxisArcmin,
    messierNumber,
    commonNames,
    aliases,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CelestialCatalogEntryRow &&
          other.id == this.id &&
          other.designation == this.designation &&
          other.category == this.category &&
          other.sourceType == this.sourceType &&
          other.raDegrees == this.raDegrees &&
          other.decDegrees == this.decDegrees &&
          other.constellation == this.constellation &&
          other.visualMagnitude == this.visualMagnitude &&
          other.majorAxisArcmin == this.majorAxisArcmin &&
          other.minorAxisArcmin == this.minorAxisArcmin &&
          other.messierNumber == this.messierNumber &&
          other.commonNames == this.commonNames &&
          other.aliases == this.aliases);
}

class CelestialCatalogEntriesCompanion
    extends UpdateCompanion<CelestialCatalogEntryRow> {
  final Value<String> id;
  final Value<String> designation;
  final Value<String> category;
  final Value<String> sourceType;
  final Value<double> raDegrees;
  final Value<double> decDegrees;
  final Value<String> constellation;
  final Value<double?> visualMagnitude;
  final Value<double?> majorAxisArcmin;
  final Value<double?> minorAxisArcmin;
  final Value<int?> messierNumber;
  final Value<String> commonNames;
  final Value<String> aliases;
  final Value<int> rowid;
  const CelestialCatalogEntriesCompanion({
    this.id = const Value.absent(),
    this.designation = const Value.absent(),
    this.category = const Value.absent(),
    this.sourceType = const Value.absent(),
    this.raDegrees = const Value.absent(),
    this.decDegrees = const Value.absent(),
    this.constellation = const Value.absent(),
    this.visualMagnitude = const Value.absent(),
    this.majorAxisArcmin = const Value.absent(),
    this.minorAxisArcmin = const Value.absent(),
    this.messierNumber = const Value.absent(),
    this.commonNames = const Value.absent(),
    this.aliases = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CelestialCatalogEntriesCompanion.insert({
    required String id,
    required String designation,
    required String category,
    required String sourceType,
    required double raDegrees,
    required double decDegrees,
    required String constellation,
    this.visualMagnitude = const Value.absent(),
    this.majorAxisArcmin = const Value.absent(),
    this.minorAxisArcmin = const Value.absent(),
    this.messierNumber = const Value.absent(),
    this.commonNames = const Value.absent(),
    this.aliases = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       designation = Value(designation),
       category = Value(category),
       sourceType = Value(sourceType),
       raDegrees = Value(raDegrees),
       decDegrees = Value(decDegrees),
       constellation = Value(constellation);
  static Insertable<CelestialCatalogEntryRow> custom({
    Expression<String>? id,
    Expression<String>? designation,
    Expression<String>? category,
    Expression<String>? sourceType,
    Expression<double>? raDegrees,
    Expression<double>? decDegrees,
    Expression<String>? constellation,
    Expression<double>? visualMagnitude,
    Expression<double>? majorAxisArcmin,
    Expression<double>? minorAxisArcmin,
    Expression<int>? messierNumber,
    Expression<String>? commonNames,
    Expression<String>? aliases,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (designation != null) 'designation': designation,
      if (category != null) 'category': category,
      if (sourceType != null) 'source_type': sourceType,
      if (raDegrees != null) 'ra_degrees': raDegrees,
      if (decDegrees != null) 'dec_degrees': decDegrees,
      if (constellation != null) 'constellation': constellation,
      if (visualMagnitude != null) 'visual_magnitude': visualMagnitude,
      if (majorAxisArcmin != null) 'major_axis_arcmin': majorAxisArcmin,
      if (minorAxisArcmin != null) 'minor_axis_arcmin': minorAxisArcmin,
      if (messierNumber != null) 'messier_number': messierNumber,
      if (commonNames != null) 'common_names': commonNames,
      if (aliases != null) 'aliases': aliases,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CelestialCatalogEntriesCompanion copyWith({
    Value<String>? id,
    Value<String>? designation,
    Value<String>? category,
    Value<String>? sourceType,
    Value<double>? raDegrees,
    Value<double>? decDegrees,
    Value<String>? constellation,
    Value<double?>? visualMagnitude,
    Value<double?>? majorAxisArcmin,
    Value<double?>? minorAxisArcmin,
    Value<int?>? messierNumber,
    Value<String>? commonNames,
    Value<String>? aliases,
    Value<int>? rowid,
  }) {
    return CelestialCatalogEntriesCompanion(
      id: id ?? this.id,
      designation: designation ?? this.designation,
      category: category ?? this.category,
      sourceType: sourceType ?? this.sourceType,
      raDegrees: raDegrees ?? this.raDegrees,
      decDegrees: decDegrees ?? this.decDegrees,
      constellation: constellation ?? this.constellation,
      visualMagnitude: visualMagnitude ?? this.visualMagnitude,
      majorAxisArcmin: majorAxisArcmin ?? this.majorAxisArcmin,
      minorAxisArcmin: minorAxisArcmin ?? this.minorAxisArcmin,
      messierNumber: messierNumber ?? this.messierNumber,
      commonNames: commonNames ?? this.commonNames,
      aliases: aliases ?? this.aliases,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (designation.present) {
      map['designation'] = Variable<String>(designation.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (sourceType.present) {
      map['source_type'] = Variable<String>(sourceType.value);
    }
    if (raDegrees.present) {
      map['ra_degrees'] = Variable<double>(raDegrees.value);
    }
    if (decDegrees.present) {
      map['dec_degrees'] = Variable<double>(decDegrees.value);
    }
    if (constellation.present) {
      map['constellation'] = Variable<String>(constellation.value);
    }
    if (visualMagnitude.present) {
      map['visual_magnitude'] = Variable<double>(visualMagnitude.value);
    }
    if (majorAxisArcmin.present) {
      map['major_axis_arcmin'] = Variable<double>(majorAxisArcmin.value);
    }
    if (minorAxisArcmin.present) {
      map['minor_axis_arcmin'] = Variable<double>(minorAxisArcmin.value);
    }
    if (messierNumber.present) {
      map['messier_number'] = Variable<int>(messierNumber.value);
    }
    if (commonNames.present) {
      map['common_names'] = Variable<String>(commonNames.value);
    }
    if (aliases.present) {
      map['aliases'] = Variable<String>(aliases.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CelestialCatalogEntriesCompanion(')
          ..write('id: $id, ')
          ..write('designation: $designation, ')
          ..write('category: $category, ')
          ..write('sourceType: $sourceType, ')
          ..write('raDegrees: $raDegrees, ')
          ..write('decDegrees: $decDegrees, ')
          ..write('constellation: $constellation, ')
          ..write('visualMagnitude: $visualMagnitude, ')
          ..write('majorAxisArcmin: $majorAxisArcmin, ')
          ..write('minorAxisArcmin: $minorAxisArcmin, ')
          ..write('messierNumber: $messierNumber, ')
          ..write('commonNames: $commonNames, ')
          ..write('aliases: $aliases, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $AppSettingsTable appSettings = $AppSettingsTable(this);
  late final $ObservingLocationsTable observingLocations =
      $ObservingLocationsTable(this);
  late final $EquipmentItemsTable equipmentItems = $EquipmentItemsTable(this);
  late final $OpticalProfilesTable opticalProfiles = $OpticalProfilesTable(
    this,
  );
  late final $CelestialCatalogEntriesTable celestialCatalogEntries =
      $CelestialCatalogEntriesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    appSettings,
    observingLocations,
    equipmentItems,
    opticalProfiles,
    celestialCatalogEntries,
  ];
}

typedef $$AppSettingsTableCreateCompanionBuilder =
    AppSettingsCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$AppSettingsTableUpdateCompanionBuilder =
    AppSettingsCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$AppSettingsTableFilterComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AppSettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AppSettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$AppSettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AppSettingsTable,
          AppSetting,
          $$AppSettingsTableFilterComposer,
          $$AppSettingsTableOrderingComposer,
          $$AppSettingsTableAnnotationComposer,
          $$AppSettingsTableCreateCompanionBuilder,
          $$AppSettingsTableUpdateCompanionBuilder,
          (
            AppSetting,
            BaseReferences<_$AppDatabase, $AppSettingsTable, AppSetting>,
          ),
          AppSetting,
          PrefetchHooks Function()
        > {
  $$AppSettingsTableTableManager(_$AppDatabase db, $AppSettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppSettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => AppSettingsCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => AppSettingsCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AppSettingsTable, AppSetting>(table),
                  BaseReferences<_$AppDatabase, $AppSettingsTable, AppSetting>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AppSettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AppSettingsTable,
      AppSetting,
      $$AppSettingsTableFilterComposer,
      $$AppSettingsTableOrderingComposer,
      $$AppSettingsTableAnnotationComposer,
      $$AppSettingsTableCreateCompanionBuilder,
      $$AppSettingsTableUpdateCompanionBuilder,
      (
        AppSetting,
        BaseReferences<_$AppDatabase, $AppSettingsTable, AppSetting>,
      ),
      AppSetting,
      PrefetchHooks Function()
    >;
typedef $$ObservingLocationsTableCreateCompanionBuilder =
    ObservingLocationsCompanion Function({
      required String id,
      required String name,
      required double latitude,
      required double longitude,
      required double elevationMeters,
      required String timeZone,
      Value<bool> isDefault,
      Value<int> rowid,
    });
typedef $$ObservingLocationsTableUpdateCompanionBuilder =
    ObservingLocationsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<double> latitude,
      Value<double> longitude,
      Value<double> elevationMeters,
      Value<String> timeZone,
      Value<bool> isDefault,
      Value<int> rowid,
    });

class $$ObservingLocationsTableFilterComposer
    extends Composer<_$AppDatabase, $ObservingLocationsTable> {
  $$ObservingLocationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get latitude => $composableBuilder(
    column: $table.latitude,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get longitude => $composableBuilder(
    column: $table.longitude,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get elevationMeters => $composableBuilder(
    column: $table.elevationMeters,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get timeZone => $composableBuilder(
    column: $table.timeZone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDefault => $composableBuilder(
    column: $table.isDefault,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ObservingLocationsTableOrderingComposer
    extends Composer<_$AppDatabase, $ObservingLocationsTable> {
  $$ObservingLocationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get latitude => $composableBuilder(
    column: $table.latitude,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get longitude => $composableBuilder(
    column: $table.longitude,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get elevationMeters => $composableBuilder(
    column: $table.elevationMeters,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get timeZone => $composableBuilder(
    column: $table.timeZone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDefault => $composableBuilder(
    column: $table.isDefault,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ObservingLocationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ObservingLocationsTable> {
  $$ObservingLocationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<double> get latitude =>
      $composableBuilder(column: $table.latitude, builder: (column) => column);

  GeneratedColumn<double> get longitude =>
      $composableBuilder(column: $table.longitude, builder: (column) => column);

  GeneratedColumn<double> get elevationMeters => $composableBuilder(
    column: $table.elevationMeters,
    builder: (column) => column,
  );

  GeneratedColumn<String> get timeZone =>
      $composableBuilder(column: $table.timeZone, builder: (column) => column);

  GeneratedColumn<bool> get isDefault =>
      $composableBuilder(column: $table.isDefault, builder: (column) => column);
}

class $$ObservingLocationsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ObservingLocationsTable,
          ObservingLocationRow,
          $$ObservingLocationsTableFilterComposer,
          $$ObservingLocationsTableOrderingComposer,
          $$ObservingLocationsTableAnnotationComposer,
          $$ObservingLocationsTableCreateCompanionBuilder,
          $$ObservingLocationsTableUpdateCompanionBuilder,
          (
            ObservingLocationRow,
            BaseReferences<
              _$AppDatabase,
              $ObservingLocationsTable,
              ObservingLocationRow
            >,
          ),
          ObservingLocationRow,
          PrefetchHooks Function()
        > {
  $$ObservingLocationsTableTableManager(
    _$AppDatabase db,
    $ObservingLocationsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ObservingLocationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ObservingLocationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ObservingLocationsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<double> latitude = const Value.absent(),
                Value<double> longitude = const Value.absent(),
                Value<double> elevationMeters = const Value.absent(),
                Value<String> timeZone = const Value.absent(),
                Value<bool> isDefault = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ObservingLocationsCompanion(
                id: id,
                name: name,
                latitude: latitude,
                longitude: longitude,
                elevationMeters: elevationMeters,
                timeZone: timeZone,
                isDefault: isDefault,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required double latitude,
                required double longitude,
                required double elevationMeters,
                required String timeZone,
                Value<bool> isDefault = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ObservingLocationsCompanion.insert(
                id: id,
                name: name,
                latitude: latitude,
                longitude: longitude,
                elevationMeters: elevationMeters,
                timeZone: timeZone,
                isDefault: isDefault,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ObservingLocationsTable, ObservingLocationRow>(
                    table,
                  ),
                  BaseReferences<
                    _$AppDatabase,
                    $ObservingLocationsTable,
                    ObservingLocationRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ObservingLocationsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ObservingLocationsTable,
      ObservingLocationRow,
      $$ObservingLocationsTableFilterComposer,
      $$ObservingLocationsTableOrderingComposer,
      $$ObservingLocationsTableAnnotationComposer,
      $$ObservingLocationsTableCreateCompanionBuilder,
      $$ObservingLocationsTableUpdateCompanionBuilder,
      (
        ObservingLocationRow,
        BaseReferences<
          _$AppDatabase,
          $ObservingLocationsTable,
          ObservingLocationRow
        >,
      ),
      ObservingLocationRow,
      PrefetchHooks Function()
    >;
typedef $$EquipmentItemsTableCreateCompanionBuilder =
    EquipmentItemsCompanion Function({
      required String id,
      required String name,
      required String kind,
      Value<double?> sensorWidthMm,
      Value<double?> sensorHeightMm,
      Value<int?> resolutionX,
      Value<int?> resolutionY,
      Value<double?> focalLengthMm,
      Value<double?> apertureMm,
      Value<double?> payloadCapacityKg,
      Value<int> rowid,
    });
typedef $$EquipmentItemsTableUpdateCompanionBuilder =
    EquipmentItemsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> kind,
      Value<double?> sensorWidthMm,
      Value<double?> sensorHeightMm,
      Value<int?> resolutionX,
      Value<int?> resolutionY,
      Value<double?> focalLengthMm,
      Value<double?> apertureMm,
      Value<double?> payloadCapacityKg,
      Value<int> rowid,
    });

class $$EquipmentItemsTableFilterComposer
    extends Composer<_$AppDatabase, $EquipmentItemsTable> {
  $$EquipmentItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get sensorWidthMm => $composableBuilder(
    column: $table.sensorWidthMm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get sensorHeightMm => $composableBuilder(
    column: $table.sensorHeightMm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get resolutionX => $composableBuilder(
    column: $table.resolutionX,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get resolutionY => $composableBuilder(
    column: $table.resolutionY,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get focalLengthMm => $composableBuilder(
    column: $table.focalLengthMm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get apertureMm => $composableBuilder(
    column: $table.apertureMm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get payloadCapacityKg => $composableBuilder(
    column: $table.payloadCapacityKg,
    builder: (column) => ColumnFilters(column),
  );
}

class $$EquipmentItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $EquipmentItemsTable> {
  $$EquipmentItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get sensorWidthMm => $composableBuilder(
    column: $table.sensorWidthMm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get sensorHeightMm => $composableBuilder(
    column: $table.sensorHeightMm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get resolutionX => $composableBuilder(
    column: $table.resolutionX,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get resolutionY => $composableBuilder(
    column: $table.resolutionY,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get focalLengthMm => $composableBuilder(
    column: $table.focalLengthMm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get apertureMm => $composableBuilder(
    column: $table.apertureMm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get payloadCapacityKg => $composableBuilder(
    column: $table.payloadCapacityKg,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$EquipmentItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $EquipmentItemsTable> {
  $$EquipmentItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<double> get sensorWidthMm => $composableBuilder(
    column: $table.sensorWidthMm,
    builder: (column) => column,
  );

  GeneratedColumn<double> get sensorHeightMm => $composableBuilder(
    column: $table.sensorHeightMm,
    builder: (column) => column,
  );

  GeneratedColumn<int> get resolutionX => $composableBuilder(
    column: $table.resolutionX,
    builder: (column) => column,
  );

  GeneratedColumn<int> get resolutionY => $composableBuilder(
    column: $table.resolutionY,
    builder: (column) => column,
  );

  GeneratedColumn<double> get focalLengthMm => $composableBuilder(
    column: $table.focalLengthMm,
    builder: (column) => column,
  );

  GeneratedColumn<double> get apertureMm => $composableBuilder(
    column: $table.apertureMm,
    builder: (column) => column,
  );

  GeneratedColumn<double> get payloadCapacityKg => $composableBuilder(
    column: $table.payloadCapacityKg,
    builder: (column) => column,
  );
}

class $$EquipmentItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EquipmentItemsTable,
          EquipmentItemRow,
          $$EquipmentItemsTableFilterComposer,
          $$EquipmentItemsTableOrderingComposer,
          $$EquipmentItemsTableAnnotationComposer,
          $$EquipmentItemsTableCreateCompanionBuilder,
          $$EquipmentItemsTableUpdateCompanionBuilder,
          (
            EquipmentItemRow,
            BaseReferences<
              _$AppDatabase,
              $EquipmentItemsTable,
              EquipmentItemRow
            >,
          ),
          EquipmentItemRow,
          PrefetchHooks Function()
        > {
  $$EquipmentItemsTableTableManager(
    _$AppDatabase db,
    $EquipmentItemsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EquipmentItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EquipmentItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EquipmentItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<double?> sensorWidthMm = const Value.absent(),
                Value<double?> sensorHeightMm = const Value.absent(),
                Value<int?> resolutionX = const Value.absent(),
                Value<int?> resolutionY = const Value.absent(),
                Value<double?> focalLengthMm = const Value.absent(),
                Value<double?> apertureMm = const Value.absent(),
                Value<double?> payloadCapacityKg = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EquipmentItemsCompanion(
                id: id,
                name: name,
                kind: kind,
                sensorWidthMm: sensorWidthMm,
                sensorHeightMm: sensorHeightMm,
                resolutionX: resolutionX,
                resolutionY: resolutionY,
                focalLengthMm: focalLengthMm,
                apertureMm: apertureMm,
                payloadCapacityKg: payloadCapacityKg,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String kind,
                Value<double?> sensorWidthMm = const Value.absent(),
                Value<double?> sensorHeightMm = const Value.absent(),
                Value<int?> resolutionX = const Value.absent(),
                Value<int?> resolutionY = const Value.absent(),
                Value<double?> focalLengthMm = const Value.absent(),
                Value<double?> apertureMm = const Value.absent(),
                Value<double?> payloadCapacityKg = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EquipmentItemsCompanion.insert(
                id: id,
                name: name,
                kind: kind,
                sensorWidthMm: sensorWidthMm,
                sensorHeightMm: sensorHeightMm,
                resolutionX: resolutionX,
                resolutionY: resolutionY,
                focalLengthMm: focalLengthMm,
                apertureMm: apertureMm,
                payloadCapacityKg: payloadCapacityKg,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$EquipmentItemsTable, EquipmentItemRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $EquipmentItemsTable,
                    EquipmentItemRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$EquipmentItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EquipmentItemsTable,
      EquipmentItemRow,
      $$EquipmentItemsTableFilterComposer,
      $$EquipmentItemsTableOrderingComposer,
      $$EquipmentItemsTableAnnotationComposer,
      $$EquipmentItemsTableCreateCompanionBuilder,
      $$EquipmentItemsTableUpdateCompanionBuilder,
      (
        EquipmentItemRow,
        BaseReferences<_$AppDatabase, $EquipmentItemsTable, EquipmentItemRow>,
      ),
      EquipmentItemRow,
      PrefetchHooks Function()
    >;
typedef $$OpticalProfilesTableCreateCompanionBuilder =
    OpticalProfilesCompanion Function({
      required String id,
      required String name,
      required String cameraId,
      required String opticId,
      Value<String?> mountId,
      Value<double> focalMultiplier,
      Value<int> rowid,
    });
typedef $$OpticalProfilesTableUpdateCompanionBuilder =
    OpticalProfilesCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> cameraId,
      Value<String> opticId,
      Value<String?> mountId,
      Value<double> focalMultiplier,
      Value<int> rowid,
    });

final class $$OpticalProfilesTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $OpticalProfilesTable,
          OpticalProfileRow
        > {
  $$OpticalProfilesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $EquipmentItemsTable _cameraIdTable(_$AppDatabase db) => db
      .equipmentItems
      .createAlias('optical_profiles__camera_id__equipment_items__id');

  $$EquipmentItemsTableProcessedTableManager get cameraId {
    final $_column = $_itemColumn<String>('camera_id')!;

    final manager = $$EquipmentItemsTableTableManager(
      $_db,
      $_db.equipmentItems,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_cameraIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $EquipmentItemsTable _opticIdTable(_$AppDatabase db) => db
      .equipmentItems
      .createAlias('optical_profiles__optic_id__equipment_items__id');

  $$EquipmentItemsTableProcessedTableManager get opticId {
    final $_column = $_itemColumn<String>('optic_id')!;

    final manager = $$EquipmentItemsTableTableManager(
      $_db,
      $_db.equipmentItems,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_opticIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $EquipmentItemsTable _mountIdTable(_$AppDatabase db) => db
      .equipmentItems
      .createAlias('optical_profiles__mount_id__equipment_items__id');

  $$EquipmentItemsTableProcessedTableManager? get mountId {
    final $_column = $_itemColumn<String>('mount_id');
    if ($_column == null) return null;
    final manager = $$EquipmentItemsTableTableManager(
      $_db,
      $_db.equipmentItems,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_mountIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$OpticalProfilesTableFilterComposer
    extends Composer<_$AppDatabase, $OpticalProfilesTable> {
  $$OpticalProfilesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get focalMultiplier => $composableBuilder(
    column: $table.focalMultiplier,
    builder: (column) => ColumnFilters(column),
  );

  $$EquipmentItemsTableFilterComposer get cameraId {
    final $$EquipmentItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cameraId,
      referencedTable: $db.equipmentItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EquipmentItemsTableFilterComposer(
            $db: $db,
            $table: $db.equipmentItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$EquipmentItemsTableFilterComposer get opticId {
    final $$EquipmentItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.opticId,
      referencedTable: $db.equipmentItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EquipmentItemsTableFilterComposer(
            $db: $db,
            $table: $db.equipmentItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$EquipmentItemsTableFilterComposer get mountId {
    final $$EquipmentItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.mountId,
      referencedTable: $db.equipmentItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EquipmentItemsTableFilterComposer(
            $db: $db,
            $table: $db.equipmentItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$OpticalProfilesTableOrderingComposer
    extends Composer<_$AppDatabase, $OpticalProfilesTable> {
  $$OpticalProfilesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get focalMultiplier => $composableBuilder(
    column: $table.focalMultiplier,
    builder: (column) => ColumnOrderings(column),
  );

  $$EquipmentItemsTableOrderingComposer get cameraId {
    final $$EquipmentItemsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cameraId,
      referencedTable: $db.equipmentItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EquipmentItemsTableOrderingComposer(
            $db: $db,
            $table: $db.equipmentItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$EquipmentItemsTableOrderingComposer get opticId {
    final $$EquipmentItemsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.opticId,
      referencedTable: $db.equipmentItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EquipmentItemsTableOrderingComposer(
            $db: $db,
            $table: $db.equipmentItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$EquipmentItemsTableOrderingComposer get mountId {
    final $$EquipmentItemsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.mountId,
      referencedTable: $db.equipmentItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EquipmentItemsTableOrderingComposer(
            $db: $db,
            $table: $db.equipmentItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$OpticalProfilesTableAnnotationComposer
    extends Composer<_$AppDatabase, $OpticalProfilesTable> {
  $$OpticalProfilesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<double> get focalMultiplier => $composableBuilder(
    column: $table.focalMultiplier,
    builder: (column) => column,
  );

  $$EquipmentItemsTableAnnotationComposer get cameraId {
    final $$EquipmentItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cameraId,
      referencedTable: $db.equipmentItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EquipmentItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.equipmentItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$EquipmentItemsTableAnnotationComposer get opticId {
    final $$EquipmentItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.opticId,
      referencedTable: $db.equipmentItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EquipmentItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.equipmentItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$EquipmentItemsTableAnnotationComposer get mountId {
    final $$EquipmentItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.mountId,
      referencedTable: $db.equipmentItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EquipmentItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.equipmentItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$OpticalProfilesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $OpticalProfilesTable,
          OpticalProfileRow,
          $$OpticalProfilesTableFilterComposer,
          $$OpticalProfilesTableOrderingComposer,
          $$OpticalProfilesTableAnnotationComposer,
          $$OpticalProfilesTableCreateCompanionBuilder,
          $$OpticalProfilesTableUpdateCompanionBuilder,
          (OpticalProfileRow, $$OpticalProfilesTableReferences),
          OpticalProfileRow,
          PrefetchHooks Function({bool cameraId, bool opticId, bool mountId})
        > {
  $$OpticalProfilesTableTableManager(
    _$AppDatabase db,
    $OpticalProfilesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OpticalProfilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OpticalProfilesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OpticalProfilesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> cameraId = const Value.absent(),
                Value<String> opticId = const Value.absent(),
                Value<String?> mountId = const Value.absent(),
                Value<double> focalMultiplier = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OpticalProfilesCompanion(
                id: id,
                name: name,
                cameraId: cameraId,
                opticId: opticId,
                mountId: mountId,
                focalMultiplier: focalMultiplier,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String cameraId,
                required String opticId,
                Value<String?> mountId = const Value.absent(),
                Value<double> focalMultiplier = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OpticalProfilesCompanion.insert(
                id: id,
                name: name,
                cameraId: cameraId,
                opticId: opticId,
                mountId: mountId,
                focalMultiplier: focalMultiplier,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$OpticalProfilesTable, OpticalProfileRow>(table),
                  $$OpticalProfilesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({cameraId = false, opticId = false, mountId = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (cameraId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.cameraId,
                            referencedTable: $$OpticalProfilesTableReferences
                                ._cameraIdTable(db),
                            referencedColumn: $$OpticalProfilesTableReferences
                                ._cameraIdTable(db)
                                .id,
                          ) as T;
                        }
                        if (opticId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.opticId,
                            referencedTable: $$OpticalProfilesTableReferences
                                ._opticIdTable(db),
                            referencedColumn: $$OpticalProfilesTableReferences
                                ._opticIdTable(db)
                                .id,
                          ) as T;
                        }
                        if (mountId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.mountId,
                            referencedTable: $$OpticalProfilesTableReferences
                                ._mountIdTable(db),
                            referencedColumn: $$OpticalProfilesTableReferences
                                ._mountIdTable(db)
                                .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [];
                  },
                );
              },
        ),
      );
}

typedef $$OpticalProfilesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $OpticalProfilesTable,
      OpticalProfileRow,
      $$OpticalProfilesTableFilterComposer,
      $$OpticalProfilesTableOrderingComposer,
      $$OpticalProfilesTableAnnotationComposer,
      $$OpticalProfilesTableCreateCompanionBuilder,
      $$OpticalProfilesTableUpdateCompanionBuilder,
      (OpticalProfileRow, $$OpticalProfilesTableReferences),
      OpticalProfileRow,
      PrefetchHooks Function({bool cameraId, bool opticId, bool mountId})
    >;
typedef $$CelestialCatalogEntriesTableCreateCompanionBuilder =
    CelestialCatalogEntriesCompanion Function({
      required String id,
      required String designation,
      required String category,
      required String sourceType,
      required double raDegrees,
      required double decDegrees,
      required String constellation,
      Value<double?> visualMagnitude,
      Value<double?> majorAxisArcmin,
      Value<double?> minorAxisArcmin,
      Value<int?> messierNumber,
      Value<String> commonNames,
      Value<String> aliases,
      Value<int> rowid,
    });
typedef $$CelestialCatalogEntriesTableUpdateCompanionBuilder =
    CelestialCatalogEntriesCompanion Function({
      Value<String> id,
      Value<String> designation,
      Value<String> category,
      Value<String> sourceType,
      Value<double> raDegrees,
      Value<double> decDegrees,
      Value<String> constellation,
      Value<double?> visualMagnitude,
      Value<double?> majorAxisArcmin,
      Value<double?> minorAxisArcmin,
      Value<int?> messierNumber,
      Value<String> commonNames,
      Value<String> aliases,
      Value<int> rowid,
    });

class $$CelestialCatalogEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $CelestialCatalogEntriesTable> {
  $$CelestialCatalogEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get designation => $composableBuilder(
    column: $table.designation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceType => $composableBuilder(
    column: $table.sourceType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get raDegrees => $composableBuilder(
    column: $table.raDegrees,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get decDegrees => $composableBuilder(
    column: $table.decDegrees,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get constellation => $composableBuilder(
    column: $table.constellation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get visualMagnitude => $composableBuilder(
    column: $table.visualMagnitude,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get majorAxisArcmin => $composableBuilder(
    column: $table.majorAxisArcmin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get minorAxisArcmin => $composableBuilder(
    column: $table.minorAxisArcmin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get messierNumber => $composableBuilder(
    column: $table.messierNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get commonNames => $composableBuilder(
    column: $table.commonNames,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get aliases => $composableBuilder(
    column: $table.aliases,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CelestialCatalogEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $CelestialCatalogEntriesTable> {
  $$CelestialCatalogEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get designation => $composableBuilder(
    column: $table.designation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceType => $composableBuilder(
    column: $table.sourceType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get raDegrees => $composableBuilder(
    column: $table.raDegrees,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get decDegrees => $composableBuilder(
    column: $table.decDegrees,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get constellation => $composableBuilder(
    column: $table.constellation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get visualMagnitude => $composableBuilder(
    column: $table.visualMagnitude,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get majorAxisArcmin => $composableBuilder(
    column: $table.majorAxisArcmin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get minorAxisArcmin => $composableBuilder(
    column: $table.minorAxisArcmin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get messierNumber => $composableBuilder(
    column: $table.messierNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get commonNames => $composableBuilder(
    column: $table.commonNames,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get aliases => $composableBuilder(
    column: $table.aliases,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CelestialCatalogEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CelestialCatalogEntriesTable> {
  $$CelestialCatalogEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get designation => $composableBuilder(
    column: $table.designation,
    builder: (column) => column,
  );

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<String> get sourceType => $composableBuilder(
    column: $table.sourceType,
    builder: (column) => column,
  );

  GeneratedColumn<double> get raDegrees =>
      $composableBuilder(column: $table.raDegrees, builder: (column) => column);

  GeneratedColumn<double> get decDegrees => $composableBuilder(
    column: $table.decDegrees,
    builder: (column) => column,
  );

  GeneratedColumn<String> get constellation => $composableBuilder(
    column: $table.constellation,
    builder: (column) => column,
  );

  GeneratedColumn<double> get visualMagnitude => $composableBuilder(
    column: $table.visualMagnitude,
    builder: (column) => column,
  );

  GeneratedColumn<double> get majorAxisArcmin => $composableBuilder(
    column: $table.majorAxisArcmin,
    builder: (column) => column,
  );

  GeneratedColumn<double> get minorAxisArcmin => $composableBuilder(
    column: $table.minorAxisArcmin,
    builder: (column) => column,
  );

  GeneratedColumn<int> get messierNumber => $composableBuilder(
    column: $table.messierNumber,
    builder: (column) => column,
  );

  GeneratedColumn<String> get commonNames => $composableBuilder(
    column: $table.commonNames,
    builder: (column) => column,
  );

  GeneratedColumn<String> get aliases =>
      $composableBuilder(column: $table.aliases, builder: (column) => column);
}

class $$CelestialCatalogEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CelestialCatalogEntriesTable,
          CelestialCatalogEntryRow,
          $$CelestialCatalogEntriesTableFilterComposer,
          $$CelestialCatalogEntriesTableOrderingComposer,
          $$CelestialCatalogEntriesTableAnnotationComposer,
          $$CelestialCatalogEntriesTableCreateCompanionBuilder,
          $$CelestialCatalogEntriesTableUpdateCompanionBuilder,
          (
            CelestialCatalogEntryRow,
            BaseReferences<
              _$AppDatabase,
              $CelestialCatalogEntriesTable,
              CelestialCatalogEntryRow
            >,
          ),
          CelestialCatalogEntryRow,
          PrefetchHooks Function()
        > {
  $$CelestialCatalogEntriesTableTableManager(
    _$AppDatabase db,
    $CelestialCatalogEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CelestialCatalogEntriesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$CelestialCatalogEntriesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$CelestialCatalogEntriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> designation = const Value.absent(),
                Value<String> category = const Value.absent(),
                Value<String> sourceType = const Value.absent(),
                Value<double> raDegrees = const Value.absent(),
                Value<double> decDegrees = const Value.absent(),
                Value<String> constellation = const Value.absent(),
                Value<double?> visualMagnitude = const Value.absent(),
                Value<double?> majorAxisArcmin = const Value.absent(),
                Value<double?> minorAxisArcmin = const Value.absent(),
                Value<int?> messierNumber = const Value.absent(),
                Value<String> commonNames = const Value.absent(),
                Value<String> aliases = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CelestialCatalogEntriesCompanion(
                id: id,
                designation: designation,
                category: category,
                sourceType: sourceType,
                raDegrees: raDegrees,
                decDegrees: decDegrees,
                constellation: constellation,
                visualMagnitude: visualMagnitude,
                majorAxisArcmin: majorAxisArcmin,
                minorAxisArcmin: minorAxisArcmin,
                messierNumber: messierNumber,
                commonNames: commonNames,
                aliases: aliases,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String designation,
                required String category,
                required String sourceType,
                required double raDegrees,
                required double decDegrees,
                required String constellation,
                Value<double?> visualMagnitude = const Value.absent(),
                Value<double?> majorAxisArcmin = const Value.absent(),
                Value<double?> minorAxisArcmin = const Value.absent(),
                Value<int?> messierNumber = const Value.absent(),
                Value<String> commonNames = const Value.absent(),
                Value<String> aliases = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CelestialCatalogEntriesCompanion.insert(
                id: id,
                designation: designation,
                category: category,
                sourceType: sourceType,
                raDegrees: raDegrees,
                decDegrees: decDegrees,
                constellation: constellation,
                visualMagnitude: visualMagnitude,
                majorAxisArcmin: majorAxisArcmin,
                minorAxisArcmin: minorAxisArcmin,
                messierNumber: messierNumber,
                commonNames: commonNames,
                aliases: aliases,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $CelestialCatalogEntriesTable,
                    CelestialCatalogEntryRow
                  >(table),
                  BaseReferences<
                    _$AppDatabase,
                    $CelestialCatalogEntriesTable,
                    CelestialCatalogEntryRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CelestialCatalogEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CelestialCatalogEntriesTable,
      CelestialCatalogEntryRow,
      $$CelestialCatalogEntriesTableFilterComposer,
      $$CelestialCatalogEntriesTableOrderingComposer,
      $$CelestialCatalogEntriesTableAnnotationComposer,
      $$CelestialCatalogEntriesTableCreateCompanionBuilder,
      $$CelestialCatalogEntriesTableUpdateCompanionBuilder,
      (
        CelestialCatalogEntryRow,
        BaseReferences<
          _$AppDatabase,
          $CelestialCatalogEntriesTable,
          CelestialCatalogEntryRow
        >,
      ),
      CelestialCatalogEntryRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$AppSettingsTableTableManager get appSettings =>
      $$AppSettingsTableTableManager(_db, _db.appSettings);
  $$ObservingLocationsTableTableManager get observingLocations =>
      $$ObservingLocationsTableTableManager(_db, _db.observingLocations);
  $$EquipmentItemsTableTableManager get equipmentItems =>
      $$EquipmentItemsTableTableManager(_db, _db.equipmentItems);
  $$OpticalProfilesTableTableManager get opticalProfiles =>
      $$OpticalProfilesTableTableManager(_db, _db.opticalProfiles);
  $$CelestialCatalogEntriesTableTableManager get celestialCatalogEntries =>
      $$CelestialCatalogEntriesTableTableManager(
        _db,
        _db.celestialCatalogEntries,
      );
}
