// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $AiUsageMonthsTable extends AiUsageMonths
    with TableInfo<$AiUsageMonthsTable, AiUsageMonthRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AiUsageMonthsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _monthMeta = const VerificationMeta('month');
  @override
  late final GeneratedColumn<String> month = GeneratedColumn<String>(
    'month',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _costMicrosMeta = const VerificationMeta(
    'costMicros',
  );
  @override
  late final GeneratedColumn<int> costMicros = GeneratedColumn<int>(
    'cost_micros',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _inputTokensMeta = const VerificationMeta(
    'inputTokens',
  );
  @override
  late final GeneratedColumn<int> inputTokens = GeneratedColumn<int>(
    'input_tokens',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _outputTokensMeta = const VerificationMeta(
    'outputTokens',
  );
  @override
  late final GeneratedColumn<int> outputTokens = GeneratedColumn<int>(
    'output_tokens',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    month,
    costMicros,
    inputTokens,
    outputTokens,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ai_usage_months';
  @override
  VerificationContext validateIntegrity(
    Insertable<AiUsageMonthRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('month')) {
      context.handle(
        _monthMeta,
        month.isAcceptableOrUnknown(data['month']!, _monthMeta),
      );
    } else if (isInserting) {
      context.missing(_monthMeta);
    }
    if (data.containsKey('cost_micros')) {
      context.handle(
        _costMicrosMeta,
        costMicros.isAcceptableOrUnknown(data['cost_micros']!, _costMicrosMeta),
      );
    }
    if (data.containsKey('input_tokens')) {
      context.handle(
        _inputTokensMeta,
        inputTokens.isAcceptableOrUnknown(
          data['input_tokens']!,
          _inputTokensMeta,
        ),
      );
    }
    if (data.containsKey('output_tokens')) {
      context.handle(
        _outputTokensMeta,
        outputTokens.isAcceptableOrUnknown(
          data['output_tokens']!,
          _outputTokensMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {month};
  @override
  AiUsageMonthRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AiUsageMonthRow(
      month: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}month'],
      )!,
      costMicros: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cost_micros'],
      )!,
      inputTokens: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}input_tokens'],
      )!,
      outputTokens: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}output_tokens'],
      )!,
    );
  }

  @override
  $AiUsageMonthsTable createAlias(String alias) {
    return $AiUsageMonthsTable(attachedDatabase, alias);
  }
}

class AiUsageMonthRow extends DataClass implements Insertable<AiUsageMonthRow> {
  final String month;
  final int costMicros;
  final int inputTokens;
  final int outputTokens;
  const AiUsageMonthRow({
    required this.month,
    required this.costMicros,
    required this.inputTokens,
    required this.outputTokens,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['month'] = Variable<String>(month);
    map['cost_micros'] = Variable<int>(costMicros);
    map['input_tokens'] = Variable<int>(inputTokens);
    map['output_tokens'] = Variable<int>(outputTokens);
    return map;
  }

  AiUsageMonthsCompanion toCompanion(bool nullToAbsent) {
    return AiUsageMonthsCompanion(
      month: Value(month),
      costMicros: Value(costMicros),
      inputTokens: Value(inputTokens),
      outputTokens: Value(outputTokens),
    );
  }

  factory AiUsageMonthRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AiUsageMonthRow(
      month: serializer.fromJson<String>(json['month']),
      costMicros: serializer.fromJson<int>(json['costMicros']),
      inputTokens: serializer.fromJson<int>(json['inputTokens']),
      outputTokens: serializer.fromJson<int>(json['outputTokens']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'month': serializer.toJson<String>(month),
      'costMicros': serializer.toJson<int>(costMicros),
      'inputTokens': serializer.toJson<int>(inputTokens),
      'outputTokens': serializer.toJson<int>(outputTokens),
    };
  }

  AiUsageMonthRow copyWith({
    String? month,
    int? costMicros,
    int? inputTokens,
    int? outputTokens,
  }) => AiUsageMonthRow(
    month: month ?? this.month,
    costMicros: costMicros ?? this.costMicros,
    inputTokens: inputTokens ?? this.inputTokens,
    outputTokens: outputTokens ?? this.outputTokens,
  );
  AiUsageMonthRow copyWithCompanion(AiUsageMonthsCompanion data) {
    return AiUsageMonthRow(
      month: data.month.present ? data.month.value : this.month,
      costMicros: data.costMicros.present
          ? data.costMicros.value
          : this.costMicros,
      inputTokens: data.inputTokens.present
          ? data.inputTokens.value
          : this.inputTokens,
      outputTokens: data.outputTokens.present
          ? data.outputTokens.value
          : this.outputTokens,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AiUsageMonthRow(')
          ..write('month: $month, ')
          ..write('costMicros: $costMicros, ')
          ..write('inputTokens: $inputTokens, ')
          ..write('outputTokens: $outputTokens')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(month, costMicros, inputTokens, outputTokens);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AiUsageMonthRow &&
          other.month == this.month &&
          other.costMicros == this.costMicros &&
          other.inputTokens == this.inputTokens &&
          other.outputTokens == this.outputTokens);
}

class AiUsageMonthsCompanion extends UpdateCompanion<AiUsageMonthRow> {
  final Value<String> month;
  final Value<int> costMicros;
  final Value<int> inputTokens;
  final Value<int> outputTokens;
  final Value<int> rowid;
  const AiUsageMonthsCompanion({
    this.month = const Value.absent(),
    this.costMicros = const Value.absent(),
    this.inputTokens = const Value.absent(),
    this.outputTokens = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AiUsageMonthsCompanion.insert({
    required String month,
    this.costMicros = const Value.absent(),
    this.inputTokens = const Value.absent(),
    this.outputTokens = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : month = Value(month);
  static Insertable<AiUsageMonthRow> custom({
    Expression<String>? month,
    Expression<int>? costMicros,
    Expression<int>? inputTokens,
    Expression<int>? outputTokens,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (month != null) 'month': month,
      if (costMicros != null) 'cost_micros': costMicros,
      if (inputTokens != null) 'input_tokens': inputTokens,
      if (outputTokens != null) 'output_tokens': outputTokens,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AiUsageMonthsCompanion copyWith({
    Value<String>? month,
    Value<int>? costMicros,
    Value<int>? inputTokens,
    Value<int>? outputTokens,
    Value<int>? rowid,
  }) {
    return AiUsageMonthsCompanion(
      month: month ?? this.month,
      costMicros: costMicros ?? this.costMicros,
      inputTokens: inputTokens ?? this.inputTokens,
      outputTokens: outputTokens ?? this.outputTokens,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (month.present) {
      map['month'] = Variable<String>(month.value);
    }
    if (costMicros.present) {
      map['cost_micros'] = Variable<int>(costMicros.value);
    }
    if (inputTokens.present) {
      map['input_tokens'] = Variable<int>(inputTokens.value);
    }
    if (outputTokens.present) {
      map['output_tokens'] = Variable<int>(outputTokens.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AiUsageMonthsCompanion(')
          ..write('month: $month, ')
          ..write('costMicros: $costMicros, ')
          ..write('inputTokens: $inputTokens, ')
          ..write('outputTokens: $outputTokens, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AppearanceSettingsTable extends AppearanceSettings
    with TableInfo<$AppearanceSettingsTable, AppearanceRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppearanceSettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _themeMeta = const VerificationMeta('theme');
  @override
  late final GeneratedColumn<String> theme = GeneratedColumn<String>(
    'theme',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('system'),
  );
  static const VerificationMeta _accentMeta = const VerificationMeta('accent');
  @override
  late final GeneratedColumn<String> accent = GeneratedColumn<String>(
    'accent',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('indigo'),
  );
  static const VerificationMeta _fontFamilyMeta = const VerificationMeta(
    'fontFamily',
  );
  @override
  late final GeneratedColumn<String> fontFamily = GeneratedColumn<String>(
    'font_family',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('Poppins'),
  );
  static const VerificationMeta _diaryTitleFontFamilyMeta =
      const VerificationMeta('diaryTitleFontFamily');
  @override
  late final GeneratedColumn<String> diaryTitleFontFamily =
      GeneratedColumn<String>(
        'diary_title_font_family',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('Caveat'),
      );
  static const VerificationMeta _diaryBodyFontFamilyMeta =
      const VerificationMeta('diaryBodyFontFamily');
  @override
  late final GeneratedColumn<String> diaryBodyFontFamily =
      GeneratedColumn<String>(
        'diary_body_font_family',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('Literata'),
      );
  static const VerificationMeta _reduceMotionMeta = const VerificationMeta(
    'reduceMotion',
  );
  @override
  late final GeneratedColumn<bool> reduceMotion = GeneratedColumn<bool>(
    'reduce_motion',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("reduce_motion" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _simplerEffectsMeta = const VerificationMeta(
    'simplerEffects',
  );
  @override
  late final GeneratedColumn<bool> simplerEffects = GeneratedColumn<bool>(
    'simpler_effects',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("simpler_effects" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    theme,
    accent,
    fontFamily,
    diaryTitleFontFamily,
    diaryBodyFontFamily,
    reduceMotion,
    simplerEffects,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'appearance_settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<AppearanceRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('theme')) {
      context.handle(
        _themeMeta,
        theme.isAcceptableOrUnknown(data['theme']!, _themeMeta),
      );
    }
    if (data.containsKey('accent')) {
      context.handle(
        _accentMeta,
        accent.isAcceptableOrUnknown(data['accent']!, _accentMeta),
      );
    }
    if (data.containsKey('font_family')) {
      context.handle(
        _fontFamilyMeta,
        fontFamily.isAcceptableOrUnknown(data['font_family']!, _fontFamilyMeta),
      );
    }
    if (data.containsKey('diary_title_font_family')) {
      context.handle(
        _diaryTitleFontFamilyMeta,
        diaryTitleFontFamily.isAcceptableOrUnknown(
          data['diary_title_font_family']!,
          _diaryTitleFontFamilyMeta,
        ),
      );
    }
    if (data.containsKey('diary_body_font_family')) {
      context.handle(
        _diaryBodyFontFamilyMeta,
        diaryBodyFontFamily.isAcceptableOrUnknown(
          data['diary_body_font_family']!,
          _diaryBodyFontFamilyMeta,
        ),
      );
    }
    if (data.containsKey('reduce_motion')) {
      context.handle(
        _reduceMotionMeta,
        reduceMotion.isAcceptableOrUnknown(
          data['reduce_motion']!,
          _reduceMotionMeta,
        ),
      );
    }
    if (data.containsKey('simpler_effects')) {
      context.handle(
        _simplerEffectsMeta,
        simplerEffects.isAcceptableOrUnknown(
          data['simpler_effects']!,
          _simplerEffectsMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AppearanceRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppearanceRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      theme: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}theme'],
      )!,
      accent: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}accent'],
      )!,
      fontFamily: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}font_family'],
      )!,
      diaryTitleFontFamily: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}diary_title_font_family'],
      )!,
      diaryBodyFontFamily: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}diary_body_font_family'],
      )!,
      reduceMotion: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}reduce_motion'],
      )!,
      simplerEffects: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}simpler_effects'],
      )!,
    );
  }

  @override
  $AppearanceSettingsTable createAlias(String alias) {
    return $AppearanceSettingsTable(attachedDatabase, alias);
  }
}

class AppearanceRow extends DataClass implements Insertable<AppearanceRow> {
  final int id;
  final String theme;
  final String accent;
  final String fontFamily;
  final String diaryTitleFontFamily;
  final String diaryBodyFontFamily;
  final bool reduceMotion;
  final bool simplerEffects;
  const AppearanceRow({
    required this.id,
    required this.theme,
    required this.accent,
    required this.fontFamily,
    required this.diaryTitleFontFamily,
    required this.diaryBodyFontFamily,
    required this.reduceMotion,
    required this.simplerEffects,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['theme'] = Variable<String>(theme);
    map['accent'] = Variable<String>(accent);
    map['font_family'] = Variable<String>(fontFamily);
    map['diary_title_font_family'] = Variable<String>(diaryTitleFontFamily);
    map['diary_body_font_family'] = Variable<String>(diaryBodyFontFamily);
    map['reduce_motion'] = Variable<bool>(reduceMotion);
    map['simpler_effects'] = Variable<bool>(simplerEffects);
    return map;
  }

  AppearanceSettingsCompanion toCompanion(bool nullToAbsent) {
    return AppearanceSettingsCompanion(
      id: Value(id),
      theme: Value(theme),
      accent: Value(accent),
      fontFamily: Value(fontFamily),
      diaryTitleFontFamily: Value(diaryTitleFontFamily),
      diaryBodyFontFamily: Value(diaryBodyFontFamily),
      reduceMotion: Value(reduceMotion),
      simplerEffects: Value(simplerEffects),
    );
  }

  factory AppearanceRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppearanceRow(
      id: serializer.fromJson<int>(json['id']),
      theme: serializer.fromJson<String>(json['theme']),
      accent: serializer.fromJson<String>(json['accent']),
      fontFamily: serializer.fromJson<String>(json['fontFamily']),
      diaryTitleFontFamily: serializer.fromJson<String>(
        json['diaryTitleFontFamily'],
      ),
      diaryBodyFontFamily: serializer.fromJson<String>(
        json['diaryBodyFontFamily'],
      ),
      reduceMotion: serializer.fromJson<bool>(json['reduceMotion']),
      simplerEffects: serializer.fromJson<bool>(json['simplerEffects']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'theme': serializer.toJson<String>(theme),
      'accent': serializer.toJson<String>(accent),
      'fontFamily': serializer.toJson<String>(fontFamily),
      'diaryTitleFontFamily': serializer.toJson<String>(diaryTitleFontFamily),
      'diaryBodyFontFamily': serializer.toJson<String>(diaryBodyFontFamily),
      'reduceMotion': serializer.toJson<bool>(reduceMotion),
      'simplerEffects': serializer.toJson<bool>(simplerEffects),
    };
  }

  AppearanceRow copyWith({
    int? id,
    String? theme,
    String? accent,
    String? fontFamily,
    String? diaryTitleFontFamily,
    String? diaryBodyFontFamily,
    bool? reduceMotion,
    bool? simplerEffects,
  }) => AppearanceRow(
    id: id ?? this.id,
    theme: theme ?? this.theme,
    accent: accent ?? this.accent,
    fontFamily: fontFamily ?? this.fontFamily,
    diaryTitleFontFamily: diaryTitleFontFamily ?? this.diaryTitleFontFamily,
    diaryBodyFontFamily: diaryBodyFontFamily ?? this.diaryBodyFontFamily,
    reduceMotion: reduceMotion ?? this.reduceMotion,
    simplerEffects: simplerEffects ?? this.simplerEffects,
  );
  AppearanceRow copyWithCompanion(AppearanceSettingsCompanion data) {
    return AppearanceRow(
      id: data.id.present ? data.id.value : this.id,
      theme: data.theme.present ? data.theme.value : this.theme,
      accent: data.accent.present ? data.accent.value : this.accent,
      fontFamily: data.fontFamily.present
          ? data.fontFamily.value
          : this.fontFamily,
      diaryTitleFontFamily: data.diaryTitleFontFamily.present
          ? data.diaryTitleFontFamily.value
          : this.diaryTitleFontFamily,
      diaryBodyFontFamily: data.diaryBodyFontFamily.present
          ? data.diaryBodyFontFamily.value
          : this.diaryBodyFontFamily,
      reduceMotion: data.reduceMotion.present
          ? data.reduceMotion.value
          : this.reduceMotion,
      simplerEffects: data.simplerEffects.present
          ? data.simplerEffects.value
          : this.simplerEffects,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppearanceRow(')
          ..write('id: $id, ')
          ..write('theme: $theme, ')
          ..write('accent: $accent, ')
          ..write('fontFamily: $fontFamily, ')
          ..write('diaryTitleFontFamily: $diaryTitleFontFamily, ')
          ..write('diaryBodyFontFamily: $diaryBodyFontFamily, ')
          ..write('reduceMotion: $reduceMotion, ')
          ..write('simplerEffects: $simplerEffects')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    theme,
    accent,
    fontFamily,
    diaryTitleFontFamily,
    diaryBodyFontFamily,
    reduceMotion,
    simplerEffects,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppearanceRow &&
          other.id == this.id &&
          other.theme == this.theme &&
          other.accent == this.accent &&
          other.fontFamily == this.fontFamily &&
          other.diaryTitleFontFamily == this.diaryTitleFontFamily &&
          other.diaryBodyFontFamily == this.diaryBodyFontFamily &&
          other.reduceMotion == this.reduceMotion &&
          other.simplerEffects == this.simplerEffects);
}

class AppearanceSettingsCompanion extends UpdateCompanion<AppearanceRow> {
  final Value<int> id;
  final Value<String> theme;
  final Value<String> accent;
  final Value<String> fontFamily;
  final Value<String> diaryTitleFontFamily;
  final Value<String> diaryBodyFontFamily;
  final Value<bool> reduceMotion;
  final Value<bool> simplerEffects;
  const AppearanceSettingsCompanion({
    this.id = const Value.absent(),
    this.theme = const Value.absent(),
    this.accent = const Value.absent(),
    this.fontFamily = const Value.absent(),
    this.diaryTitleFontFamily = const Value.absent(),
    this.diaryBodyFontFamily = const Value.absent(),
    this.reduceMotion = const Value.absent(),
    this.simplerEffects = const Value.absent(),
  });
  AppearanceSettingsCompanion.insert({
    this.id = const Value.absent(),
    this.theme = const Value.absent(),
    this.accent = const Value.absent(),
    this.fontFamily = const Value.absent(),
    this.diaryTitleFontFamily = const Value.absent(),
    this.diaryBodyFontFamily = const Value.absent(),
    this.reduceMotion = const Value.absent(),
    this.simplerEffects = const Value.absent(),
  });
  static Insertable<AppearanceRow> custom({
    Expression<int>? id,
    Expression<String>? theme,
    Expression<String>? accent,
    Expression<String>? fontFamily,
    Expression<String>? diaryTitleFontFamily,
    Expression<String>? diaryBodyFontFamily,
    Expression<bool>? reduceMotion,
    Expression<bool>? simplerEffects,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (theme != null) 'theme': theme,
      if (accent != null) 'accent': accent,
      if (fontFamily != null) 'font_family': fontFamily,
      if (diaryTitleFontFamily != null)
        'diary_title_font_family': diaryTitleFontFamily,
      if (diaryBodyFontFamily != null)
        'diary_body_font_family': diaryBodyFontFamily,
      if (reduceMotion != null) 'reduce_motion': reduceMotion,
      if (simplerEffects != null) 'simpler_effects': simplerEffects,
    });
  }

  AppearanceSettingsCompanion copyWith({
    Value<int>? id,
    Value<String>? theme,
    Value<String>? accent,
    Value<String>? fontFamily,
    Value<String>? diaryTitleFontFamily,
    Value<String>? diaryBodyFontFamily,
    Value<bool>? reduceMotion,
    Value<bool>? simplerEffects,
  }) {
    return AppearanceSettingsCompanion(
      id: id ?? this.id,
      theme: theme ?? this.theme,
      accent: accent ?? this.accent,
      fontFamily: fontFamily ?? this.fontFamily,
      diaryTitleFontFamily: diaryTitleFontFamily ?? this.diaryTitleFontFamily,
      diaryBodyFontFamily: diaryBodyFontFamily ?? this.diaryBodyFontFamily,
      reduceMotion: reduceMotion ?? this.reduceMotion,
      simplerEffects: simplerEffects ?? this.simplerEffects,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (theme.present) {
      map['theme'] = Variable<String>(theme.value);
    }
    if (accent.present) {
      map['accent'] = Variable<String>(accent.value);
    }
    if (fontFamily.present) {
      map['font_family'] = Variable<String>(fontFamily.value);
    }
    if (diaryTitleFontFamily.present) {
      map['diary_title_font_family'] = Variable<String>(
        diaryTitleFontFamily.value,
      );
    }
    if (diaryBodyFontFamily.present) {
      map['diary_body_font_family'] = Variable<String>(
        diaryBodyFontFamily.value,
      );
    }
    if (reduceMotion.present) {
      map['reduce_motion'] = Variable<bool>(reduceMotion.value);
    }
    if (simplerEffects.present) {
      map['simpler_effects'] = Variable<bool>(simplerEffects.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppearanceSettingsCompanion(')
          ..write('id: $id, ')
          ..write('theme: $theme, ')
          ..write('accent: $accent, ')
          ..write('fontFamily: $fontFamily, ')
          ..write('diaryTitleFontFamily: $diaryTitleFontFamily, ')
          ..write('diaryBodyFontFamily: $diaryBodyFontFamily, ')
          ..write('reduceMotion: $reduceMotion, ')
          ..write('simplerEffects: $simplerEffects')
          ..write(')'))
        .toString();
  }
}

class $OnboardingCompletionTable extends OnboardingCompletion
    with TableInfo<$OnboardingCompletionTable, OnboardingCompletionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OnboardingCompletionTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (length(trim(name)) BETWEEN 1 AND 160)',
  );
  @override
  List<GeneratedColumn> get $columns => [id, name];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'onboarding_completion';
  @override
  VerificationContext validateIntegrity(
    Insertable<OnboardingCompletionRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  OnboardingCompletionRow map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OnboardingCompletionRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
    );
  }

  @override
  $OnboardingCompletionTable createAlias(String alias) {
    return $OnboardingCompletionTable(attachedDatabase, alias);
  }
}

class OnboardingCompletionRow extends DataClass
    implements Insertable<OnboardingCompletionRow> {
  final int id;
  final String name;
  const OnboardingCompletionRow({required this.id, required this.name});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    return map;
  }

  OnboardingCompletionCompanion toCompanion(bool nullToAbsent) {
    return OnboardingCompletionCompanion(id: Value(id), name: Value(name));
  }

  factory OnboardingCompletionRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OnboardingCompletionRow(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
    };
  }

  OnboardingCompletionRow copyWith({int? id, String? name}) =>
      OnboardingCompletionRow(id: id ?? this.id, name: name ?? this.name);
  OnboardingCompletionRow copyWithCompanion(
    OnboardingCompletionCompanion data,
  ) {
    return OnboardingCompletionRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OnboardingCompletionRow(')
          ..write('id: $id, ')
          ..write('name: $name')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OnboardingCompletionRow &&
          other.id == this.id &&
          other.name == this.name);
}

class OnboardingCompletionCompanion
    extends UpdateCompanion<OnboardingCompletionRow> {
  final Value<int> id;
  final Value<String> name;
  const OnboardingCompletionCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
  });
  OnboardingCompletionCompanion.insert({
    this.id = const Value.absent(),
    required String name,
  }) : name = Value(name);
  static Insertable<OnboardingCompletionRow> custom({
    Expression<int>? id,
    Expression<String>? name,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
    });
  }

  OnboardingCompletionCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
  }) {
    return OnboardingCompletionCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OnboardingCompletionCompanion(')
          ..write('id: $id, ')
          ..write('name: $name')
          ..write(')'))
        .toString();
  }
}

class $NotesTable extends Notes with TableInfo<$NotesTable, Note> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NotesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _detailsMeta = const VerificationMeta(
    'details',
  );
  @override
  late final GeneratedColumn<String> details = GeneratedColumn<String>(
    'details',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'body',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
    'revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (revision > 0)',
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pinnedMeta = const VerificationMeta('pinned');
  @override
  late final GeneratedColumn<bool> pinned = GeneratedColumn<bool>(
    'pinned',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("pinned" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    details,
    id,
    title,
    body,
    revision,
    createdAt,
    updatedAt,
    pinned,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'notes';
  @override
  VerificationContext validateIntegrity(
    Insertable<Note> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('details')) {
      context.handle(
        _detailsMeta,
        details.isAcceptableOrUnknown(data['details']!, _detailsMeta),
      );
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('body')) {
      context.handle(
        _bodyMeta,
        body.isAcceptableOrUnknown(data['body']!, _bodyMeta),
      );
    } else if (isInserting) {
      context.missing(_bodyMeta);
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
      );
    } else if (isInserting) {
      context.missing(_revisionMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('pinned')) {
      context.handle(
        _pinnedMeta,
        pinned.isAcceptableOrUnknown(data['pinned']!, _pinnedMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Note map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Note(
      details: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}details'],
      )!,
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      body: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body'],
      )!,
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revision'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      pinned: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}pinned'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $NotesTable createAlias(String alias) {
    return $NotesTable(attachedDatabase, alias);
  }
}

class Note extends DataClass implements Insertable<Note> {
  final String details;
  final String id;
  final String title;
  final String body;
  final int revision;
  final int createdAt;
  final int updatedAt;
  final bool pinned;
  final int? deletedAt;
  const Note({
    required this.details,
    required this.id,
    required this.title,
    required this.body,
    required this.revision,
    required this.createdAt,
    required this.updatedAt,
    required this.pinned,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['details'] = Variable<String>(details);
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    map['body'] = Variable<String>(body);
    map['revision'] = Variable<int>(revision);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    map['pinned'] = Variable<bool>(pinned);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    return map;
  }

  NotesCompanion toCompanion(bool nullToAbsent) {
    return NotesCompanion(
      details: Value(details),
      id: Value(id),
      title: Value(title),
      body: Value(body),
      revision: Value(revision),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      pinned: Value(pinned),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory Note.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Note(
      details: serializer.fromJson<String>(json['details']),
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      body: serializer.fromJson<String>(json['body']),
      revision: serializer.fromJson<int>(json['revision']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      pinned: serializer.fromJson<bool>(json['pinned']),
      deletedAt: serializer.fromJson<int?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'details': serializer.toJson<String>(details),
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'body': serializer.toJson<String>(body),
      'revision': serializer.toJson<int>(revision),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'pinned': serializer.toJson<bool>(pinned),
      'deletedAt': serializer.toJson<int?>(deletedAt),
    };
  }

  Note copyWith({
    String? details,
    String? id,
    String? title,
    String? body,
    int? revision,
    int? createdAt,
    int? updatedAt,
    bool? pinned,
    Value<int?> deletedAt = const Value.absent(),
  }) => Note(
    details: details ?? this.details,
    id: id ?? this.id,
    title: title ?? this.title,
    body: body ?? this.body,
    revision: revision ?? this.revision,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    pinned: pinned ?? this.pinned,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  Note copyWithCompanion(NotesCompanion data) {
    return Note(
      details: data.details.present ? data.details.value : this.details,
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      body: data.body.present ? data.body.value : this.body,
      revision: data.revision.present ? data.revision.value : this.revision,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      pinned: data.pinned.present ? data.pinned.value : this.pinned,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Note(')
          ..write('details: $details, ')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('body: $body, ')
          ..write('revision: $revision, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('pinned: $pinned, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    details,
    id,
    title,
    body,
    revision,
    createdAt,
    updatedAt,
    pinned,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Note &&
          other.details == this.details &&
          other.id == this.id &&
          other.title == this.title &&
          other.body == this.body &&
          other.revision == this.revision &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.pinned == this.pinned &&
          other.deletedAt == this.deletedAt);
}

class NotesCompanion extends UpdateCompanion<Note> {
  final Value<String> details;
  final Value<String> id;
  final Value<String> title;
  final Value<String> body;
  final Value<int> revision;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<bool> pinned;
  final Value<int?> deletedAt;
  final Value<int> rowid;
  const NotesCompanion({
    this.details = const Value.absent(),
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.body = const Value.absent(),
    this.revision = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.pinned = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  NotesCompanion.insert({
    this.details = const Value.absent(),
    required String id,
    required String title,
    required String body,
    required int revision,
    required int createdAt,
    required int updatedAt,
    this.pinned = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       title = Value(title),
       body = Value(body),
       revision = Value(revision),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<Note> custom({
    Expression<String>? details,
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? body,
    Expression<int>? revision,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<bool>? pinned,
    Expression<int>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (details != null) 'details': details,
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (body != null) 'body': body,
      if (revision != null) 'revision': revision,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (pinned != null) 'pinned': pinned,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  NotesCompanion copyWith({
    Value<String>? details,
    Value<String>? id,
    Value<String>? title,
    Value<String>? body,
    Value<int>? revision,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<bool>? pinned,
    Value<int?>? deletedAt,
    Value<int>? rowid,
  }) {
    return NotesCompanion(
      details: details ?? this.details,
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      revision: revision ?? this.revision,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      pinned: pinned ?? this.pinned,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (details.present) {
      map['details'] = Variable<String>(details.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (pinned.present) {
      map['pinned'] = Variable<bool>(pinned.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NotesCompanion(')
          ..write('details: $details, ')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('body: $body, ')
          ..write('revision: $revision, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('pinned: $pinned, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $NoteTagsTable extends NoteTags with TableInfo<$NoteTagsTable, NoteTag> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NoteTagsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _noteIdMeta = const VerificationMeta('noteId');
  @override
  late final GeneratedColumn<String> noteId = GeneratedColumn<String>(
    'note_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES notes (id)',
    ),
  );
  static const VerificationMeta _tagMeta = const VerificationMeta('tag');
  @override
  late final GeneratedColumn<String> tag = GeneratedColumn<String>(
    'tag',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 40,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [noteId, tag];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'note_tags';
  @override
  VerificationContext validateIntegrity(
    Insertable<NoteTag> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('note_id')) {
      context.handle(
        _noteIdMeta,
        noteId.isAcceptableOrUnknown(data['note_id']!, _noteIdMeta),
      );
    } else if (isInserting) {
      context.missing(_noteIdMeta);
    }
    if (data.containsKey('tag')) {
      context.handle(
        _tagMeta,
        tag.isAcceptableOrUnknown(data['tag']!, _tagMeta),
      );
    } else if (isInserting) {
      context.missing(_tagMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {noteId, tag};
  @override
  NoteTag map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return NoteTag(
      noteId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note_id'],
      )!,
      tag: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tag'],
      )!,
    );
  }

  @override
  $NoteTagsTable createAlias(String alias) {
    return $NoteTagsTable(attachedDatabase, alias);
  }
}

class NoteTag extends DataClass implements Insertable<NoteTag> {
  final String noteId;
  final String tag;
  const NoteTag({required this.noteId, required this.tag});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['note_id'] = Variable<String>(noteId);
    map['tag'] = Variable<String>(tag);
    return map;
  }

  NoteTagsCompanion toCompanion(bool nullToAbsent) {
    return NoteTagsCompanion(noteId: Value(noteId), tag: Value(tag));
  }

  factory NoteTag.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return NoteTag(
      noteId: serializer.fromJson<String>(json['noteId']),
      tag: serializer.fromJson<String>(json['tag']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'noteId': serializer.toJson<String>(noteId),
      'tag': serializer.toJson<String>(tag),
    };
  }

  NoteTag copyWith({String? noteId, String? tag}) =>
      NoteTag(noteId: noteId ?? this.noteId, tag: tag ?? this.tag);
  NoteTag copyWithCompanion(NoteTagsCompanion data) {
    return NoteTag(
      noteId: data.noteId.present ? data.noteId.value : this.noteId,
      tag: data.tag.present ? data.tag.value : this.tag,
    );
  }

  @override
  String toString() {
    return (StringBuffer('NoteTag(')
          ..write('noteId: $noteId, ')
          ..write('tag: $tag')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(noteId, tag);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NoteTag &&
          other.noteId == this.noteId &&
          other.tag == this.tag);
}

class NoteTagsCompanion extends UpdateCompanion<NoteTag> {
  final Value<String> noteId;
  final Value<String> tag;
  final Value<int> rowid;
  const NoteTagsCompanion({
    this.noteId = const Value.absent(),
    this.tag = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  NoteTagsCompanion.insert({
    required String noteId,
    required String tag,
    this.rowid = const Value.absent(),
  }) : noteId = Value(noteId),
       tag = Value(tag);
  static Insertable<NoteTag> custom({
    Expression<String>? noteId,
    Expression<String>? tag,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (noteId != null) 'note_id': noteId,
      if (tag != null) 'tag': tag,
      if (rowid != null) 'rowid': rowid,
    });
  }

  NoteTagsCompanion copyWith({
    Value<String>? noteId,
    Value<String>? tag,
    Value<int>? rowid,
  }) {
    return NoteTagsCompanion(
      noteId: noteId ?? this.noteId,
      tag: tag ?? this.tag,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (noteId.present) {
      map['note_id'] = Variable<String>(noteId.value);
    }
    if (tag.present) {
      map['tag'] = Variable<String>(tag.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NoteTagsCompanion(')
          ..write('noteId: $noteId, ')
          ..write('tag: $tag, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $NoteMediaOpsTable extends NoteMediaOps
    with TableInfo<$NoteMediaOpsTable, NoteMediaOp> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NoteMediaOpsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
    'path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdMeta = const VerificationMeta(
    'created',
  );
  @override
  late final GeneratedColumn<int> created = GeneratedColumn<int>(
    'created',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [path, created];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'note_media_ops';
  @override
  VerificationContext validateIntegrity(
    Insertable<NoteMediaOp> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('path')) {
      context.handle(
        _pathMeta,
        path.isAcceptableOrUnknown(data['path']!, _pathMeta),
      );
    } else if (isInserting) {
      context.missing(_pathMeta);
    }
    if (data.containsKey('created')) {
      context.handle(
        _createdMeta,
        created.isAcceptableOrUnknown(data['created']!, _createdMeta),
      );
    } else if (isInserting) {
      context.missing(_createdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {path};
  @override
  NoteMediaOp map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return NoteMediaOp(
      path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path'],
      )!,
      created: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created'],
      )!,
    );
  }

  @override
  $NoteMediaOpsTable createAlias(String alias) {
    return $NoteMediaOpsTable(attachedDatabase, alias);
  }
}

class NoteMediaOp extends DataClass implements Insertable<NoteMediaOp> {
  final String path;
  final int created;
  const NoteMediaOp({required this.path, required this.created});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['path'] = Variable<String>(path);
    map['created'] = Variable<int>(created);
    return map;
  }

  NoteMediaOpsCompanion toCompanion(bool nullToAbsent) {
    return NoteMediaOpsCompanion(path: Value(path), created: Value(created));
  }

  factory NoteMediaOp.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return NoteMediaOp(
      path: serializer.fromJson<String>(json['path']),
      created: serializer.fromJson<int>(json['created']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'path': serializer.toJson<String>(path),
      'created': serializer.toJson<int>(created),
    };
  }

  NoteMediaOp copyWith({String? path, int? created}) =>
      NoteMediaOp(path: path ?? this.path, created: created ?? this.created);
  NoteMediaOp copyWithCompanion(NoteMediaOpsCompanion data) {
    return NoteMediaOp(
      path: data.path.present ? data.path.value : this.path,
      created: data.created.present ? data.created.value : this.created,
    );
  }

  @override
  String toString() {
    return (StringBuffer('NoteMediaOp(')
          ..write('path: $path, ')
          ..write('created: $created')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(path, created);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NoteMediaOp &&
          other.path == this.path &&
          other.created == this.created);
}

class NoteMediaOpsCompanion extends UpdateCompanion<NoteMediaOp> {
  final Value<String> path;
  final Value<int> created;
  final Value<int> rowid;
  const NoteMediaOpsCompanion({
    this.path = const Value.absent(),
    this.created = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  NoteMediaOpsCompanion.insert({
    required String path,
    required int created,
    this.rowid = const Value.absent(),
  }) : path = Value(path),
       created = Value(created);
  static Insertable<NoteMediaOp> custom({
    Expression<String>? path,
    Expression<int>? created,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (path != null) 'path': path,
      if (created != null) 'created': created,
      if (rowid != null) 'rowid': rowid,
    });
  }

  NoteMediaOpsCompanion copyWith({
    Value<String>? path,
    Value<int>? created,
    Value<int>? rowid,
  }) {
    return NoteMediaOpsCompanion(
      path: path ?? this.path,
      created: created ?? this.created,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (created.present) {
      map['created'] = Variable<int>(created.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NoteMediaOpsCompanion(')
          ..write('path: $path, ')
          ..write('created: $created, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $NoteWebsitesTable extends NoteWebsites
    with TableInfo<$NoteWebsitesTable, NoteWebsiteRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NoteWebsitesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _noteIdMeta = const VerificationMeta('noteId');
  @override
  late final GeneratedColumn<String> noteId = GeneratedColumn<String>(
    'note_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES notes (id)',
    ),
  );
  static const VerificationMeta _htmlMeta = const VerificationMeta('html');
  @override
  late final GeneratedColumn<String> html = GeneratedColumn<String>(
    'html',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceHashMeta = const VerificationMeta(
    'sourceHash',
  );
  @override
  late final GeneratedColumn<String> sourceHash = GeneratedColumn<String>(
    'source_hash',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _briefMeta = const VerificationMeta('brief');
  @override
  late final GeneratedColumn<String> brief = GeneratedColumn<String>(
    'brief',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _modelMeta = const VerificationMeta('model');
  @override
  late final GeneratedColumn<String> model = GeneratedColumn<String>(
    'model',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _madeAtMeta = const VerificationMeta('madeAt');
  @override
  late final GeneratedColumn<int> madeAt = GeneratedColumn<int>(
    'made_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _stateMeta = const VerificationMeta('state');
  @override
  late final GeneratedColumn<String> state = GeneratedColumn<String>(
    'state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _previousHtmlMeta = const VerificationMeta(
    'previousHtml',
  );
  @override
  late final GeneratedColumn<String> previousHtml = GeneratedColumn<String>(
    'previous_html',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _previousSourceHashMeta =
      const VerificationMeta('previousSourceHash');
  @override
  late final GeneratedColumn<String> previousSourceHash =
      GeneratedColumn<String>(
        'previous_source_hash',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant(''),
      );
  static const VerificationMeta _syncChecksMeta = const VerificationMeta(
    'syncChecks',
  );
  @override
  late final GeneratedColumn<bool> syncChecks = GeneratedColumn<bool>(
    'sync_checks',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("sync_checks" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    noteId,
    html,
    sourceHash,
    brief,
    model,
    madeAt,
    state,
    previousHtml,
    previousSourceHash,
    syncChecks,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'note_websites';
  @override
  VerificationContext validateIntegrity(
    Insertable<NoteWebsiteRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('note_id')) {
      context.handle(
        _noteIdMeta,
        noteId.isAcceptableOrUnknown(data['note_id']!, _noteIdMeta),
      );
    } else if (isInserting) {
      context.missing(_noteIdMeta);
    }
    if (data.containsKey('html')) {
      context.handle(
        _htmlMeta,
        html.isAcceptableOrUnknown(data['html']!, _htmlMeta),
      );
    } else if (isInserting) {
      context.missing(_htmlMeta);
    }
    if (data.containsKey('source_hash')) {
      context.handle(
        _sourceHashMeta,
        sourceHash.isAcceptableOrUnknown(data['source_hash']!, _sourceHashMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceHashMeta);
    }
    if (data.containsKey('brief')) {
      context.handle(
        _briefMeta,
        brief.isAcceptableOrUnknown(data['brief']!, _briefMeta),
      );
    }
    if (data.containsKey('model')) {
      context.handle(
        _modelMeta,
        model.isAcceptableOrUnknown(data['model']!, _modelMeta),
      );
    }
    if (data.containsKey('made_at')) {
      context.handle(
        _madeAtMeta,
        madeAt.isAcceptableOrUnknown(data['made_at']!, _madeAtMeta),
      );
    } else if (isInserting) {
      context.missing(_madeAtMeta);
    }
    if (data.containsKey('state')) {
      context.handle(
        _stateMeta,
        state.isAcceptableOrUnknown(data['state']!, _stateMeta),
      );
    }
    if (data.containsKey('previous_html')) {
      context.handle(
        _previousHtmlMeta,
        previousHtml.isAcceptableOrUnknown(
          data['previous_html']!,
          _previousHtmlMeta,
        ),
      );
    }
    if (data.containsKey('previous_source_hash')) {
      context.handle(
        _previousSourceHashMeta,
        previousSourceHash.isAcceptableOrUnknown(
          data['previous_source_hash']!,
          _previousSourceHashMeta,
        ),
      );
    }
    if (data.containsKey('sync_checks')) {
      context.handle(
        _syncChecksMeta,
        syncChecks.isAcceptableOrUnknown(data['sync_checks']!, _syncChecksMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {noteId};
  @override
  NoteWebsiteRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return NoteWebsiteRow(
      noteId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note_id'],
      )!,
      html: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}html'],
      )!,
      sourceHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_hash'],
      )!,
      brief: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}brief'],
      )!,
      model: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}model'],
      )!,
      madeAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}made_at'],
      )!,
      state: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}state'],
      )!,
      previousHtml: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}previous_html'],
      )!,
      previousSourceHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}previous_source_hash'],
      )!,
      syncChecks: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}sync_checks'],
      )!,
    );
  }

  @override
  $NoteWebsitesTable createAlias(String alias) {
    return $NoteWebsitesTable(attachedDatabase, alias);
  }
}

class NoteWebsiteRow extends DataClass implements Insertable<NoteWebsiteRow> {
  final String noteId;
  final String html;

  /// SHA-256 of the note body the website was made from.
  final String sourceHash;

  /// The person's description of the website; may be empty.
  final String brief;
  final String model;
  final int madeAt;

  /// What the page saved for itself (ticks, scores, progress), as JSON.
  final String state;

  /// The page before the last remix or rebuild, so it can be undone.
  final String previousHtml;
  final String previousSourceHash;

  /// Ticks on the page update the note's checklist without asking.
  final bool syncChecks;
  const NoteWebsiteRow({
    required this.noteId,
    required this.html,
    required this.sourceHash,
    required this.brief,
    required this.model,
    required this.madeAt,
    required this.state,
    required this.previousHtml,
    required this.previousSourceHash,
    required this.syncChecks,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['note_id'] = Variable<String>(noteId);
    map['html'] = Variable<String>(html);
    map['source_hash'] = Variable<String>(sourceHash);
    map['brief'] = Variable<String>(brief);
    map['model'] = Variable<String>(model);
    map['made_at'] = Variable<int>(madeAt);
    map['state'] = Variable<String>(state);
    map['previous_html'] = Variable<String>(previousHtml);
    map['previous_source_hash'] = Variable<String>(previousSourceHash);
    map['sync_checks'] = Variable<bool>(syncChecks);
    return map;
  }

  NoteWebsitesCompanion toCompanion(bool nullToAbsent) {
    return NoteWebsitesCompanion(
      noteId: Value(noteId),
      html: Value(html),
      sourceHash: Value(sourceHash),
      brief: Value(brief),
      model: Value(model),
      madeAt: Value(madeAt),
      state: Value(state),
      previousHtml: Value(previousHtml),
      previousSourceHash: Value(previousSourceHash),
      syncChecks: Value(syncChecks),
    );
  }

  factory NoteWebsiteRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return NoteWebsiteRow(
      noteId: serializer.fromJson<String>(json['noteId']),
      html: serializer.fromJson<String>(json['html']),
      sourceHash: serializer.fromJson<String>(json['sourceHash']),
      brief: serializer.fromJson<String>(json['brief']),
      model: serializer.fromJson<String>(json['model']),
      madeAt: serializer.fromJson<int>(json['madeAt']),
      state: serializer.fromJson<String>(json['state']),
      previousHtml: serializer.fromJson<String>(json['previousHtml']),
      previousSourceHash: serializer.fromJson<String>(
        json['previousSourceHash'],
      ),
      syncChecks: serializer.fromJson<bool>(json['syncChecks']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'noteId': serializer.toJson<String>(noteId),
      'html': serializer.toJson<String>(html),
      'sourceHash': serializer.toJson<String>(sourceHash),
      'brief': serializer.toJson<String>(brief),
      'model': serializer.toJson<String>(model),
      'madeAt': serializer.toJson<int>(madeAt),
      'state': serializer.toJson<String>(state),
      'previousHtml': serializer.toJson<String>(previousHtml),
      'previousSourceHash': serializer.toJson<String>(previousSourceHash),
      'syncChecks': serializer.toJson<bool>(syncChecks),
    };
  }

  NoteWebsiteRow copyWith({
    String? noteId,
    String? html,
    String? sourceHash,
    String? brief,
    String? model,
    int? madeAt,
    String? state,
    String? previousHtml,
    String? previousSourceHash,
    bool? syncChecks,
  }) => NoteWebsiteRow(
    noteId: noteId ?? this.noteId,
    html: html ?? this.html,
    sourceHash: sourceHash ?? this.sourceHash,
    brief: brief ?? this.brief,
    model: model ?? this.model,
    madeAt: madeAt ?? this.madeAt,
    state: state ?? this.state,
    previousHtml: previousHtml ?? this.previousHtml,
    previousSourceHash: previousSourceHash ?? this.previousSourceHash,
    syncChecks: syncChecks ?? this.syncChecks,
  );
  NoteWebsiteRow copyWithCompanion(NoteWebsitesCompanion data) {
    return NoteWebsiteRow(
      noteId: data.noteId.present ? data.noteId.value : this.noteId,
      html: data.html.present ? data.html.value : this.html,
      sourceHash: data.sourceHash.present
          ? data.sourceHash.value
          : this.sourceHash,
      brief: data.brief.present ? data.brief.value : this.brief,
      model: data.model.present ? data.model.value : this.model,
      madeAt: data.madeAt.present ? data.madeAt.value : this.madeAt,
      state: data.state.present ? data.state.value : this.state,
      previousHtml: data.previousHtml.present
          ? data.previousHtml.value
          : this.previousHtml,
      previousSourceHash: data.previousSourceHash.present
          ? data.previousSourceHash.value
          : this.previousSourceHash,
      syncChecks: data.syncChecks.present
          ? data.syncChecks.value
          : this.syncChecks,
    );
  }

  @override
  String toString() {
    return (StringBuffer('NoteWebsiteRow(')
          ..write('noteId: $noteId, ')
          ..write('html: $html, ')
          ..write('sourceHash: $sourceHash, ')
          ..write('brief: $brief, ')
          ..write('model: $model, ')
          ..write('madeAt: $madeAt, ')
          ..write('state: $state, ')
          ..write('previousHtml: $previousHtml, ')
          ..write('previousSourceHash: $previousSourceHash, ')
          ..write('syncChecks: $syncChecks')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    noteId,
    html,
    sourceHash,
    brief,
    model,
    madeAt,
    state,
    previousHtml,
    previousSourceHash,
    syncChecks,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NoteWebsiteRow &&
          other.noteId == this.noteId &&
          other.html == this.html &&
          other.sourceHash == this.sourceHash &&
          other.brief == this.brief &&
          other.model == this.model &&
          other.madeAt == this.madeAt &&
          other.state == this.state &&
          other.previousHtml == this.previousHtml &&
          other.previousSourceHash == this.previousSourceHash &&
          other.syncChecks == this.syncChecks);
}

class NoteWebsitesCompanion extends UpdateCompanion<NoteWebsiteRow> {
  final Value<String> noteId;
  final Value<String> html;
  final Value<String> sourceHash;
  final Value<String> brief;
  final Value<String> model;
  final Value<int> madeAt;
  final Value<String> state;
  final Value<String> previousHtml;
  final Value<String> previousSourceHash;
  final Value<bool> syncChecks;
  final Value<int> rowid;
  const NoteWebsitesCompanion({
    this.noteId = const Value.absent(),
    this.html = const Value.absent(),
    this.sourceHash = const Value.absent(),
    this.brief = const Value.absent(),
    this.model = const Value.absent(),
    this.madeAt = const Value.absent(),
    this.state = const Value.absent(),
    this.previousHtml = const Value.absent(),
    this.previousSourceHash = const Value.absent(),
    this.syncChecks = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  NoteWebsitesCompanion.insert({
    required String noteId,
    required String html,
    required String sourceHash,
    this.brief = const Value.absent(),
    this.model = const Value.absent(),
    required int madeAt,
    this.state = const Value.absent(),
    this.previousHtml = const Value.absent(),
    this.previousSourceHash = const Value.absent(),
    this.syncChecks = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : noteId = Value(noteId),
       html = Value(html),
       sourceHash = Value(sourceHash),
       madeAt = Value(madeAt);
  static Insertable<NoteWebsiteRow> custom({
    Expression<String>? noteId,
    Expression<String>? html,
    Expression<String>? sourceHash,
    Expression<String>? brief,
    Expression<String>? model,
    Expression<int>? madeAt,
    Expression<String>? state,
    Expression<String>? previousHtml,
    Expression<String>? previousSourceHash,
    Expression<bool>? syncChecks,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (noteId != null) 'note_id': noteId,
      if (html != null) 'html': html,
      if (sourceHash != null) 'source_hash': sourceHash,
      if (brief != null) 'brief': brief,
      if (model != null) 'model': model,
      if (madeAt != null) 'made_at': madeAt,
      if (state != null) 'state': state,
      if (previousHtml != null) 'previous_html': previousHtml,
      if (previousSourceHash != null)
        'previous_source_hash': previousSourceHash,
      if (syncChecks != null) 'sync_checks': syncChecks,
      if (rowid != null) 'rowid': rowid,
    });
  }

  NoteWebsitesCompanion copyWith({
    Value<String>? noteId,
    Value<String>? html,
    Value<String>? sourceHash,
    Value<String>? brief,
    Value<String>? model,
    Value<int>? madeAt,
    Value<String>? state,
    Value<String>? previousHtml,
    Value<String>? previousSourceHash,
    Value<bool>? syncChecks,
    Value<int>? rowid,
  }) {
    return NoteWebsitesCompanion(
      noteId: noteId ?? this.noteId,
      html: html ?? this.html,
      sourceHash: sourceHash ?? this.sourceHash,
      brief: brief ?? this.brief,
      model: model ?? this.model,
      madeAt: madeAt ?? this.madeAt,
      state: state ?? this.state,
      previousHtml: previousHtml ?? this.previousHtml,
      previousSourceHash: previousSourceHash ?? this.previousSourceHash,
      syncChecks: syncChecks ?? this.syncChecks,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (noteId.present) {
      map['note_id'] = Variable<String>(noteId.value);
    }
    if (html.present) {
      map['html'] = Variable<String>(html.value);
    }
    if (sourceHash.present) {
      map['source_hash'] = Variable<String>(sourceHash.value);
    }
    if (brief.present) {
      map['brief'] = Variable<String>(brief.value);
    }
    if (model.present) {
      map['model'] = Variable<String>(model.value);
    }
    if (madeAt.present) {
      map['made_at'] = Variable<int>(madeAt.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(state.value);
    }
    if (previousHtml.present) {
      map['previous_html'] = Variable<String>(previousHtml.value);
    }
    if (previousSourceHash.present) {
      map['previous_source_hash'] = Variable<String>(previousSourceHash.value);
    }
    if (syncChecks.present) {
      map['sync_checks'] = Variable<bool>(syncChecks.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NoteWebsitesCompanion(')
          ..write('noteId: $noteId, ')
          ..write('html: $html, ')
          ..write('sourceHash: $sourceHash, ')
          ..write('brief: $brief, ')
          ..write('model: $model, ')
          ..write('madeAt: $madeAt, ')
          ..write('state: $state, ')
          ..write('previousHtml: $previousHtml, ')
          ..write('previousSourceHash: $previousSourceHash, ')
          ..write('syncChecks: $syncChecks, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $NoteChatTurnsTable extends NoteChatTurns
    with TableInfo<$NoteChatTurnsTable, NoteChatTurnRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NoteChatTurnsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _noteIdMeta = const VerificationMeta('noteId');
  @override
  late final GeneratedColumn<String> noteId = GeneratedColumn<String>(
    'note_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _atMeta = const VerificationMeta('at');
  @override
  late final GeneratedColumn<int> at = GeneratedColumn<int>(
    'at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _askMeta = const VerificationMeta('ask');
  @override
  late final GeneratedColumn<String> ask = GeneratedColumn<String>(
    'ask',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _replyMeta = const VerificationMeta('reply');
  @override
  late final GeneratedColumn<String> reply = GeneratedColumn<String>(
    'reply',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _actionsMeta = const VerificationMeta(
    'actions',
  );
  @override
  late final GeneratedColumn<String> actions = GeneratedColumn<String>(
    'actions',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  @override
  List<GeneratedColumn> get $columns => [id, noteId, at, ask, reply, actions];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'note_chat_turns';
  @override
  VerificationContext validateIntegrity(
    Insertable<NoteChatTurnRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('note_id')) {
      context.handle(
        _noteIdMeta,
        noteId.isAcceptableOrUnknown(data['note_id']!, _noteIdMeta),
      );
    } else if (isInserting) {
      context.missing(_noteIdMeta);
    }
    if (data.containsKey('at')) {
      context.handle(_atMeta, at.isAcceptableOrUnknown(data['at']!, _atMeta));
    } else if (isInserting) {
      context.missing(_atMeta);
    }
    if (data.containsKey('ask')) {
      context.handle(
        _askMeta,
        ask.isAcceptableOrUnknown(data['ask']!, _askMeta),
      );
    } else if (isInserting) {
      context.missing(_askMeta);
    }
    if (data.containsKey('reply')) {
      context.handle(
        _replyMeta,
        reply.isAcceptableOrUnknown(data['reply']!, _replyMeta),
      );
    }
    if (data.containsKey('actions')) {
      context.handle(
        _actionsMeta,
        actions.isAcceptableOrUnknown(data['actions']!, _actionsMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  NoteChatTurnRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return NoteChatTurnRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      noteId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note_id'],
      )!,
      at: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}at'],
      )!,
      ask: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ask'],
      )!,
      reply: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reply'],
      )!,
      actions: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}actions'],
      )!,
    );
  }

  @override
  $NoteChatTurnsTable createAlias(String alias) {
    return $NoteChatTurnsTable(attachedDatabase, alias);
  }
}

class NoteChatTurnRow extends DataClass implements Insertable<NoteChatTurnRow> {
  final String id;

  /// Not a reference: a new note can talk before it is first saved.
  final String noteId;
  final int at;
  final String ask;
  final String reply;

  /// The Maester's tool calls and what came of them, as JSON.
  final String actions;
  const NoteChatTurnRow({
    required this.id,
    required this.noteId,
    required this.at,
    required this.ask,
    required this.reply,
    required this.actions,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['note_id'] = Variable<String>(noteId);
    map['at'] = Variable<int>(at);
    map['ask'] = Variable<String>(ask);
    map['reply'] = Variable<String>(reply);
    map['actions'] = Variable<String>(actions);
    return map;
  }

  NoteChatTurnsCompanion toCompanion(bool nullToAbsent) {
    return NoteChatTurnsCompanion(
      id: Value(id),
      noteId: Value(noteId),
      at: Value(at),
      ask: Value(ask),
      reply: Value(reply),
      actions: Value(actions),
    );
  }

  factory NoteChatTurnRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return NoteChatTurnRow(
      id: serializer.fromJson<String>(json['id']),
      noteId: serializer.fromJson<String>(json['noteId']),
      at: serializer.fromJson<int>(json['at']),
      ask: serializer.fromJson<String>(json['ask']),
      reply: serializer.fromJson<String>(json['reply']),
      actions: serializer.fromJson<String>(json['actions']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'noteId': serializer.toJson<String>(noteId),
      'at': serializer.toJson<int>(at),
      'ask': serializer.toJson<String>(ask),
      'reply': serializer.toJson<String>(reply),
      'actions': serializer.toJson<String>(actions),
    };
  }

  NoteChatTurnRow copyWith({
    String? id,
    String? noteId,
    int? at,
    String? ask,
    String? reply,
    String? actions,
  }) => NoteChatTurnRow(
    id: id ?? this.id,
    noteId: noteId ?? this.noteId,
    at: at ?? this.at,
    ask: ask ?? this.ask,
    reply: reply ?? this.reply,
    actions: actions ?? this.actions,
  );
  NoteChatTurnRow copyWithCompanion(NoteChatTurnsCompanion data) {
    return NoteChatTurnRow(
      id: data.id.present ? data.id.value : this.id,
      noteId: data.noteId.present ? data.noteId.value : this.noteId,
      at: data.at.present ? data.at.value : this.at,
      ask: data.ask.present ? data.ask.value : this.ask,
      reply: data.reply.present ? data.reply.value : this.reply,
      actions: data.actions.present ? data.actions.value : this.actions,
    );
  }

  @override
  String toString() {
    return (StringBuffer('NoteChatTurnRow(')
          ..write('id: $id, ')
          ..write('noteId: $noteId, ')
          ..write('at: $at, ')
          ..write('ask: $ask, ')
          ..write('reply: $reply, ')
          ..write('actions: $actions')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, noteId, at, ask, reply, actions);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NoteChatTurnRow &&
          other.id == this.id &&
          other.noteId == this.noteId &&
          other.at == this.at &&
          other.ask == this.ask &&
          other.reply == this.reply &&
          other.actions == this.actions);
}

class NoteChatTurnsCompanion extends UpdateCompanion<NoteChatTurnRow> {
  final Value<String> id;
  final Value<String> noteId;
  final Value<int> at;
  final Value<String> ask;
  final Value<String> reply;
  final Value<String> actions;
  final Value<int> rowid;
  const NoteChatTurnsCompanion({
    this.id = const Value.absent(),
    this.noteId = const Value.absent(),
    this.at = const Value.absent(),
    this.ask = const Value.absent(),
    this.reply = const Value.absent(),
    this.actions = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  NoteChatTurnsCompanion.insert({
    required String id,
    required String noteId,
    required int at,
    required String ask,
    this.reply = const Value.absent(),
    this.actions = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       noteId = Value(noteId),
       at = Value(at),
       ask = Value(ask);
  static Insertable<NoteChatTurnRow> custom({
    Expression<String>? id,
    Expression<String>? noteId,
    Expression<int>? at,
    Expression<String>? ask,
    Expression<String>? reply,
    Expression<String>? actions,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (noteId != null) 'note_id': noteId,
      if (at != null) 'at': at,
      if (ask != null) 'ask': ask,
      if (reply != null) 'reply': reply,
      if (actions != null) 'actions': actions,
      if (rowid != null) 'rowid': rowid,
    });
  }

  NoteChatTurnsCompanion copyWith({
    Value<String>? id,
    Value<String>? noteId,
    Value<int>? at,
    Value<String>? ask,
    Value<String>? reply,
    Value<String>? actions,
    Value<int>? rowid,
  }) {
    return NoteChatTurnsCompanion(
      id: id ?? this.id,
      noteId: noteId ?? this.noteId,
      at: at ?? this.at,
      ask: ask ?? this.ask,
      reply: reply ?? this.reply,
      actions: actions ?? this.actions,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (noteId.present) {
      map['note_id'] = Variable<String>(noteId.value);
    }
    if (at.present) {
      map['at'] = Variable<int>(at.value);
    }
    if (ask.present) {
      map['ask'] = Variable<String>(ask.value);
    }
    if (reply.present) {
      map['reply'] = Variable<String>(reply.value);
    }
    if (actions.present) {
      map['actions'] = Variable<String>(actions.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NoteChatTurnsCompanion(')
          ..write('id: $id, ')
          ..write('noteId: $noteId, ')
          ..write('at: $at, ')
          ..write('ask: $ask, ')
          ..write('reply: $reply, ')
          ..write('actions: $actions, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DiaryEntriesTable extends DiaryEntries
    with TableInfo<$DiaryEntriesTable, DiaryEntryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DiaryEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _periodKeyMeta = const VerificationMeta(
    'periodKey',
  );
  @override
  late final GeneratedColumn<String> periodKey = GeneratedColumn<String>(
    'period_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'body',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _photosMeta = const VerificationMeta('photos');
  @override
  late final GeneratedColumn<String> photos = GeneratedColumn<String>(
    'photos',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
    'revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (revision > 0)',
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('entry'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    periodKey,
    body,
    photos,
    revision,
    createdAt,
    updatedAt,
    deletedAt,
    kind,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'diary_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<DiaryEntryRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('period_key')) {
      context.handle(
        _periodKeyMeta,
        periodKey.isAcceptableOrUnknown(data['period_key']!, _periodKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_periodKeyMeta);
    }
    if (data.containsKey('body')) {
      context.handle(
        _bodyMeta,
        body.isAcceptableOrUnknown(data['body']!, _bodyMeta),
      );
    } else if (isInserting) {
      context.missing(_bodyMeta);
    }
    if (data.containsKey('photos')) {
      context.handle(
        _photosMeta,
        photos.isAcceptableOrUnknown(data['photos']!, _photosMeta),
      );
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
      );
    } else if (isInserting) {
      context.missing(_revisionMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DiaryEntryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DiaryEntryRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      periodKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}period_key'],
      )!,
      body: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body'],
      )!,
      photos: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}photos'],
      )!,
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revision'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
    );
  }

  @override
  $DiaryEntriesTable createAlias(String alias) {
    return $DiaryEntriesTable(attachedDatabase, alias);
  }
}

class DiaryEntryRow extends DataClass implements Insertable<DiaryEntryRow> {
  final String id;
  final String periodKey;
  final String body;
  final String photos;
  final int revision;
  final int createdAt;
  final int updatedAt;
  final int? deletedAt;

  /// A [DiaryEntryKind] name. Added in schema 9.
  final String kind;
  const DiaryEntryRow({
    required this.id,
    required this.periodKey,
    required this.body,
    required this.photos,
    required this.revision,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.kind,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['period_key'] = Variable<String>(periodKey);
    map['body'] = Variable<String>(body);
    map['photos'] = Variable<String>(photos);
    map['revision'] = Variable<int>(revision);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    map['kind'] = Variable<String>(kind);
    return map;
  }

  DiaryEntriesCompanion toCompanion(bool nullToAbsent) {
    return DiaryEntriesCompanion(
      id: Value(id),
      periodKey: Value(periodKey),
      body: Value(body),
      photos: Value(photos),
      revision: Value(revision),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      kind: Value(kind),
    );
  }

  factory DiaryEntryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DiaryEntryRow(
      id: serializer.fromJson<String>(json['id']),
      periodKey: serializer.fromJson<String>(json['periodKey']),
      body: serializer.fromJson<String>(json['body']),
      photos: serializer.fromJson<String>(json['photos']),
      revision: serializer.fromJson<int>(json['revision']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      deletedAt: serializer.fromJson<int?>(json['deletedAt']),
      kind: serializer.fromJson<String>(json['kind']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'periodKey': serializer.toJson<String>(periodKey),
      'body': serializer.toJson<String>(body),
      'photos': serializer.toJson<String>(photos),
      'revision': serializer.toJson<int>(revision),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'deletedAt': serializer.toJson<int?>(deletedAt),
      'kind': serializer.toJson<String>(kind),
    };
  }

  DiaryEntryRow copyWith({
    String? id,
    String? periodKey,
    String? body,
    String? photos,
    int? revision,
    int? createdAt,
    int? updatedAt,
    Value<int?> deletedAt = const Value.absent(),
    String? kind,
  }) => DiaryEntryRow(
    id: id ?? this.id,
    periodKey: periodKey ?? this.periodKey,
    body: body ?? this.body,
    photos: photos ?? this.photos,
    revision: revision ?? this.revision,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    kind: kind ?? this.kind,
  );
  DiaryEntryRow copyWithCompanion(DiaryEntriesCompanion data) {
    return DiaryEntryRow(
      id: data.id.present ? data.id.value : this.id,
      periodKey: data.periodKey.present ? data.periodKey.value : this.periodKey,
      body: data.body.present ? data.body.value : this.body,
      photos: data.photos.present ? data.photos.value : this.photos,
      revision: data.revision.present ? data.revision.value : this.revision,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      kind: data.kind.present ? data.kind.value : this.kind,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DiaryEntryRow(')
          ..write('id: $id, ')
          ..write('periodKey: $periodKey, ')
          ..write('body: $body, ')
          ..write('photos: $photos, ')
          ..write('revision: $revision, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('kind: $kind')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    periodKey,
    body,
    photos,
    revision,
    createdAt,
    updatedAt,
    deletedAt,
    kind,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DiaryEntryRow &&
          other.id == this.id &&
          other.periodKey == this.periodKey &&
          other.body == this.body &&
          other.photos == this.photos &&
          other.revision == this.revision &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.kind == this.kind);
}

class DiaryEntriesCompanion extends UpdateCompanion<DiaryEntryRow> {
  final Value<String> id;
  final Value<String> periodKey;
  final Value<String> body;
  final Value<String> photos;
  final Value<int> revision;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int?> deletedAt;
  final Value<String> kind;
  final Value<int> rowid;
  const DiaryEntriesCompanion({
    this.id = const Value.absent(),
    this.periodKey = const Value.absent(),
    this.body = const Value.absent(),
    this.photos = const Value.absent(),
    this.revision = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.kind = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DiaryEntriesCompanion.insert({
    required String id,
    required String periodKey,
    required String body,
    this.photos = const Value.absent(),
    required int revision,
    required int createdAt,
    required int updatedAt,
    this.deletedAt = const Value.absent(),
    this.kind = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       periodKey = Value(periodKey),
       body = Value(body),
       revision = Value(revision),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<DiaryEntryRow> custom({
    Expression<String>? id,
    Expression<String>? periodKey,
    Expression<String>? body,
    Expression<String>? photos,
    Expression<int>? revision,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? deletedAt,
    Expression<String>? kind,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (periodKey != null) 'period_key': periodKey,
      if (body != null) 'body': body,
      if (photos != null) 'photos': photos,
      if (revision != null) 'revision': revision,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (kind != null) 'kind': kind,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DiaryEntriesCompanion copyWith({
    Value<String>? id,
    Value<String>? periodKey,
    Value<String>? body,
    Value<String>? photos,
    Value<int>? revision,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int?>? deletedAt,
    Value<String>? kind,
    Value<int>? rowid,
  }) {
    return DiaryEntriesCompanion(
      id: id ?? this.id,
      periodKey: periodKey ?? this.periodKey,
      body: body ?? this.body,
      photos: photos ?? this.photos,
      revision: revision ?? this.revision,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      kind: kind ?? this.kind,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (periodKey.present) {
      map['period_key'] = Variable<String>(periodKey.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (photos.present) {
      map['photos'] = Variable<String>(photos.value);
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DiaryEntriesCompanion(')
          ..write('id: $id, ')
          ..write('periodKey: $periodKey, ')
          ..write('body: $body, ')
          ..write('photos: $photos, ')
          ..write('revision: $revision, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('kind: $kind, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DiaryDaysTable extends DiaryDays
    with TableInfo<$DiaryDaysTable, DiaryDayRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DiaryDaysTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _periodKeyMeta = const VerificationMeta(
    'periodKey',
  );
  @override
  late final GeneratedColumn<String> periodKey = GeneratedColumn<String>(
    'period_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _headingMeta = const VerificationMeta(
    'heading',
  );
  @override
  late final GeneratedColumn<String> heading = GeneratedColumn<String>(
    'heading',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(maxTextLength: 160),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _moodMeta = const VerificationMeta('mood');
  @override
  late final GeneratedColumn<String> mood = GeneratedColumn<String>(
    'mood',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _themesMeta = const VerificationMeta('themes');
  @override
  late final GeneratedColumn<String> themes = GeneratedColumn<String>(
    'themes',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
    'revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (revision > 0)',
  );
  @override
  List<GeneratedColumn> get $columns => [
    periodKey,
    heading,
    mood,
    themes,
    revision,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'diary_days';
  @override
  VerificationContext validateIntegrity(
    Insertable<DiaryDayRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('period_key')) {
      context.handle(
        _periodKeyMeta,
        periodKey.isAcceptableOrUnknown(data['period_key']!, _periodKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_periodKeyMeta);
    }
    if (data.containsKey('heading')) {
      context.handle(
        _headingMeta,
        heading.isAcceptableOrUnknown(data['heading']!, _headingMeta),
      );
    } else if (isInserting) {
      context.missing(_headingMeta);
    }
    if (data.containsKey('mood')) {
      context.handle(
        _moodMeta,
        mood.isAcceptableOrUnknown(data['mood']!, _moodMeta),
      );
    }
    if (data.containsKey('themes')) {
      context.handle(
        _themesMeta,
        themes.isAcceptableOrUnknown(data['themes']!, _themesMeta),
      );
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
      );
    } else if (isInserting) {
      context.missing(_revisionMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {periodKey};
  @override
  DiaryDayRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DiaryDayRow(
      periodKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}period_key'],
      )!,
      heading: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}heading'],
      )!,
      mood: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mood'],
      ),
      themes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}themes'],
      )!,
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revision'],
      )!,
    );
  }

  @override
  $DiaryDaysTable createAlias(String alias) {
    return $DiaryDaysTable(attachedDatabase, alias);
  }
}

class DiaryDayRow extends DataClass implements Insertable<DiaryDayRow> {
  final String periodKey;
  final String heading;
  final String? mood;
  final String themes;
  final int revision;
  const DiaryDayRow({
    required this.periodKey,
    required this.heading,
    this.mood,
    required this.themes,
    required this.revision,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['period_key'] = Variable<String>(periodKey);
    map['heading'] = Variable<String>(heading);
    if (!nullToAbsent || mood != null) {
      map['mood'] = Variable<String>(mood);
    }
    map['themes'] = Variable<String>(themes);
    map['revision'] = Variable<int>(revision);
    return map;
  }

  DiaryDaysCompanion toCompanion(bool nullToAbsent) {
    return DiaryDaysCompanion(
      periodKey: Value(periodKey),
      heading: Value(heading),
      mood: mood == null && nullToAbsent ? const Value.absent() : Value(mood),
      themes: Value(themes),
      revision: Value(revision),
    );
  }

  factory DiaryDayRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DiaryDayRow(
      periodKey: serializer.fromJson<String>(json['periodKey']),
      heading: serializer.fromJson<String>(json['heading']),
      mood: serializer.fromJson<String?>(json['mood']),
      themes: serializer.fromJson<String>(json['themes']),
      revision: serializer.fromJson<int>(json['revision']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'periodKey': serializer.toJson<String>(periodKey),
      'heading': serializer.toJson<String>(heading),
      'mood': serializer.toJson<String?>(mood),
      'themes': serializer.toJson<String>(themes),
      'revision': serializer.toJson<int>(revision),
    };
  }

  DiaryDayRow copyWith({
    String? periodKey,
    String? heading,
    Value<String?> mood = const Value.absent(),
    String? themes,
    int? revision,
  }) => DiaryDayRow(
    periodKey: periodKey ?? this.periodKey,
    heading: heading ?? this.heading,
    mood: mood.present ? mood.value : this.mood,
    themes: themes ?? this.themes,
    revision: revision ?? this.revision,
  );
  DiaryDayRow copyWithCompanion(DiaryDaysCompanion data) {
    return DiaryDayRow(
      periodKey: data.periodKey.present ? data.periodKey.value : this.periodKey,
      heading: data.heading.present ? data.heading.value : this.heading,
      mood: data.mood.present ? data.mood.value : this.mood,
      themes: data.themes.present ? data.themes.value : this.themes,
      revision: data.revision.present ? data.revision.value : this.revision,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DiaryDayRow(')
          ..write('periodKey: $periodKey, ')
          ..write('heading: $heading, ')
          ..write('mood: $mood, ')
          ..write('themes: $themes, ')
          ..write('revision: $revision')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(periodKey, heading, mood, themes, revision);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DiaryDayRow &&
          other.periodKey == this.periodKey &&
          other.heading == this.heading &&
          other.mood == this.mood &&
          other.themes == this.themes &&
          other.revision == this.revision);
}

class DiaryDaysCompanion extends UpdateCompanion<DiaryDayRow> {
  final Value<String> periodKey;
  final Value<String> heading;
  final Value<String?> mood;
  final Value<String> themes;
  final Value<int> revision;
  final Value<int> rowid;
  const DiaryDaysCompanion({
    this.periodKey = const Value.absent(),
    this.heading = const Value.absent(),
    this.mood = const Value.absent(),
    this.themes = const Value.absent(),
    this.revision = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DiaryDaysCompanion.insert({
    required String periodKey,
    required String heading,
    this.mood = const Value.absent(),
    this.themes = const Value.absent(),
    required int revision,
    this.rowid = const Value.absent(),
  }) : periodKey = Value(periodKey),
       heading = Value(heading),
       revision = Value(revision);
  static Insertable<DiaryDayRow> custom({
    Expression<String>? periodKey,
    Expression<String>? heading,
    Expression<String>? mood,
    Expression<String>? themes,
    Expression<int>? revision,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (periodKey != null) 'period_key': periodKey,
      if (heading != null) 'heading': heading,
      if (mood != null) 'mood': mood,
      if (themes != null) 'themes': themes,
      if (revision != null) 'revision': revision,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DiaryDaysCompanion copyWith({
    Value<String>? periodKey,
    Value<String>? heading,
    Value<String?>? mood,
    Value<String>? themes,
    Value<int>? revision,
    Value<int>? rowid,
  }) {
    return DiaryDaysCompanion(
      periodKey: periodKey ?? this.periodKey,
      heading: heading ?? this.heading,
      mood: mood ?? this.mood,
      themes: themes ?? this.themes,
      revision: revision ?? this.revision,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (periodKey.present) {
      map['period_key'] = Variable<String>(periodKey.value);
    }
    if (heading.present) {
      map['heading'] = Variable<String>(heading.value);
    }
    if (mood.present) {
      map['mood'] = Variable<String>(mood.value);
    }
    if (themes.present) {
      map['themes'] = Variable<String>(themes.value);
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DiaryDaysCompanion(')
          ..write('periodKey: $periodKey, ')
          ..write('heading: $heading, ')
          ..write('mood: $mood, ')
          ..write('themes: $themes, ')
          ..write('revision: $revision, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DiaryMediaOpsTable extends DiaryMediaOps
    with TableInfo<$DiaryMediaOpsTable, DiaryMediaOpRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DiaryMediaOpsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
    'path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _actionMeta = const VerificationMeta('action');
  @override
  late final GeneratedColumn<String> action = GeneratedColumn<String>(
    'action',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ownerMeta = const VerificationMeta('owner');
  @override
  late final GeneratedColumn<String> owner = GeneratedColumn<String>(
    'owner',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdMeta = const VerificationMeta(
    'created',
  );
  @override
  late final GeneratedColumn<int> created = GeneratedColumn<int>(
    'created',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [path, action, owner, created];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'diary_media_ops';
  @override
  VerificationContext validateIntegrity(
    Insertable<DiaryMediaOpRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('path')) {
      context.handle(
        _pathMeta,
        path.isAcceptableOrUnknown(data['path']!, _pathMeta),
      );
    } else if (isInserting) {
      context.missing(_pathMeta);
    }
    if (data.containsKey('action')) {
      context.handle(
        _actionMeta,
        action.isAcceptableOrUnknown(data['action']!, _actionMeta),
      );
    } else if (isInserting) {
      context.missing(_actionMeta);
    }
    if (data.containsKey('owner')) {
      context.handle(
        _ownerMeta,
        owner.isAcceptableOrUnknown(data['owner']!, _ownerMeta),
      );
    } else if (isInserting) {
      context.missing(_ownerMeta);
    }
    if (data.containsKey('created')) {
      context.handle(
        _createdMeta,
        created.isAcceptableOrUnknown(data['created']!, _createdMeta),
      );
    } else if (isInserting) {
      context.missing(_createdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {path};
  @override
  DiaryMediaOpRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DiaryMediaOpRow(
      path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path'],
      )!,
      action: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}action'],
      )!,
      owner: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner'],
      )!,
      created: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created'],
      )!,
    );
  }

  @override
  $DiaryMediaOpsTable createAlias(String alias) {
    return $DiaryMediaOpsTable(attachedDatabase, alias);
  }
}

class DiaryMediaOpRow extends DataClass implements Insertable<DiaryMediaOpRow> {
  final String path;
  final String action;
  final String owner;
  final int created;
  const DiaryMediaOpRow({
    required this.path,
    required this.action,
    required this.owner,
    required this.created,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['path'] = Variable<String>(path);
    map['action'] = Variable<String>(action);
    map['owner'] = Variable<String>(owner);
    map['created'] = Variable<int>(created);
    return map;
  }

  DiaryMediaOpsCompanion toCompanion(bool nullToAbsent) {
    return DiaryMediaOpsCompanion(
      path: Value(path),
      action: Value(action),
      owner: Value(owner),
      created: Value(created),
    );
  }

  factory DiaryMediaOpRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DiaryMediaOpRow(
      path: serializer.fromJson<String>(json['path']),
      action: serializer.fromJson<String>(json['action']),
      owner: serializer.fromJson<String>(json['owner']),
      created: serializer.fromJson<int>(json['created']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'path': serializer.toJson<String>(path),
      'action': serializer.toJson<String>(action),
      'owner': serializer.toJson<String>(owner),
      'created': serializer.toJson<int>(created),
    };
  }

  DiaryMediaOpRow copyWith({
    String? path,
    String? action,
    String? owner,
    int? created,
  }) => DiaryMediaOpRow(
    path: path ?? this.path,
    action: action ?? this.action,
    owner: owner ?? this.owner,
    created: created ?? this.created,
  );
  DiaryMediaOpRow copyWithCompanion(DiaryMediaOpsCompanion data) {
    return DiaryMediaOpRow(
      path: data.path.present ? data.path.value : this.path,
      action: data.action.present ? data.action.value : this.action,
      owner: data.owner.present ? data.owner.value : this.owner,
      created: data.created.present ? data.created.value : this.created,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DiaryMediaOpRow(')
          ..write('path: $path, ')
          ..write('action: $action, ')
          ..write('owner: $owner, ')
          ..write('created: $created')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(path, action, owner, created);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DiaryMediaOpRow &&
          other.path == this.path &&
          other.action == this.action &&
          other.owner == this.owner &&
          other.created == this.created);
}

class DiaryMediaOpsCompanion extends UpdateCompanion<DiaryMediaOpRow> {
  final Value<String> path;
  final Value<String> action;
  final Value<String> owner;
  final Value<int> created;
  final Value<int> rowid;
  const DiaryMediaOpsCompanion({
    this.path = const Value.absent(),
    this.action = const Value.absent(),
    this.owner = const Value.absent(),
    this.created = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DiaryMediaOpsCompanion.insert({
    required String path,
    required String action,
    required String owner,
    required int created,
    this.rowid = const Value.absent(),
  }) : path = Value(path),
       action = Value(action),
       owner = Value(owner),
       created = Value(created);
  static Insertable<DiaryMediaOpRow> custom({
    Expression<String>? path,
    Expression<String>? action,
    Expression<String>? owner,
    Expression<int>? created,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (path != null) 'path': path,
      if (action != null) 'action': action,
      if (owner != null) 'owner': owner,
      if (created != null) 'created': created,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DiaryMediaOpsCompanion copyWith({
    Value<String>? path,
    Value<String>? action,
    Value<String>? owner,
    Value<int>? created,
    Value<int>? rowid,
  }) {
    return DiaryMediaOpsCompanion(
      path: path ?? this.path,
      action: action ?? this.action,
      owner: owner ?? this.owner,
      created: created ?? this.created,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (action.present) {
      map['action'] = Variable<String>(action.value);
    }
    if (owner.present) {
      map['owner'] = Variable<String>(owner.value);
    }
    if (created.present) {
      map['created'] = Variable<int>(created.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DiaryMediaOpsCompanion(')
          ..write('path: $path, ')
          ..write('action: $action, ')
          ..write('owner: $owner, ')
          ..write('created: $created, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DiarySearchHistoryTable extends DiarySearchHistory
    with TableInfo<$DiarySearchHistoryTable, DiarySearchHistoryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DiarySearchHistoryTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _queryMeta = const VerificationMeta('query');
  @override
  late final GeneratedColumn<String> query = GeneratedColumn<String>(
    'query',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sequenceMeta = const VerificationMeta(
    'sequence',
  );
  @override
  late final GeneratedColumn<int> sequence = GeneratedColumn<int>(
    'sequence',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [query, sequence];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'diary_search_history';
  @override
  VerificationContext validateIntegrity(
    Insertable<DiarySearchHistoryRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('query')) {
      context.handle(
        _queryMeta,
        query.isAcceptableOrUnknown(data['query']!, _queryMeta),
      );
    } else if (isInserting) {
      context.missing(_queryMeta);
    }
    if (data.containsKey('sequence')) {
      context.handle(
        _sequenceMeta,
        sequence.isAcceptableOrUnknown(data['sequence']!, _sequenceMeta),
      );
    } else if (isInserting) {
      context.missing(_sequenceMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {query};
  @override
  DiarySearchHistoryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DiarySearchHistoryRow(
      query: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}query'],
      )!,
      sequence: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sequence'],
      )!,
    );
  }

  @override
  $DiarySearchHistoryTable createAlias(String alias) {
    return $DiarySearchHistoryTable(attachedDatabase, alias);
  }
}

class DiarySearchHistoryRow extends DataClass
    implements Insertable<DiarySearchHistoryRow> {
  final String query;

  /// Higher is more recent.
  final int sequence;
  const DiarySearchHistoryRow({required this.query, required this.sequence});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['query'] = Variable<String>(query);
    map['sequence'] = Variable<int>(sequence);
    return map;
  }

  DiarySearchHistoryCompanion toCompanion(bool nullToAbsent) {
    return DiarySearchHistoryCompanion(
      query: Value(query),
      sequence: Value(sequence),
    );
  }

  factory DiarySearchHistoryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DiarySearchHistoryRow(
      query: serializer.fromJson<String>(json['query']),
      sequence: serializer.fromJson<int>(json['sequence']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'query': serializer.toJson<String>(query),
      'sequence': serializer.toJson<int>(sequence),
    };
  }

  DiarySearchHistoryRow copyWith({String? query, int? sequence}) =>
      DiarySearchHistoryRow(
        query: query ?? this.query,
        sequence: sequence ?? this.sequence,
      );
  DiarySearchHistoryRow copyWithCompanion(DiarySearchHistoryCompanion data) {
    return DiarySearchHistoryRow(
      query: data.query.present ? data.query.value : this.query,
      sequence: data.sequence.present ? data.sequence.value : this.sequence,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DiarySearchHistoryRow(')
          ..write('query: $query, ')
          ..write('sequence: $sequence')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(query, sequence);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DiarySearchHistoryRow &&
          other.query == this.query &&
          other.sequence == this.sequence);
}

class DiarySearchHistoryCompanion
    extends UpdateCompanion<DiarySearchHistoryRow> {
  final Value<String> query;
  final Value<int> sequence;
  final Value<int> rowid;
  const DiarySearchHistoryCompanion({
    this.query = const Value.absent(),
    this.sequence = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DiarySearchHistoryCompanion.insert({
    required String query,
    required int sequence,
    this.rowid = const Value.absent(),
  }) : query = Value(query),
       sequence = Value(sequence);
  static Insertable<DiarySearchHistoryRow> custom({
    Expression<String>? query,
    Expression<int>? sequence,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (query != null) 'query': query,
      if (sequence != null) 'sequence': sequence,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DiarySearchHistoryCompanion copyWith({
    Value<String>? query,
    Value<int>? sequence,
    Value<int>? rowid,
  }) {
    return DiarySearchHistoryCompanion(
      query: query ?? this.query,
      sequence: sequence ?? this.sequence,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (query.present) {
      map['query'] = Variable<String>(query.value);
    }
    if (sequence.present) {
      map['sequence'] = Variable<int>(sequence.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DiarySearchHistoryCompanion(')
          ..write('query: $query, ')
          ..write('sequence: $sequence, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WatchCatalogTable extends WatchCatalog
    with TableInfo<$WatchCatalogTable, WatchCatalogRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WatchCatalogTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _mediaKeyMeta = const VerificationMeta(
    'mediaKey',
  );
  @override
  late final GeneratedColumn<String> mediaKey = GeneratedColumn<String>(
    'media_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dataMeta = const VerificationMeta('data');
  @override
  late final GeneratedColumn<String> data = GeneratedColumn<String>(
    'data',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _seasonsMeta = const VerificationMeta(
    'seasons',
  );
  @override
  late final GeneratedColumn<String> seasons = GeneratedColumn<String>(
    'seasons',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  static const VerificationMeta _detailedMeta = const VerificationMeta(
    'detailed',
  );
  @override
  late final GeneratedColumn<bool> detailed = GeneratedColumn<bool>(
    'detailed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("detailed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _popularityMeta = const VerificationMeta(
    'popularity',
  );
  @override
  late final GeneratedColumn<double> popularity = GeneratedColumn<double>(
    'popularity',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _fetchedAtMeta = const VerificationMeta(
    'fetchedAt',
  );
  @override
  late final GeneratedColumn<int> fetchedAt = GeneratedColumn<int>(
    'fetched_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    mediaKey,
    data,
    seasons,
    detailed,
    popularity,
    fetchedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'watch_catalog';
  @override
  VerificationContext validateIntegrity(
    Insertable<WatchCatalogRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('media_key')) {
      context.handle(
        _mediaKeyMeta,
        mediaKey.isAcceptableOrUnknown(data['media_key']!, _mediaKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_mediaKeyMeta);
    }
    if (data.containsKey('data')) {
      context.handle(
        _dataMeta,
        this.data.isAcceptableOrUnknown(data['data']!, _dataMeta),
      );
    } else if (isInserting) {
      context.missing(_dataMeta);
    }
    if (data.containsKey('seasons')) {
      context.handle(
        _seasonsMeta,
        seasons.isAcceptableOrUnknown(data['seasons']!, _seasonsMeta),
      );
    }
    if (data.containsKey('detailed')) {
      context.handle(
        _detailedMeta,
        detailed.isAcceptableOrUnknown(data['detailed']!, _detailedMeta),
      );
    }
    if (data.containsKey('popularity')) {
      context.handle(
        _popularityMeta,
        popularity.isAcceptableOrUnknown(data['popularity']!, _popularityMeta),
      );
    }
    if (data.containsKey('fetched_at')) {
      context.handle(
        _fetchedAtMeta,
        fetchedAt.isAcceptableOrUnknown(data['fetched_at']!, _fetchedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_fetchedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {mediaKey};
  @override
  WatchCatalogRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WatchCatalogRow(
      mediaKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}media_key'],
      )!,
      data: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}data'],
      )!,
      seasons: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}seasons'],
      )!,
      detailed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}detailed'],
      )!,
      popularity: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}popularity'],
      )!,
      fetchedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}fetched_at'],
      )!,
    );
  }

  @override
  $WatchCatalogTable createAlias(String alias) {
    return $WatchCatalogTable(attachedDatabase, alias);
  }
}

class WatchCatalogRow extends DataClass implements Insertable<WatchCatalogRow> {
  final String mediaKey;

  /// [CatalogTitle.toJson].
  final String data;

  /// Fetched seasons of a show, `{"1": [episodes...]}`.
  final String seasons;
  final bool detailed;
  final double popularity;
  final int fetchedAt;
  const WatchCatalogRow({
    required this.mediaKey,
    required this.data,
    required this.seasons,
    required this.detailed,
    required this.popularity,
    required this.fetchedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['media_key'] = Variable<String>(mediaKey);
    map['data'] = Variable<String>(data);
    map['seasons'] = Variable<String>(seasons);
    map['detailed'] = Variable<bool>(detailed);
    map['popularity'] = Variable<double>(popularity);
    map['fetched_at'] = Variable<int>(fetchedAt);
    return map;
  }

  WatchCatalogCompanion toCompanion(bool nullToAbsent) {
    return WatchCatalogCompanion(
      mediaKey: Value(mediaKey),
      data: Value(data),
      seasons: Value(seasons),
      detailed: Value(detailed),
      popularity: Value(popularity),
      fetchedAt: Value(fetchedAt),
    );
  }

  factory WatchCatalogRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WatchCatalogRow(
      mediaKey: serializer.fromJson<String>(json['mediaKey']),
      data: serializer.fromJson<String>(json['data']),
      seasons: serializer.fromJson<String>(json['seasons']),
      detailed: serializer.fromJson<bool>(json['detailed']),
      popularity: serializer.fromJson<double>(json['popularity']),
      fetchedAt: serializer.fromJson<int>(json['fetchedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'mediaKey': serializer.toJson<String>(mediaKey),
      'data': serializer.toJson<String>(data),
      'seasons': serializer.toJson<String>(seasons),
      'detailed': serializer.toJson<bool>(detailed),
      'popularity': serializer.toJson<double>(popularity),
      'fetchedAt': serializer.toJson<int>(fetchedAt),
    };
  }

  WatchCatalogRow copyWith({
    String? mediaKey,
    String? data,
    String? seasons,
    bool? detailed,
    double? popularity,
    int? fetchedAt,
  }) => WatchCatalogRow(
    mediaKey: mediaKey ?? this.mediaKey,
    data: data ?? this.data,
    seasons: seasons ?? this.seasons,
    detailed: detailed ?? this.detailed,
    popularity: popularity ?? this.popularity,
    fetchedAt: fetchedAt ?? this.fetchedAt,
  );
  WatchCatalogRow copyWithCompanion(WatchCatalogCompanion data) {
    return WatchCatalogRow(
      mediaKey: data.mediaKey.present ? data.mediaKey.value : this.mediaKey,
      data: data.data.present ? data.data.value : this.data,
      seasons: data.seasons.present ? data.seasons.value : this.seasons,
      detailed: data.detailed.present ? data.detailed.value : this.detailed,
      popularity: data.popularity.present
          ? data.popularity.value
          : this.popularity,
      fetchedAt: data.fetchedAt.present ? data.fetchedAt.value : this.fetchedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WatchCatalogRow(')
          ..write('mediaKey: $mediaKey, ')
          ..write('data: $data, ')
          ..write('seasons: $seasons, ')
          ..write('detailed: $detailed, ')
          ..write('popularity: $popularity, ')
          ..write('fetchedAt: $fetchedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(mediaKey, data, seasons, detailed, popularity, fetchedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WatchCatalogRow &&
          other.mediaKey == this.mediaKey &&
          other.data == this.data &&
          other.seasons == this.seasons &&
          other.detailed == this.detailed &&
          other.popularity == this.popularity &&
          other.fetchedAt == this.fetchedAt);
}

class WatchCatalogCompanion extends UpdateCompanion<WatchCatalogRow> {
  final Value<String> mediaKey;
  final Value<String> data;
  final Value<String> seasons;
  final Value<bool> detailed;
  final Value<double> popularity;
  final Value<int> fetchedAt;
  final Value<int> rowid;
  const WatchCatalogCompanion({
    this.mediaKey = const Value.absent(),
    this.data = const Value.absent(),
    this.seasons = const Value.absent(),
    this.detailed = const Value.absent(),
    this.popularity = const Value.absent(),
    this.fetchedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WatchCatalogCompanion.insert({
    required String mediaKey,
    required String data,
    this.seasons = const Value.absent(),
    this.detailed = const Value.absent(),
    this.popularity = const Value.absent(),
    required int fetchedAt,
    this.rowid = const Value.absent(),
  }) : mediaKey = Value(mediaKey),
       data = Value(data),
       fetchedAt = Value(fetchedAt);
  static Insertable<WatchCatalogRow> custom({
    Expression<String>? mediaKey,
    Expression<String>? data,
    Expression<String>? seasons,
    Expression<bool>? detailed,
    Expression<double>? popularity,
    Expression<int>? fetchedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (mediaKey != null) 'media_key': mediaKey,
      if (data != null) 'data': data,
      if (seasons != null) 'seasons': seasons,
      if (detailed != null) 'detailed': detailed,
      if (popularity != null) 'popularity': popularity,
      if (fetchedAt != null) 'fetched_at': fetchedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WatchCatalogCompanion copyWith({
    Value<String>? mediaKey,
    Value<String>? data,
    Value<String>? seasons,
    Value<bool>? detailed,
    Value<double>? popularity,
    Value<int>? fetchedAt,
    Value<int>? rowid,
  }) {
    return WatchCatalogCompanion(
      mediaKey: mediaKey ?? this.mediaKey,
      data: data ?? this.data,
      seasons: seasons ?? this.seasons,
      detailed: detailed ?? this.detailed,
      popularity: popularity ?? this.popularity,
      fetchedAt: fetchedAt ?? this.fetchedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (mediaKey.present) {
      map['media_key'] = Variable<String>(mediaKey.value);
    }
    if (data.present) {
      map['data'] = Variable<String>(data.value);
    }
    if (seasons.present) {
      map['seasons'] = Variable<String>(seasons.value);
    }
    if (detailed.present) {
      map['detailed'] = Variable<bool>(detailed.value);
    }
    if (popularity.present) {
      map['popularity'] = Variable<double>(popularity.value);
    }
    if (fetchedAt.present) {
      map['fetched_at'] = Variable<int>(fetchedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WatchCatalogCompanion(')
          ..write('mediaKey: $mediaKey, ')
          ..write('data: $data, ')
          ..write('seasons: $seasons, ')
          ..write('detailed: $detailed, ')
          ..write('popularity: $popularity, ')
          ..write('fetchedAt: $fetchedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WatchTitlesTable extends WatchTitles
    with TableInfo<$WatchTitlesTable, WatchTitleRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WatchTitlesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mediaKeyMeta = const VerificationMeta(
    'mediaKey',
  );
  @override
  late final GeneratedColumn<String> mediaKey = GeneratedColumn<String>(
    'media_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _posterPathMeta = const VerificationMeta(
    'posterPath',
  );
  @override
  late final GeneratedColumn<String> posterPath = GeneratedColumn<String>(
    'poster_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _yearMeta = const VerificationMeta('year');
  @override
  late final GeneratedColumn<int> year = GeneratedColumn<int>(
    'year',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ratingMeta = const VerificationMeta('rating');
  @override
  late final GeneratedColumn<int> rating = GeneratedColumn<int>(
    'rating',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _swipeMeta = const VerificationMeta('swipe');
  @override
  late final GeneratedColumn<String> swipe = GeneratedColumn<String>(
    'swipe',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _matchStateMeta = const VerificationMeta(
    'matchState',
  );
  @override
  late final GeneratedColumn<String> matchState = GeneratedColumn<String>(
    'match_state',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _matchedAtMeta = const VerificationMeta(
    'matchedAt',
  );
  @override
  late final GeneratedColumn<int> matchedAt = GeneratedColumn<int>(
    'matched_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _expiresAtMeta = const VerificationMeta(
    'expiresAt',
  );
  @override
  late final GeneratedColumn<int> expiresAt = GeneratedColumn<int>(
    'expires_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nightAtMeta = const VerificationMeta(
    'nightAt',
  );
  @override
  late final GeneratedColumn<int> nightAt = GeneratedColumn<int>(
    'night_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _outcomeMeta = const VerificationMeta(
    'outcome',
  );
  @override
  late final GeneratedColumn<String> outcome = GeneratedColumn<String>(
    'outcome',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _checkedInAtMeta = const VerificationMeta(
    'checkedInAt',
  );
  @override
  late final GeneratedColumn<int> checkedInAt = GeneratedColumn<int>(
    'checked_in_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _episodesMeta = const VerificationMeta(
    'episodes',
  );
  @override
  late final GeneratedColumn<String> episodes = GeneratedColumn<String>(
    'episodes',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
    'revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (revision > 0)',
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    mediaKey,
    title,
    posterPath,
    year,
    status,
    rating,
    note,
    swipe,
    matchState,
    matchedAt,
    expiresAt,
    nightAt,
    outcome,
    checkedInAt,
    episodes,
    revision,
    createdAt,
    updatedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'watch_titles';
  @override
  VerificationContext validateIntegrity(
    Insertable<WatchTitleRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('media_key')) {
      context.handle(
        _mediaKeyMeta,
        mediaKey.isAcceptableOrUnknown(data['media_key']!, _mediaKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_mediaKeyMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('poster_path')) {
      context.handle(
        _posterPathMeta,
        posterPath.isAcceptableOrUnknown(data['poster_path']!, _posterPathMeta),
      );
    }
    if (data.containsKey('year')) {
      context.handle(
        _yearMeta,
        year.isAcceptableOrUnknown(data['year']!, _yearMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('rating')) {
      context.handle(
        _ratingMeta,
        rating.isAcceptableOrUnknown(data['rating']!, _ratingMeta),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('swipe')) {
      context.handle(
        _swipeMeta,
        swipe.isAcceptableOrUnknown(data['swipe']!, _swipeMeta),
      );
    }
    if (data.containsKey('match_state')) {
      context.handle(
        _matchStateMeta,
        matchState.isAcceptableOrUnknown(data['match_state']!, _matchStateMeta),
      );
    }
    if (data.containsKey('matched_at')) {
      context.handle(
        _matchedAtMeta,
        matchedAt.isAcceptableOrUnknown(data['matched_at']!, _matchedAtMeta),
      );
    }
    if (data.containsKey('expires_at')) {
      context.handle(
        _expiresAtMeta,
        expiresAt.isAcceptableOrUnknown(data['expires_at']!, _expiresAtMeta),
      );
    }
    if (data.containsKey('night_at')) {
      context.handle(
        _nightAtMeta,
        nightAt.isAcceptableOrUnknown(data['night_at']!, _nightAtMeta),
      );
    }
    if (data.containsKey('outcome')) {
      context.handle(
        _outcomeMeta,
        outcome.isAcceptableOrUnknown(data['outcome']!, _outcomeMeta),
      );
    }
    if (data.containsKey('checked_in_at')) {
      context.handle(
        _checkedInAtMeta,
        checkedInAt.isAcceptableOrUnknown(
          data['checked_in_at']!,
          _checkedInAtMeta,
        ),
      );
    }
    if (data.containsKey('episodes')) {
      context.handle(
        _episodesMeta,
        episodes.isAcceptableOrUnknown(data['episodes']!, _episodesMeta),
      );
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
      );
    } else if (isInserting) {
      context.missing(_revisionMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WatchTitleRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WatchTitleRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      mediaKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}media_key'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      posterPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}poster_path'],
      ),
      year: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}year'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      ),
      rating: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}rating'],
      ),
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      )!,
      swipe: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}swipe'],
      ),
      matchState: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}match_state'],
      ),
      matchedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}matched_at'],
      ),
      expiresAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}expires_at'],
      ),
      nightAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}night_at'],
      ),
      outcome: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}outcome'],
      ),
      checkedInAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}checked_in_at'],
      ),
      episodes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}episodes'],
      )!,
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revision'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $WatchTitlesTable createAlias(String alias) {
    return $WatchTitlesTable(attachedDatabase, alias);
  }
}

class WatchTitleRow extends DataClass implements Insertable<WatchTitleRow> {
  final String id;
  final String mediaKey;
  final String title;
  final String? posterPath;
  final int? year;
  final String? status;
  final int? rating;
  final String note;
  final String? swipe;
  final String? matchState;
  final int? matchedAt;
  final int? expiresAt;
  final int? nightAt;
  final String? outcome;
  final int? checkedInAt;

  /// Watched episodes as a JSON array of `s1e4` codes.
  final String episodes;
  final int revision;
  final int createdAt;
  final int updatedAt;
  final int? deletedAt;
  const WatchTitleRow({
    required this.id,
    required this.mediaKey,
    required this.title,
    this.posterPath,
    this.year,
    this.status,
    this.rating,
    required this.note,
    this.swipe,
    this.matchState,
    this.matchedAt,
    this.expiresAt,
    this.nightAt,
    this.outcome,
    this.checkedInAt,
    required this.episodes,
    required this.revision,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['media_key'] = Variable<String>(mediaKey);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || posterPath != null) {
      map['poster_path'] = Variable<String>(posterPath);
    }
    if (!nullToAbsent || year != null) {
      map['year'] = Variable<int>(year);
    }
    if (!nullToAbsent || status != null) {
      map['status'] = Variable<String>(status);
    }
    if (!nullToAbsent || rating != null) {
      map['rating'] = Variable<int>(rating);
    }
    map['note'] = Variable<String>(note);
    if (!nullToAbsent || swipe != null) {
      map['swipe'] = Variable<String>(swipe);
    }
    if (!nullToAbsent || matchState != null) {
      map['match_state'] = Variable<String>(matchState);
    }
    if (!nullToAbsent || matchedAt != null) {
      map['matched_at'] = Variable<int>(matchedAt);
    }
    if (!nullToAbsent || expiresAt != null) {
      map['expires_at'] = Variable<int>(expiresAt);
    }
    if (!nullToAbsent || nightAt != null) {
      map['night_at'] = Variable<int>(nightAt);
    }
    if (!nullToAbsent || outcome != null) {
      map['outcome'] = Variable<String>(outcome);
    }
    if (!nullToAbsent || checkedInAt != null) {
      map['checked_in_at'] = Variable<int>(checkedInAt);
    }
    map['episodes'] = Variable<String>(episodes);
    map['revision'] = Variable<int>(revision);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    return map;
  }

  WatchTitlesCompanion toCompanion(bool nullToAbsent) {
    return WatchTitlesCompanion(
      id: Value(id),
      mediaKey: Value(mediaKey),
      title: Value(title),
      posterPath: posterPath == null && nullToAbsent
          ? const Value.absent()
          : Value(posterPath),
      year: year == null && nullToAbsent ? const Value.absent() : Value(year),
      status: status == null && nullToAbsent
          ? const Value.absent()
          : Value(status),
      rating: rating == null && nullToAbsent
          ? const Value.absent()
          : Value(rating),
      note: Value(note),
      swipe: swipe == null && nullToAbsent
          ? const Value.absent()
          : Value(swipe),
      matchState: matchState == null && nullToAbsent
          ? const Value.absent()
          : Value(matchState),
      matchedAt: matchedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(matchedAt),
      expiresAt: expiresAt == null && nullToAbsent
          ? const Value.absent()
          : Value(expiresAt),
      nightAt: nightAt == null && nullToAbsent
          ? const Value.absent()
          : Value(nightAt),
      outcome: outcome == null && nullToAbsent
          ? const Value.absent()
          : Value(outcome),
      checkedInAt: checkedInAt == null && nullToAbsent
          ? const Value.absent()
          : Value(checkedInAt),
      episodes: Value(episodes),
      revision: Value(revision),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory WatchTitleRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WatchTitleRow(
      id: serializer.fromJson<String>(json['id']),
      mediaKey: serializer.fromJson<String>(json['mediaKey']),
      title: serializer.fromJson<String>(json['title']),
      posterPath: serializer.fromJson<String?>(json['posterPath']),
      year: serializer.fromJson<int?>(json['year']),
      status: serializer.fromJson<String?>(json['status']),
      rating: serializer.fromJson<int?>(json['rating']),
      note: serializer.fromJson<String>(json['note']),
      swipe: serializer.fromJson<String?>(json['swipe']),
      matchState: serializer.fromJson<String?>(json['matchState']),
      matchedAt: serializer.fromJson<int?>(json['matchedAt']),
      expiresAt: serializer.fromJson<int?>(json['expiresAt']),
      nightAt: serializer.fromJson<int?>(json['nightAt']),
      outcome: serializer.fromJson<String?>(json['outcome']),
      checkedInAt: serializer.fromJson<int?>(json['checkedInAt']),
      episodes: serializer.fromJson<String>(json['episodes']),
      revision: serializer.fromJson<int>(json['revision']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      deletedAt: serializer.fromJson<int?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'mediaKey': serializer.toJson<String>(mediaKey),
      'title': serializer.toJson<String>(title),
      'posterPath': serializer.toJson<String?>(posterPath),
      'year': serializer.toJson<int?>(year),
      'status': serializer.toJson<String?>(status),
      'rating': serializer.toJson<int?>(rating),
      'note': serializer.toJson<String>(note),
      'swipe': serializer.toJson<String?>(swipe),
      'matchState': serializer.toJson<String?>(matchState),
      'matchedAt': serializer.toJson<int?>(matchedAt),
      'expiresAt': serializer.toJson<int?>(expiresAt),
      'nightAt': serializer.toJson<int?>(nightAt),
      'outcome': serializer.toJson<String?>(outcome),
      'checkedInAt': serializer.toJson<int?>(checkedInAt),
      'episodes': serializer.toJson<String>(episodes),
      'revision': serializer.toJson<int>(revision),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'deletedAt': serializer.toJson<int?>(deletedAt),
    };
  }

  WatchTitleRow copyWith({
    String? id,
    String? mediaKey,
    String? title,
    Value<String?> posterPath = const Value.absent(),
    Value<int?> year = const Value.absent(),
    Value<String?> status = const Value.absent(),
    Value<int?> rating = const Value.absent(),
    String? note,
    Value<String?> swipe = const Value.absent(),
    Value<String?> matchState = const Value.absent(),
    Value<int?> matchedAt = const Value.absent(),
    Value<int?> expiresAt = const Value.absent(),
    Value<int?> nightAt = const Value.absent(),
    Value<String?> outcome = const Value.absent(),
    Value<int?> checkedInAt = const Value.absent(),
    String? episodes,
    int? revision,
    int? createdAt,
    int? updatedAt,
    Value<int?> deletedAt = const Value.absent(),
  }) => WatchTitleRow(
    id: id ?? this.id,
    mediaKey: mediaKey ?? this.mediaKey,
    title: title ?? this.title,
    posterPath: posterPath.present ? posterPath.value : this.posterPath,
    year: year.present ? year.value : this.year,
    status: status.present ? status.value : this.status,
    rating: rating.present ? rating.value : this.rating,
    note: note ?? this.note,
    swipe: swipe.present ? swipe.value : this.swipe,
    matchState: matchState.present ? matchState.value : this.matchState,
    matchedAt: matchedAt.present ? matchedAt.value : this.matchedAt,
    expiresAt: expiresAt.present ? expiresAt.value : this.expiresAt,
    nightAt: nightAt.present ? nightAt.value : this.nightAt,
    outcome: outcome.present ? outcome.value : this.outcome,
    checkedInAt: checkedInAt.present ? checkedInAt.value : this.checkedInAt,
    episodes: episodes ?? this.episodes,
    revision: revision ?? this.revision,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  WatchTitleRow copyWithCompanion(WatchTitlesCompanion data) {
    return WatchTitleRow(
      id: data.id.present ? data.id.value : this.id,
      mediaKey: data.mediaKey.present ? data.mediaKey.value : this.mediaKey,
      title: data.title.present ? data.title.value : this.title,
      posterPath: data.posterPath.present
          ? data.posterPath.value
          : this.posterPath,
      year: data.year.present ? data.year.value : this.year,
      status: data.status.present ? data.status.value : this.status,
      rating: data.rating.present ? data.rating.value : this.rating,
      note: data.note.present ? data.note.value : this.note,
      swipe: data.swipe.present ? data.swipe.value : this.swipe,
      matchState: data.matchState.present
          ? data.matchState.value
          : this.matchState,
      matchedAt: data.matchedAt.present ? data.matchedAt.value : this.matchedAt,
      expiresAt: data.expiresAt.present ? data.expiresAt.value : this.expiresAt,
      nightAt: data.nightAt.present ? data.nightAt.value : this.nightAt,
      outcome: data.outcome.present ? data.outcome.value : this.outcome,
      checkedInAt: data.checkedInAt.present
          ? data.checkedInAt.value
          : this.checkedInAt,
      episodes: data.episodes.present ? data.episodes.value : this.episodes,
      revision: data.revision.present ? data.revision.value : this.revision,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WatchTitleRow(')
          ..write('id: $id, ')
          ..write('mediaKey: $mediaKey, ')
          ..write('title: $title, ')
          ..write('posterPath: $posterPath, ')
          ..write('year: $year, ')
          ..write('status: $status, ')
          ..write('rating: $rating, ')
          ..write('note: $note, ')
          ..write('swipe: $swipe, ')
          ..write('matchState: $matchState, ')
          ..write('matchedAt: $matchedAt, ')
          ..write('expiresAt: $expiresAt, ')
          ..write('nightAt: $nightAt, ')
          ..write('outcome: $outcome, ')
          ..write('checkedInAt: $checkedInAt, ')
          ..write('episodes: $episodes, ')
          ..write('revision: $revision, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    mediaKey,
    title,
    posterPath,
    year,
    status,
    rating,
    note,
    swipe,
    matchState,
    matchedAt,
    expiresAt,
    nightAt,
    outcome,
    checkedInAt,
    episodes,
    revision,
    createdAt,
    updatedAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WatchTitleRow &&
          other.id == this.id &&
          other.mediaKey == this.mediaKey &&
          other.title == this.title &&
          other.posterPath == this.posterPath &&
          other.year == this.year &&
          other.status == this.status &&
          other.rating == this.rating &&
          other.note == this.note &&
          other.swipe == this.swipe &&
          other.matchState == this.matchState &&
          other.matchedAt == this.matchedAt &&
          other.expiresAt == this.expiresAt &&
          other.nightAt == this.nightAt &&
          other.outcome == this.outcome &&
          other.checkedInAt == this.checkedInAt &&
          other.episodes == this.episodes &&
          other.revision == this.revision &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class WatchTitlesCompanion extends UpdateCompanion<WatchTitleRow> {
  final Value<String> id;
  final Value<String> mediaKey;
  final Value<String> title;
  final Value<String?> posterPath;
  final Value<int?> year;
  final Value<String?> status;
  final Value<int?> rating;
  final Value<String> note;
  final Value<String?> swipe;
  final Value<String?> matchState;
  final Value<int?> matchedAt;
  final Value<int?> expiresAt;
  final Value<int?> nightAt;
  final Value<String?> outcome;
  final Value<int?> checkedInAt;
  final Value<String> episodes;
  final Value<int> revision;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int?> deletedAt;
  final Value<int> rowid;
  const WatchTitlesCompanion({
    this.id = const Value.absent(),
    this.mediaKey = const Value.absent(),
    this.title = const Value.absent(),
    this.posterPath = const Value.absent(),
    this.year = const Value.absent(),
    this.status = const Value.absent(),
    this.rating = const Value.absent(),
    this.note = const Value.absent(),
    this.swipe = const Value.absent(),
    this.matchState = const Value.absent(),
    this.matchedAt = const Value.absent(),
    this.expiresAt = const Value.absent(),
    this.nightAt = const Value.absent(),
    this.outcome = const Value.absent(),
    this.checkedInAt = const Value.absent(),
    this.episodes = const Value.absent(),
    this.revision = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WatchTitlesCompanion.insert({
    required String id,
    required String mediaKey,
    required String title,
    this.posterPath = const Value.absent(),
    this.year = const Value.absent(),
    this.status = const Value.absent(),
    this.rating = const Value.absent(),
    this.note = const Value.absent(),
    this.swipe = const Value.absent(),
    this.matchState = const Value.absent(),
    this.matchedAt = const Value.absent(),
    this.expiresAt = const Value.absent(),
    this.nightAt = const Value.absent(),
    this.outcome = const Value.absent(),
    this.checkedInAt = const Value.absent(),
    this.episodes = const Value.absent(),
    required int revision,
    required int createdAt,
    required int updatedAt,
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       mediaKey = Value(mediaKey),
       title = Value(title),
       revision = Value(revision),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<WatchTitleRow> custom({
    Expression<String>? id,
    Expression<String>? mediaKey,
    Expression<String>? title,
    Expression<String>? posterPath,
    Expression<int>? year,
    Expression<String>? status,
    Expression<int>? rating,
    Expression<String>? note,
    Expression<String>? swipe,
    Expression<String>? matchState,
    Expression<int>? matchedAt,
    Expression<int>? expiresAt,
    Expression<int>? nightAt,
    Expression<String>? outcome,
    Expression<int>? checkedInAt,
    Expression<String>? episodes,
    Expression<int>? revision,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (mediaKey != null) 'media_key': mediaKey,
      if (title != null) 'title': title,
      if (posterPath != null) 'poster_path': posterPath,
      if (year != null) 'year': year,
      if (status != null) 'status': status,
      if (rating != null) 'rating': rating,
      if (note != null) 'note': note,
      if (swipe != null) 'swipe': swipe,
      if (matchState != null) 'match_state': matchState,
      if (matchedAt != null) 'matched_at': matchedAt,
      if (expiresAt != null) 'expires_at': expiresAt,
      if (nightAt != null) 'night_at': nightAt,
      if (outcome != null) 'outcome': outcome,
      if (checkedInAt != null) 'checked_in_at': checkedInAt,
      if (episodes != null) 'episodes': episodes,
      if (revision != null) 'revision': revision,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WatchTitlesCompanion copyWith({
    Value<String>? id,
    Value<String>? mediaKey,
    Value<String>? title,
    Value<String?>? posterPath,
    Value<int?>? year,
    Value<String?>? status,
    Value<int?>? rating,
    Value<String>? note,
    Value<String?>? swipe,
    Value<String?>? matchState,
    Value<int?>? matchedAt,
    Value<int?>? expiresAt,
    Value<int?>? nightAt,
    Value<String?>? outcome,
    Value<int?>? checkedInAt,
    Value<String>? episodes,
    Value<int>? revision,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int?>? deletedAt,
    Value<int>? rowid,
  }) {
    return WatchTitlesCompanion(
      id: id ?? this.id,
      mediaKey: mediaKey ?? this.mediaKey,
      title: title ?? this.title,
      posterPath: posterPath ?? this.posterPath,
      year: year ?? this.year,
      status: status ?? this.status,
      rating: rating ?? this.rating,
      note: note ?? this.note,
      swipe: swipe ?? this.swipe,
      matchState: matchState ?? this.matchState,
      matchedAt: matchedAt ?? this.matchedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      nightAt: nightAt ?? this.nightAt,
      outcome: outcome ?? this.outcome,
      checkedInAt: checkedInAt ?? this.checkedInAt,
      episodes: episodes ?? this.episodes,
      revision: revision ?? this.revision,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (mediaKey.present) {
      map['media_key'] = Variable<String>(mediaKey.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (posterPath.present) {
      map['poster_path'] = Variable<String>(posterPath.value);
    }
    if (year.present) {
      map['year'] = Variable<int>(year.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (rating.present) {
      map['rating'] = Variable<int>(rating.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (swipe.present) {
      map['swipe'] = Variable<String>(swipe.value);
    }
    if (matchState.present) {
      map['match_state'] = Variable<String>(matchState.value);
    }
    if (matchedAt.present) {
      map['matched_at'] = Variable<int>(matchedAt.value);
    }
    if (expiresAt.present) {
      map['expires_at'] = Variable<int>(expiresAt.value);
    }
    if (nightAt.present) {
      map['night_at'] = Variable<int>(nightAt.value);
    }
    if (outcome.present) {
      map['outcome'] = Variable<String>(outcome.value);
    }
    if (checkedInAt.present) {
      map['checked_in_at'] = Variable<int>(checkedInAt.value);
    }
    if (episodes.present) {
      map['episodes'] = Variable<String>(episodes.value);
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WatchTitlesCompanion(')
          ..write('id: $id, ')
          ..write('mediaKey: $mediaKey, ')
          ..write('title: $title, ')
          ..write('posterPath: $posterPath, ')
          ..write('year: $year, ')
          ..write('status: $status, ')
          ..write('rating: $rating, ')
          ..write('note: $note, ')
          ..write('swipe: $swipe, ')
          ..write('matchState: $matchState, ')
          ..write('matchedAt: $matchedAt, ')
          ..write('expiresAt: $expiresAt, ')
          ..write('nightAt: $nightAt, ')
          ..write('outcome: $outcome, ')
          ..write('checkedInAt: $checkedInAt, ')
          ..write('episodes: $episodes, ')
          ..write('revision: $revision, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WatchListsTable extends WatchLists
    with TableInfo<$WatchListsTable, WatchListRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WatchListsTable(this.attachedDatabase, [this._alias]);
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
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _itemsMeta = const VerificationMeta('items');
  @override
  late final GeneratedColumn<String> items = GeneratedColumn<String>(
    'items',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
    'revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (revision > 0)',
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    items,
    revision,
    createdAt,
    updatedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'watch_lists';
  @override
  VerificationContext validateIntegrity(
    Insertable<WatchListRow> instance, {
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
    if (data.containsKey('items')) {
      context.handle(
        _itemsMeta,
        items.isAcceptableOrUnknown(data['items']!, _itemsMeta),
      );
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
      );
    } else if (isInserting) {
      context.missing(_revisionMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WatchListRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WatchListRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      items: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}items'],
      )!,
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revision'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $WatchListsTable createAlias(String alias) {
    return $WatchListsTable(attachedDatabase, alias);
  }
}

class WatchListRow extends DataClass implements Insertable<WatchListRow> {
  final String id;
  final String name;

  /// JSON array of title ids, newest first.
  final String items;
  final int revision;
  final int createdAt;
  final int updatedAt;
  final int? deletedAt;
  const WatchListRow({
    required this.id,
    required this.name,
    required this.items,
    required this.revision,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['items'] = Variable<String>(items);
    map['revision'] = Variable<int>(revision);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    return map;
  }

  WatchListsCompanion toCompanion(bool nullToAbsent) {
    return WatchListsCompanion(
      id: Value(id),
      name: Value(name),
      items: Value(items),
      revision: Value(revision),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory WatchListRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WatchListRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      items: serializer.fromJson<String>(json['items']),
      revision: serializer.fromJson<int>(json['revision']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      deletedAt: serializer.fromJson<int?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'items': serializer.toJson<String>(items),
      'revision': serializer.toJson<int>(revision),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'deletedAt': serializer.toJson<int?>(deletedAt),
    };
  }

  WatchListRow copyWith({
    String? id,
    String? name,
    String? items,
    int? revision,
    int? createdAt,
    int? updatedAt,
    Value<int?> deletedAt = const Value.absent(),
  }) => WatchListRow(
    id: id ?? this.id,
    name: name ?? this.name,
    items: items ?? this.items,
    revision: revision ?? this.revision,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  WatchListRow copyWithCompanion(WatchListsCompanion data) {
    return WatchListRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      items: data.items.present ? data.items.value : this.items,
      revision: data.revision.present ? data.revision.value : this.revision,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WatchListRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('items: $items, ')
          ..write('revision: $revision, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, items, revision, createdAt, updatedAt, deletedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WatchListRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.items == this.items &&
          other.revision == this.revision &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class WatchListsCompanion extends UpdateCompanion<WatchListRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> items;
  final Value<int> revision;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int?> deletedAt;
  final Value<int> rowid;
  const WatchListsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.items = const Value.absent(),
    this.revision = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WatchListsCompanion.insert({
    required String id,
    required String name,
    this.items = const Value.absent(),
    required int revision,
    required int createdAt,
    required int updatedAt,
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       revision = Value(revision),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<WatchListRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? items,
    Expression<int>? revision,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (items != null) 'items': items,
      if (revision != null) 'revision': revision,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WatchListsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? items,
    Value<int>? revision,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int?>? deletedAt,
    Value<int>? rowid,
  }) {
    return WatchListsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      items: items ?? this.items,
      revision: revision ?? this.revision,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
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
    if (items.present) {
      map['items'] = Variable<String>(items.value);
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WatchListsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('items: $items, ')
          ..write('revision: $revision, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WatchProfilesTable extends WatchProfiles
    with TableInfo<$WatchProfilesTable, WatchProfileRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WatchProfilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _stateMeta = const VerificationMeta('state');
  @override
  late final GeneratedColumn<String> state = GeneratedColumn<String>(
    'state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
    'revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (revision > 0)',
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    state,
    revision,
    createdAt,
    updatedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'watch_profiles';
  @override
  VerificationContext validateIntegrity(
    Insertable<WatchProfileRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('state')) {
      context.handle(
        _stateMeta,
        state.isAcceptableOrUnknown(data['state']!, _stateMeta),
      );
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
      );
    } else if (isInserting) {
      context.missing(_revisionMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WatchProfileRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WatchProfileRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      state: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}state'],
      )!,
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revision'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $WatchProfilesTable createAlias(String alias) {
    return $WatchProfilesTable(attachedDatabase, alias);
  }
}

class WatchProfileRow extends DataClass implements Insertable<WatchProfileRow> {
  final String id;
  final String state;
  final int revision;
  final int createdAt;
  final int updatedAt;
  final int? deletedAt;
  const WatchProfileRow({
    required this.id,
    required this.state,
    required this.revision,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['state'] = Variable<String>(state);
    map['revision'] = Variable<int>(revision);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    return map;
  }

  WatchProfilesCompanion toCompanion(bool nullToAbsent) {
    return WatchProfilesCompanion(
      id: Value(id),
      state: Value(state),
      revision: Value(revision),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory WatchProfileRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WatchProfileRow(
      id: serializer.fromJson<String>(json['id']),
      state: serializer.fromJson<String>(json['state']),
      revision: serializer.fromJson<int>(json['revision']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      deletedAt: serializer.fromJson<int?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'state': serializer.toJson<String>(state),
      'revision': serializer.toJson<int>(revision),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'deletedAt': serializer.toJson<int?>(deletedAt),
    };
  }

  WatchProfileRow copyWith({
    String? id,
    String? state,
    int? revision,
    int? createdAt,
    int? updatedAt,
    Value<int?> deletedAt = const Value.absent(),
  }) => WatchProfileRow(
    id: id ?? this.id,
    state: state ?? this.state,
    revision: revision ?? this.revision,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  WatchProfileRow copyWithCompanion(WatchProfilesCompanion data) {
    return WatchProfileRow(
      id: data.id.present ? data.id.value : this.id,
      state: data.state.present ? data.state.value : this.state,
      revision: data.revision.present ? data.revision.value : this.revision,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WatchProfileRow(')
          ..write('id: $id, ')
          ..write('state: $state, ')
          ..write('revision: $revision, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, state, revision, createdAt, updatedAt, deletedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WatchProfileRow &&
          other.id == this.id &&
          other.state == this.state &&
          other.revision == this.revision &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class WatchProfilesCompanion extends UpdateCompanion<WatchProfileRow> {
  final Value<String> id;
  final Value<String> state;
  final Value<int> revision;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int?> deletedAt;
  final Value<int> rowid;
  const WatchProfilesCompanion({
    this.id = const Value.absent(),
    this.state = const Value.absent(),
    this.revision = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WatchProfilesCompanion.insert({
    required String id,
    this.state = const Value.absent(),
    required int revision,
    required int createdAt,
    required int updatedAt,
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       revision = Value(revision),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<WatchProfileRow> custom({
    Expression<String>? id,
    Expression<String>? state,
    Expression<int>? revision,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (state != null) 'state': state,
      if (revision != null) 'revision': revision,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WatchProfilesCompanion copyWith({
    Value<String>? id,
    Value<String>? state,
    Value<int>? revision,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int?>? deletedAt,
    Value<int>? rowid,
  }) {
    return WatchProfilesCompanion(
      id: id ?? this.id,
      state: state ?? this.state,
      revision: revision ?? this.revision,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(state.value);
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WatchProfilesCompanion(')
          ..write('id: $id, ')
          ..write('state: $state, ')
          ..write('revision: $revision, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WatchChatTurnsTable extends WatchChatTurns
    with TableInfo<$WatchChatTurnsTable, WatchChatTurnRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WatchChatTurnsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleIdMeta = const VerificationMeta(
    'titleId',
  );
  @override
  late final GeneratedColumn<String> titleId = GeneratedColumn<String>(
    'title_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _atMeta = const VerificationMeta('at');
  @override
  late final GeneratedColumn<int> at = GeneratedColumn<int>(
    'at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fromReaderMeta = const VerificationMeta(
    'fromReader',
  );
  @override
  late final GeneratedColumn<bool> fromReader = GeneratedColumn<bool>(
    'from_reader',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("from_reader" IN (0, 1))',
    ),
  );
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'body',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, titleId, at, fromReader, body];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'watch_chat_turns';
  @override
  VerificationContext validateIntegrity(
    Insertable<WatchChatTurnRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title_id')) {
      context.handle(
        _titleIdMeta,
        titleId.isAcceptableOrUnknown(data['title_id']!, _titleIdMeta),
      );
    } else if (isInserting) {
      context.missing(_titleIdMeta);
    }
    if (data.containsKey('at')) {
      context.handle(_atMeta, at.isAcceptableOrUnknown(data['at']!, _atMeta));
    } else if (isInserting) {
      context.missing(_atMeta);
    }
    if (data.containsKey('from_reader')) {
      context.handle(
        _fromReaderMeta,
        fromReader.isAcceptableOrUnknown(data['from_reader']!, _fromReaderMeta),
      );
    } else if (isInserting) {
      context.missing(_fromReaderMeta);
    }
    if (data.containsKey('body')) {
      context.handle(
        _bodyMeta,
        body.isAcceptableOrUnknown(data['body']!, _bodyMeta),
      );
    } else if (isInserting) {
      context.missing(_bodyMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WatchChatTurnRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WatchChatTurnRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      titleId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title_id'],
      )!,
      at: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}at'],
      )!,
      fromReader: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}from_reader'],
      )!,
      body: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body'],
      )!,
    );
  }

  @override
  $WatchChatTurnsTable createAlias(String alias) {
    return $WatchChatTurnsTable(attachedDatabase, alias);
  }
}

class WatchChatTurnRow extends DataClass
    implements Insertable<WatchChatTurnRow> {
  final String id;
  final String titleId;
  final int at;
  final bool fromReader;
  final String body;
  const WatchChatTurnRow({
    required this.id,
    required this.titleId,
    required this.at,
    required this.fromReader,
    required this.body,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title_id'] = Variable<String>(titleId);
    map['at'] = Variable<int>(at);
    map['from_reader'] = Variable<bool>(fromReader);
    map['body'] = Variable<String>(body);
    return map;
  }

  WatchChatTurnsCompanion toCompanion(bool nullToAbsent) {
    return WatchChatTurnsCompanion(
      id: Value(id),
      titleId: Value(titleId),
      at: Value(at),
      fromReader: Value(fromReader),
      body: Value(body),
    );
  }

  factory WatchChatTurnRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WatchChatTurnRow(
      id: serializer.fromJson<String>(json['id']),
      titleId: serializer.fromJson<String>(json['titleId']),
      at: serializer.fromJson<int>(json['at']),
      fromReader: serializer.fromJson<bool>(json['fromReader']),
      body: serializer.fromJson<String>(json['body']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'titleId': serializer.toJson<String>(titleId),
      'at': serializer.toJson<int>(at),
      'fromReader': serializer.toJson<bool>(fromReader),
      'body': serializer.toJson<String>(body),
    };
  }

  WatchChatTurnRow copyWith({
    String? id,
    String? titleId,
    int? at,
    bool? fromReader,
    String? body,
  }) => WatchChatTurnRow(
    id: id ?? this.id,
    titleId: titleId ?? this.titleId,
    at: at ?? this.at,
    fromReader: fromReader ?? this.fromReader,
    body: body ?? this.body,
  );
  WatchChatTurnRow copyWithCompanion(WatchChatTurnsCompanion data) {
    return WatchChatTurnRow(
      id: data.id.present ? data.id.value : this.id,
      titleId: data.titleId.present ? data.titleId.value : this.titleId,
      at: data.at.present ? data.at.value : this.at,
      fromReader: data.fromReader.present
          ? data.fromReader.value
          : this.fromReader,
      body: data.body.present ? data.body.value : this.body,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WatchChatTurnRow(')
          ..write('id: $id, ')
          ..write('titleId: $titleId, ')
          ..write('at: $at, ')
          ..write('fromReader: $fromReader, ')
          ..write('body: $body')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, titleId, at, fromReader, body);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WatchChatTurnRow &&
          other.id == this.id &&
          other.titleId == this.titleId &&
          other.at == this.at &&
          other.fromReader == this.fromReader &&
          other.body == this.body);
}

class WatchChatTurnsCompanion extends UpdateCompanion<WatchChatTurnRow> {
  final Value<String> id;
  final Value<String> titleId;
  final Value<int> at;
  final Value<bool> fromReader;
  final Value<String> body;
  final Value<int> rowid;
  const WatchChatTurnsCompanion({
    this.id = const Value.absent(),
    this.titleId = const Value.absent(),
    this.at = const Value.absent(),
    this.fromReader = const Value.absent(),
    this.body = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WatchChatTurnsCompanion.insert({
    required String id,
    required String titleId,
    required int at,
    required bool fromReader,
    required String body,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       titleId = Value(titleId),
       at = Value(at),
       fromReader = Value(fromReader),
       body = Value(body);
  static Insertable<WatchChatTurnRow> custom({
    Expression<String>? id,
    Expression<String>? titleId,
    Expression<int>? at,
    Expression<bool>? fromReader,
    Expression<String>? body,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (titleId != null) 'title_id': titleId,
      if (at != null) 'at': at,
      if (fromReader != null) 'from_reader': fromReader,
      if (body != null) 'body': body,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WatchChatTurnsCompanion copyWith({
    Value<String>? id,
    Value<String>? titleId,
    Value<int>? at,
    Value<bool>? fromReader,
    Value<String>? body,
    Value<int>? rowid,
  }) {
    return WatchChatTurnsCompanion(
      id: id ?? this.id,
      titleId: titleId ?? this.titleId,
      at: at ?? this.at,
      fromReader: fromReader ?? this.fromReader,
      body: body ?? this.body,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (titleId.present) {
      map['title_id'] = Variable<String>(titleId.value);
    }
    if (at.present) {
      map['at'] = Variable<int>(at.value);
    }
    if (fromReader.present) {
      map['from_reader'] = Variable<bool>(fromReader.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WatchChatTurnsCompanion(')
          ..write('id: $id, ')
          ..write('titleId: $titleId, ')
          ..write('at: $at, ')
          ..write('fromReader: $fromReader, ')
          ..write('body: $body, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $AiUsageMonthsTable aiUsageMonths = $AiUsageMonthsTable(this);
  late final $AppearanceSettingsTable appearanceSettings =
      $AppearanceSettingsTable(this);
  late final $OnboardingCompletionTable onboardingCompletion =
      $OnboardingCompletionTable(this);
  late final $NotesTable notes = $NotesTable(this);
  late final $NoteTagsTable noteTags = $NoteTagsTable(this);
  late final $NoteMediaOpsTable noteMediaOps = $NoteMediaOpsTable(this);
  late final $NoteWebsitesTable noteWebsites = $NoteWebsitesTable(this);
  late final $NoteChatTurnsTable noteChatTurns = $NoteChatTurnsTable(this);
  late final $DiaryEntriesTable diaryEntries = $DiaryEntriesTable(this);
  late final $DiaryDaysTable diaryDays = $DiaryDaysTable(this);
  late final $DiaryMediaOpsTable diaryMediaOps = $DiaryMediaOpsTable(this);
  late final $DiarySearchHistoryTable diarySearchHistory =
      $DiarySearchHistoryTable(this);
  late final $WatchCatalogTable watchCatalog = $WatchCatalogTable(this);
  late final $WatchTitlesTable watchTitles = $WatchTitlesTable(this);
  late final $WatchListsTable watchLists = $WatchListsTable(this);
  late final $WatchProfilesTable watchProfiles = $WatchProfilesTable(this);
  late final $WatchChatTurnsTable watchChatTurns = $WatchChatTurnsTable(this);
  late final Index diaryEntriesDayOrder = Index(
    'diary_entries_day_order',
    'CREATE INDEX diary_entries_day_order ON diary_entries (period_key, created_at, id)',
  );
  late final Index watchTitlesOrder = Index(
    'watch_titles_order',
    'CREATE INDEX watch_titles_order ON watch_titles (updated_at DESC, id DESC)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    aiUsageMonths,
    appearanceSettings,
    onboardingCompletion,
    notes,
    noteTags,
    noteMediaOps,
    noteWebsites,
    noteChatTurns,
    diaryEntries,
    diaryDays,
    diaryMediaOps,
    diarySearchHistory,
    watchCatalog,
    watchTitles,
    watchLists,
    watchProfiles,
    watchChatTurns,
    diaryEntriesDayOrder,
    watchTitlesOrder,
  ];
}

typedef $$AiUsageMonthsTableCreateCompanionBuilder =
    AiUsageMonthsCompanion Function({
      required String month,
      Value<int> costMicros,
      Value<int> inputTokens,
      Value<int> outputTokens,
      Value<int> rowid,
    });
typedef $$AiUsageMonthsTableUpdateCompanionBuilder =
    AiUsageMonthsCompanion Function({
      Value<String> month,
      Value<int> costMicros,
      Value<int> inputTokens,
      Value<int> outputTokens,
      Value<int> rowid,
    });

class $$AiUsageMonthsTableFilterComposer
    extends Composer<_$AppDatabase, $AiUsageMonthsTable> {
  $$AiUsageMonthsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get month => $composableBuilder(
    column: $table.month,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get costMicros => $composableBuilder(
    column: $table.costMicros,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get inputTokens => $composableBuilder(
    column: $table.inputTokens,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get outputTokens => $composableBuilder(
    column: $table.outputTokens,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AiUsageMonthsTableOrderingComposer
    extends Composer<_$AppDatabase, $AiUsageMonthsTable> {
  $$AiUsageMonthsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get month => $composableBuilder(
    column: $table.month,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get costMicros => $composableBuilder(
    column: $table.costMicros,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get inputTokens => $composableBuilder(
    column: $table.inputTokens,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get outputTokens => $composableBuilder(
    column: $table.outputTokens,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AiUsageMonthsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AiUsageMonthsTable> {
  $$AiUsageMonthsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get month =>
      $composableBuilder(column: $table.month, builder: (column) => column);

  GeneratedColumn<int> get costMicros => $composableBuilder(
    column: $table.costMicros,
    builder: (column) => column,
  );

  GeneratedColumn<int> get inputTokens => $composableBuilder(
    column: $table.inputTokens,
    builder: (column) => column,
  );

  GeneratedColumn<int> get outputTokens => $composableBuilder(
    column: $table.outputTokens,
    builder: (column) => column,
  );
}

class $$AiUsageMonthsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AiUsageMonthsTable,
          AiUsageMonthRow,
          $$AiUsageMonthsTableFilterComposer,
          $$AiUsageMonthsTableOrderingComposer,
          $$AiUsageMonthsTableAnnotationComposer,
          $$AiUsageMonthsTableCreateCompanionBuilder,
          $$AiUsageMonthsTableUpdateCompanionBuilder,
          (
            AiUsageMonthRow,
            BaseReferences<_$AppDatabase, $AiUsageMonthsTable, AiUsageMonthRow>,
          ),
          AiUsageMonthRow,
          PrefetchHooks Function()
        > {
  $$AiUsageMonthsTableTableManager(_$AppDatabase db, $AiUsageMonthsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AiUsageMonthsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AiUsageMonthsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AiUsageMonthsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> month = const Value.absent(),
                Value<int> costMicros = const Value.absent(),
                Value<int> inputTokens = const Value.absent(),
                Value<int> outputTokens = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AiUsageMonthsCompanion(
                month: month,
                costMicros: costMicros,
                inputTokens: inputTokens,
                outputTokens: outputTokens,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String month,
                Value<int> costMicros = const Value.absent(),
                Value<int> inputTokens = const Value.absent(),
                Value<int> outputTokens = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AiUsageMonthsCompanion.insert(
                month: month,
                costMicros: costMicros,
                inputTokens: inputTokens,
                outputTokens: outputTokens,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AiUsageMonthsTable, AiUsageMonthRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $AiUsageMonthsTable,
                    AiUsageMonthRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AiUsageMonthsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AiUsageMonthsTable,
      AiUsageMonthRow,
      $$AiUsageMonthsTableFilterComposer,
      $$AiUsageMonthsTableOrderingComposer,
      $$AiUsageMonthsTableAnnotationComposer,
      $$AiUsageMonthsTableCreateCompanionBuilder,
      $$AiUsageMonthsTableUpdateCompanionBuilder,
      (
        AiUsageMonthRow,
        BaseReferences<_$AppDatabase, $AiUsageMonthsTable, AiUsageMonthRow>,
      ),
      AiUsageMonthRow,
      PrefetchHooks Function()
    >;
typedef $$AppearanceSettingsTableCreateCompanionBuilder =
    AppearanceSettingsCompanion Function({
      Value<int> id,
      Value<String> theme,
      Value<String> accent,
      Value<String> fontFamily,
      Value<String> diaryTitleFontFamily,
      Value<String> diaryBodyFontFamily,
      Value<bool> reduceMotion,
      Value<bool> simplerEffects,
    });
typedef $$AppearanceSettingsTableUpdateCompanionBuilder =
    AppearanceSettingsCompanion Function({
      Value<int> id,
      Value<String> theme,
      Value<String> accent,
      Value<String> fontFamily,
      Value<String> diaryTitleFontFamily,
      Value<String> diaryBodyFontFamily,
      Value<bool> reduceMotion,
      Value<bool> simplerEffects,
    });

class $$AppearanceSettingsTableFilterComposer
    extends Composer<_$AppDatabase, $AppearanceSettingsTable> {
  $$AppearanceSettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get theme => $composableBuilder(
    column: $table.theme,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get accent => $composableBuilder(
    column: $table.accent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fontFamily => $composableBuilder(
    column: $table.fontFamily,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get diaryTitleFontFamily => $composableBuilder(
    column: $table.diaryTitleFontFamily,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get diaryBodyFontFamily => $composableBuilder(
    column: $table.diaryBodyFontFamily,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get reduceMotion => $composableBuilder(
    column: $table.reduceMotion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get simplerEffects => $composableBuilder(
    column: $table.simplerEffects,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AppearanceSettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $AppearanceSettingsTable> {
  $$AppearanceSettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get theme => $composableBuilder(
    column: $table.theme,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get accent => $composableBuilder(
    column: $table.accent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fontFamily => $composableBuilder(
    column: $table.fontFamily,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get diaryTitleFontFamily => $composableBuilder(
    column: $table.diaryTitleFontFamily,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get diaryBodyFontFamily => $composableBuilder(
    column: $table.diaryBodyFontFamily,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get reduceMotion => $composableBuilder(
    column: $table.reduceMotion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get simplerEffects => $composableBuilder(
    column: $table.simplerEffects,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AppearanceSettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AppearanceSettingsTable> {
  $$AppearanceSettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get theme =>
      $composableBuilder(column: $table.theme, builder: (column) => column);

  GeneratedColumn<String> get accent =>
      $composableBuilder(column: $table.accent, builder: (column) => column);

  GeneratedColumn<String> get fontFamily => $composableBuilder(
    column: $table.fontFamily,
    builder: (column) => column,
  );

  GeneratedColumn<String> get diaryTitleFontFamily => $composableBuilder(
    column: $table.diaryTitleFontFamily,
    builder: (column) => column,
  );

  GeneratedColumn<String> get diaryBodyFontFamily => $composableBuilder(
    column: $table.diaryBodyFontFamily,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get reduceMotion => $composableBuilder(
    column: $table.reduceMotion,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get simplerEffects => $composableBuilder(
    column: $table.simplerEffects,
    builder: (column) => column,
  );
}

class $$AppearanceSettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AppearanceSettingsTable,
          AppearanceRow,
          $$AppearanceSettingsTableFilterComposer,
          $$AppearanceSettingsTableOrderingComposer,
          $$AppearanceSettingsTableAnnotationComposer,
          $$AppearanceSettingsTableCreateCompanionBuilder,
          $$AppearanceSettingsTableUpdateCompanionBuilder,
          (
            AppearanceRow,
            BaseReferences<
              _$AppDatabase,
              $AppearanceSettingsTable,
              AppearanceRow
            >,
          ),
          AppearanceRow,
          PrefetchHooks Function()
        > {
  $$AppearanceSettingsTableTableManager(
    _$AppDatabase db,
    $AppearanceSettingsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppearanceSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppearanceSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppearanceSettingsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> theme = const Value.absent(),
                Value<String> accent = const Value.absent(),
                Value<String> fontFamily = const Value.absent(),
                Value<String> diaryTitleFontFamily = const Value.absent(),
                Value<String> diaryBodyFontFamily = const Value.absent(),
                Value<bool> reduceMotion = const Value.absent(),
                Value<bool> simplerEffects = const Value.absent(),
              }) => AppearanceSettingsCompanion(
                id: id,
                theme: theme,
                accent: accent,
                fontFamily: fontFamily,
                diaryTitleFontFamily: diaryTitleFontFamily,
                diaryBodyFontFamily: diaryBodyFontFamily,
                reduceMotion: reduceMotion,
                simplerEffects: simplerEffects,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> theme = const Value.absent(),
                Value<String> accent = const Value.absent(),
                Value<String> fontFamily = const Value.absent(),
                Value<String> diaryTitleFontFamily = const Value.absent(),
                Value<String> diaryBodyFontFamily = const Value.absent(),
                Value<bool> reduceMotion = const Value.absent(),
                Value<bool> simplerEffects = const Value.absent(),
              }) => AppearanceSettingsCompanion.insert(
                id: id,
                theme: theme,
                accent: accent,
                fontFamily: fontFamily,
                diaryTitleFontFamily: diaryTitleFontFamily,
                diaryBodyFontFamily: diaryBodyFontFamily,
                reduceMotion: reduceMotion,
                simplerEffects: simplerEffects,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AppearanceSettingsTable, AppearanceRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $AppearanceSettingsTable,
                    AppearanceRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AppearanceSettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AppearanceSettingsTable,
      AppearanceRow,
      $$AppearanceSettingsTableFilterComposer,
      $$AppearanceSettingsTableOrderingComposer,
      $$AppearanceSettingsTableAnnotationComposer,
      $$AppearanceSettingsTableCreateCompanionBuilder,
      $$AppearanceSettingsTableUpdateCompanionBuilder,
      (
        AppearanceRow,
        BaseReferences<_$AppDatabase, $AppearanceSettingsTable, AppearanceRow>,
      ),
      AppearanceRow,
      PrefetchHooks Function()
    >;
typedef $$OnboardingCompletionTableCreateCompanionBuilder =
    OnboardingCompletionCompanion Function({
      Value<int> id,
      required String name,
    });
typedef $$OnboardingCompletionTableUpdateCompanionBuilder =
    OnboardingCompletionCompanion Function({Value<int> id, Value<String> name});

class $$OnboardingCompletionTableFilterComposer
    extends Composer<_$AppDatabase, $OnboardingCompletionTable> {
  $$OnboardingCompletionTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );
}

class $$OnboardingCompletionTableOrderingComposer
    extends Composer<_$AppDatabase, $OnboardingCompletionTable> {
  $$OnboardingCompletionTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$OnboardingCompletionTableAnnotationComposer
    extends Composer<_$AppDatabase, $OnboardingCompletionTable> {
  $$OnboardingCompletionTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);
}

class $$OnboardingCompletionTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $OnboardingCompletionTable,
          OnboardingCompletionRow,
          $$OnboardingCompletionTableFilterComposer,
          $$OnboardingCompletionTableOrderingComposer,
          $$OnboardingCompletionTableAnnotationComposer,
          $$OnboardingCompletionTableCreateCompanionBuilder,
          $$OnboardingCompletionTableUpdateCompanionBuilder,
          (
            OnboardingCompletionRow,
            BaseReferences<
              _$AppDatabase,
              $OnboardingCompletionTable,
              OnboardingCompletionRow
            >,
          ),
          OnboardingCompletionRow,
          PrefetchHooks Function()
        > {
  $$OnboardingCompletionTableTableManager(
    _$AppDatabase db,
    $OnboardingCompletionTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OnboardingCompletionTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OnboardingCompletionTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$OnboardingCompletionTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> name = const Value.absent(),
          }) => OnboardingCompletionCompanion(id: id, name: name),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String name,
          }) => OnboardingCompletionCompanion.insert(id: id, name: name),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $OnboardingCompletionTable,
                    OnboardingCompletionRow
                  >(table),
                  BaseReferences<
                    _$AppDatabase,
                    $OnboardingCompletionTable,
                    OnboardingCompletionRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$OnboardingCompletionTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $OnboardingCompletionTable,
      OnboardingCompletionRow,
      $$OnboardingCompletionTableFilterComposer,
      $$OnboardingCompletionTableOrderingComposer,
      $$OnboardingCompletionTableAnnotationComposer,
      $$OnboardingCompletionTableCreateCompanionBuilder,
      $$OnboardingCompletionTableUpdateCompanionBuilder,
      (
        OnboardingCompletionRow,
        BaseReferences<
          _$AppDatabase,
          $OnboardingCompletionTable,
          OnboardingCompletionRow
        >,
      ),
      OnboardingCompletionRow,
      PrefetchHooks Function()
    >;
typedef $$NotesTableCreateCompanionBuilder = NotesCompanion Function({
  Value<String> details,
  required String id,
  required String title,
  required String body,
  required int revision,
  required int createdAt,
  required int updatedAt,
  Value<bool> pinned,
  Value<int?> deletedAt,
  Value<int> rowid,
});
typedef $$NotesTableUpdateCompanionBuilder = NotesCompanion Function({
  Value<String> details,
  Value<String> id,
  Value<String> title,
  Value<String> body,
  Value<int> revision,
  Value<int> createdAt,
  Value<int> updatedAt,
  Value<bool> pinned,
  Value<int?> deletedAt,
  Value<int> rowid,
});

final class $$NotesTableReferences
    extends BaseReferences<_$AppDatabase, $NotesTable, Note> {
  $$NotesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$NoteTagsTable, List<NoteTag>> _noteTagsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.noteTags,
    aliasName: 'notes__id__note_tags__note_id',
  );

  $$NoteTagsTableProcessedTableManager get noteTagsRefs {
    final manager = $$NoteTagsTableTableManager(
      $_db,
      $_db.noteTags,
    ).filter((f) => f.noteId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_noteTagsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$NoteWebsitesTable, List<NoteWebsiteRow>>
  _noteWebsitesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.noteWebsites,
    aliasName: 'notes__id__note_websites__note_id',
  );

  $$NoteWebsitesTableProcessedTableManager get noteWebsitesRefs {
    final manager = $$NoteWebsitesTableTableManager(
      $_db,
      $_db.noteWebsites,
    ).filter((f) => f.noteId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_noteWebsitesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$NotesTableFilterComposer extends Composer<_$AppDatabase, $NotesTable> {
  $$NotesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get details => $composableBuilder(
    column: $table.details,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get pinned => $composableBuilder(
    column: $table.pinned,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> noteTagsRefs(
    Expression<bool> Function($$NoteTagsTableFilterComposer f) f,
  ) {
    final $$NoteTagsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.noteTags,
      getReferencedColumn: (t) => t.noteId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NoteTagsTableFilterComposer(
            $db: $db,
            $table: $db.noteTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> noteWebsitesRefs(
    Expression<bool> Function($$NoteWebsitesTableFilterComposer f) f,
  ) {
    final $$NoteWebsitesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.noteWebsites,
      getReferencedColumn: (t) => t.noteId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NoteWebsitesTableFilterComposer(
            $db: $db,
            $table: $db.noteWebsites,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$NotesTableOrderingComposer
    extends Composer<_$AppDatabase, $NotesTable> {
  $$NotesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get details => $composableBuilder(
    column: $table.details,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get pinned => $composableBuilder(
    column: $table.pinned,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$NotesTableAnnotationComposer
    extends Composer<_$AppDatabase, $NotesTable> {
  $$NotesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get details =>
      $composableBuilder(column: $table.details, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<bool> get pinned =>
      $composableBuilder(column: $table.pinned, builder: (column) => column);

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  Expression<T> noteTagsRefs<T extends Object>(
    Expression<T> Function($$NoteTagsTableAnnotationComposer a) f,
  ) {
    final $$NoteTagsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.noteTags,
      getReferencedColumn: (t) => t.noteId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NoteTagsTableAnnotationComposer(
            $db: $db,
            $table: $db.noteTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> noteWebsitesRefs<T extends Object>(
    Expression<T> Function($$NoteWebsitesTableAnnotationComposer a) f,
  ) {
    final $$NoteWebsitesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.noteWebsites,
      getReferencedColumn: (t) => t.noteId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NoteWebsitesTableAnnotationComposer(
            $db: $db,
            $table: $db.noteWebsites,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$NotesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $NotesTable,
          Note,
          $$NotesTableFilterComposer,
          $$NotesTableOrderingComposer,
          $$NotesTableAnnotationComposer,
          $$NotesTableCreateCompanionBuilder,
          $$NotesTableUpdateCompanionBuilder,
          (Note, $$NotesTableReferences),
          Note,
          PrefetchHooks Function({bool noteTagsRefs, bool noteWebsitesRefs})
        > {
  $$NotesTableTableManager(_$AppDatabase db, $NotesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NotesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$NotesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$NotesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> details = const Value.absent(),
                Value<String> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> body = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<bool> pinned = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NotesCompanion(
                details: details,
                id: id,
                title: title,
                body: body,
                revision: revision,
                createdAt: createdAt,
                updatedAt: updatedAt,
                pinned: pinned,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<String> details = const Value.absent(),
                required String id,
                required String title,
                required String body,
                required int revision,
                required int createdAt,
                required int updatedAt,
                Value<bool> pinned = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NotesCompanion.insert(
                details: details,
                id: id,
                title: title,
                body: body,
                revision: revision,
                createdAt: createdAt,
                updatedAt: updatedAt,
                pinned: pinned,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$NotesTable, Note>(table),
                  $$NotesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({noteTagsRefs = false, noteWebsitesRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (noteTagsRefs) db.noteTags,
                    if (noteWebsitesRefs) db.noteWebsites,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (noteTagsRefs)
                        await $_getPrefetchedDataByColumns<
                          Note,
                          $NotesTable,
                          NoteTag,
                          $NoteTagsTable
                        >(
                          currentTable: table,
                          referencedTable: $$NotesTableReferences
                              ._noteTagsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$NotesTableReferences(
                                db,
                                table,
                                p0,
                              ).noteTagsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'note_id',
                          typedResults: items,
                        ),
                      if (noteWebsitesRefs)
                        await $_getPrefetchedDataByColumns<
                          Note,
                          $NotesTable,
                          NoteWebsiteRow,
                          $NoteWebsitesTable
                        >(
                          currentTable: table,
                          referencedTable: $$NotesTableReferences
                              ._noteWebsitesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$NotesTableReferences(
                                db,
                                table,
                                p0,
                              ).noteWebsitesRefs,
                          currentColumn: 'id',
                          referencedColumn: 'note_id',
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$NotesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $NotesTable,
      Note,
      $$NotesTableFilterComposer,
      $$NotesTableOrderingComposer,
      $$NotesTableAnnotationComposer,
      $$NotesTableCreateCompanionBuilder,
      $$NotesTableUpdateCompanionBuilder,
      (Note, $$NotesTableReferences),
      Note,
      PrefetchHooks Function({bool noteTagsRefs, bool noteWebsitesRefs})
    >;
typedef $$NoteTagsTableCreateCompanionBuilder = NoteTagsCompanion Function({
  required String noteId,
  required String tag,
  Value<int> rowid,
});
typedef $$NoteTagsTableUpdateCompanionBuilder = NoteTagsCompanion Function({
  Value<String> noteId,
  Value<String> tag,
  Value<int> rowid,
});

final class $$NoteTagsTableReferences
    extends BaseReferences<_$AppDatabase, $NoteTagsTable, NoteTag> {
  $$NoteTagsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $NotesTable _noteIdTable(_$AppDatabase db) =>
      db.notes.createAlias('note_tags__note_id__notes__id');

  $$NotesTableProcessedTableManager get noteId {
    final $_column = $_itemColumn<String>('note_id')!;

    final manager = $$NotesTableTableManager(
      $_db,
      $_db.notes,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_noteIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$NoteTagsTableFilterComposer
    extends Composer<_$AppDatabase, $NoteTagsTable> {
  $$NoteTagsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get tag => $composableBuilder(
    column: $table.tag,
    builder: (column) => ColumnFilters(column),
  );

  $$NotesTableFilterComposer get noteId {
    final $$NotesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.noteId,
      referencedTable: $db.notes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NotesTableFilterComposer(
            $db: $db,
            $table: $db.notes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$NoteTagsTableOrderingComposer
    extends Composer<_$AppDatabase, $NoteTagsTable> {
  $$NoteTagsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get tag => $composableBuilder(
    column: $table.tag,
    builder: (column) => ColumnOrderings(column),
  );

  $$NotesTableOrderingComposer get noteId {
    final $$NotesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.noteId,
      referencedTable: $db.notes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NotesTableOrderingComposer(
            $db: $db,
            $table: $db.notes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$NoteTagsTableAnnotationComposer
    extends Composer<_$AppDatabase, $NoteTagsTable> {
  $$NoteTagsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get tag =>
      $composableBuilder(column: $table.tag, builder: (column) => column);

  $$NotesTableAnnotationComposer get noteId {
    final $$NotesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.noteId,
      referencedTable: $db.notes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NotesTableAnnotationComposer(
            $db: $db,
            $table: $db.notes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$NoteTagsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $NoteTagsTable,
          NoteTag,
          $$NoteTagsTableFilterComposer,
          $$NoteTagsTableOrderingComposer,
          $$NoteTagsTableAnnotationComposer,
          $$NoteTagsTableCreateCompanionBuilder,
          $$NoteTagsTableUpdateCompanionBuilder,
          (NoteTag, $$NoteTagsTableReferences),
          NoteTag,
          PrefetchHooks Function({bool noteId})
        > {
  $$NoteTagsTableTableManager(_$AppDatabase db, $NoteTagsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NoteTagsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$NoteTagsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$NoteTagsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> noteId = const Value.absent(),
            Value<String> tag = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => NoteTagsCompanion(noteId: noteId, tag: tag, rowid: rowid),
          createCompanionCallback:
              ({
                required String noteId,
                required String tag,
                Value<int> rowid = const Value.absent(),
              }) => NoteTagsCompanion.insert(
                noteId: noteId,
                tag: tag,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$NoteTagsTable, NoteTag>(table),
                  $$NoteTagsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({noteId = false}) {
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
                    if (noteId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.noteId,
                        referencedTable: $$NoteTagsTableReferences._noteIdTable(
                          db,
                        ),
                        referencedColumn: $$NoteTagsTableReferences
                            ._noteIdTable(db)
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

typedef $$NoteTagsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $NoteTagsTable,
      NoteTag,
      $$NoteTagsTableFilterComposer,
      $$NoteTagsTableOrderingComposer,
      $$NoteTagsTableAnnotationComposer,
      $$NoteTagsTableCreateCompanionBuilder,
      $$NoteTagsTableUpdateCompanionBuilder,
      (NoteTag, $$NoteTagsTableReferences),
      NoteTag,
      PrefetchHooks Function({bool noteId})
    >;
typedef $$NoteMediaOpsTableCreateCompanionBuilder =
    NoteMediaOpsCompanion Function({
      required String path,
      required int created,
      Value<int> rowid,
    });
typedef $$NoteMediaOpsTableUpdateCompanionBuilder =
    NoteMediaOpsCompanion Function({
      Value<String> path,
      Value<int> created,
      Value<int> rowid,
    });

class $$NoteMediaOpsTableFilterComposer
    extends Composer<_$AppDatabase, $NoteMediaOpsTable> {
  $$NoteMediaOpsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get created => $composableBuilder(
    column: $table.created,
    builder: (column) => ColumnFilters(column),
  );
}

class $$NoteMediaOpsTableOrderingComposer
    extends Composer<_$AppDatabase, $NoteMediaOpsTable> {
  $$NoteMediaOpsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get created => $composableBuilder(
    column: $table.created,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$NoteMediaOpsTableAnnotationComposer
    extends Composer<_$AppDatabase, $NoteMediaOpsTable> {
  $$NoteMediaOpsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => column);

  GeneratedColumn<int> get created =>
      $composableBuilder(column: $table.created, builder: (column) => column);
}

class $$NoteMediaOpsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $NoteMediaOpsTable,
          NoteMediaOp,
          $$NoteMediaOpsTableFilterComposer,
          $$NoteMediaOpsTableOrderingComposer,
          $$NoteMediaOpsTableAnnotationComposer,
          $$NoteMediaOpsTableCreateCompanionBuilder,
          $$NoteMediaOpsTableUpdateCompanionBuilder,
          (
            NoteMediaOp,
            BaseReferences<_$AppDatabase, $NoteMediaOpsTable, NoteMediaOp>,
          ),
          NoteMediaOp,
          PrefetchHooks Function()
        > {
  $$NoteMediaOpsTableTableManager(_$AppDatabase db, $NoteMediaOpsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NoteMediaOpsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$NoteMediaOpsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$NoteMediaOpsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> path = const Value.absent(),
                Value<int> created = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NoteMediaOpsCompanion(
                path: path,
                created: created,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String path,
                required int created,
                Value<int> rowid = const Value.absent(),
              }) => NoteMediaOpsCompanion.insert(
                path: path,
                created: created,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$NoteMediaOpsTable, NoteMediaOp>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $NoteMediaOpsTable,
                    NoteMediaOp
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$NoteMediaOpsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $NoteMediaOpsTable,
      NoteMediaOp,
      $$NoteMediaOpsTableFilterComposer,
      $$NoteMediaOpsTableOrderingComposer,
      $$NoteMediaOpsTableAnnotationComposer,
      $$NoteMediaOpsTableCreateCompanionBuilder,
      $$NoteMediaOpsTableUpdateCompanionBuilder,
      (
        NoteMediaOp,
        BaseReferences<_$AppDatabase, $NoteMediaOpsTable, NoteMediaOp>,
      ),
      NoteMediaOp,
      PrefetchHooks Function()
    >;
typedef $$NoteWebsitesTableCreateCompanionBuilder =
    NoteWebsitesCompanion Function({
      required String noteId,
      required String html,
      required String sourceHash,
      Value<String> brief,
      Value<String> model,
      required int madeAt,
      Value<String> state,
      Value<String> previousHtml,
      Value<String> previousSourceHash,
      Value<bool> syncChecks,
      Value<int> rowid,
    });
typedef $$NoteWebsitesTableUpdateCompanionBuilder =
    NoteWebsitesCompanion Function({
      Value<String> noteId,
      Value<String> html,
      Value<String> sourceHash,
      Value<String> brief,
      Value<String> model,
      Value<int> madeAt,
      Value<String> state,
      Value<String> previousHtml,
      Value<String> previousSourceHash,
      Value<bool> syncChecks,
      Value<int> rowid,
    });

final class $$NoteWebsitesTableReferences
    extends BaseReferences<_$AppDatabase, $NoteWebsitesTable, NoteWebsiteRow> {
  $$NoteWebsitesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $NotesTable _noteIdTable(_$AppDatabase db) =>
      db.notes.createAlias('note_websites__note_id__notes__id');

  $$NotesTableProcessedTableManager get noteId {
    final $_column = $_itemColumn<String>('note_id')!;

    final manager = $$NotesTableTableManager(
      $_db,
      $_db.notes,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_noteIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$NoteWebsitesTableFilterComposer
    extends Composer<_$AppDatabase, $NoteWebsitesTable> {
  $$NoteWebsitesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get html => $composableBuilder(
    column: $table.html,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceHash => $composableBuilder(
    column: $table.sourceHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get brief => $composableBuilder(
    column: $table.brief,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get model => $composableBuilder(
    column: $table.model,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get madeAt => $composableBuilder(
    column: $table.madeAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get previousHtml => $composableBuilder(
    column: $table.previousHtml,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get previousSourceHash => $composableBuilder(
    column: $table.previousSourceHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get syncChecks => $composableBuilder(
    column: $table.syncChecks,
    builder: (column) => ColumnFilters(column),
  );

  $$NotesTableFilterComposer get noteId {
    final $$NotesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.noteId,
      referencedTable: $db.notes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NotesTableFilterComposer(
            $db: $db,
            $table: $db.notes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$NoteWebsitesTableOrderingComposer
    extends Composer<_$AppDatabase, $NoteWebsitesTable> {
  $$NoteWebsitesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get html => $composableBuilder(
    column: $table.html,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceHash => $composableBuilder(
    column: $table.sourceHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get brief => $composableBuilder(
    column: $table.brief,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get model => $composableBuilder(
    column: $table.model,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get madeAt => $composableBuilder(
    column: $table.madeAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get previousHtml => $composableBuilder(
    column: $table.previousHtml,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get previousSourceHash => $composableBuilder(
    column: $table.previousSourceHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get syncChecks => $composableBuilder(
    column: $table.syncChecks,
    builder: (column) => ColumnOrderings(column),
  );

  $$NotesTableOrderingComposer get noteId {
    final $$NotesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.noteId,
      referencedTable: $db.notes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NotesTableOrderingComposer(
            $db: $db,
            $table: $db.notes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$NoteWebsitesTableAnnotationComposer
    extends Composer<_$AppDatabase, $NoteWebsitesTable> {
  $$NoteWebsitesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get html =>
      $composableBuilder(column: $table.html, builder: (column) => column);

  GeneratedColumn<String> get sourceHash => $composableBuilder(
    column: $table.sourceHash,
    builder: (column) => column,
  );

  GeneratedColumn<String> get brief =>
      $composableBuilder(column: $table.brief, builder: (column) => column);

  GeneratedColumn<String> get model =>
      $composableBuilder(column: $table.model, builder: (column) => column);

  GeneratedColumn<int> get madeAt =>
      $composableBuilder(column: $table.madeAt, builder: (column) => column);

  GeneratedColumn<String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<String> get previousHtml => $composableBuilder(
    column: $table.previousHtml,
    builder: (column) => column,
  );

  GeneratedColumn<String> get previousSourceHash => $composableBuilder(
    column: $table.previousSourceHash,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get syncChecks => $composableBuilder(
    column: $table.syncChecks,
    builder: (column) => column,
  );

  $$NotesTableAnnotationComposer get noteId {
    final $$NotesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.noteId,
      referencedTable: $db.notes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NotesTableAnnotationComposer(
            $db: $db,
            $table: $db.notes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$NoteWebsitesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $NoteWebsitesTable,
          NoteWebsiteRow,
          $$NoteWebsitesTableFilterComposer,
          $$NoteWebsitesTableOrderingComposer,
          $$NoteWebsitesTableAnnotationComposer,
          $$NoteWebsitesTableCreateCompanionBuilder,
          $$NoteWebsitesTableUpdateCompanionBuilder,
          (NoteWebsiteRow, $$NoteWebsitesTableReferences),
          NoteWebsiteRow,
          PrefetchHooks Function({bool noteId})
        > {
  $$NoteWebsitesTableTableManager(_$AppDatabase db, $NoteWebsitesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NoteWebsitesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$NoteWebsitesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$NoteWebsitesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> noteId = const Value.absent(),
                Value<String> html = const Value.absent(),
                Value<String> sourceHash = const Value.absent(),
                Value<String> brief = const Value.absent(),
                Value<String> model = const Value.absent(),
                Value<int> madeAt = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<String> previousHtml = const Value.absent(),
                Value<String> previousSourceHash = const Value.absent(),
                Value<bool> syncChecks = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NoteWebsitesCompanion(
                noteId: noteId,
                html: html,
                sourceHash: sourceHash,
                brief: brief,
                model: model,
                madeAt: madeAt,
                state: state,
                previousHtml: previousHtml,
                previousSourceHash: previousSourceHash,
                syncChecks: syncChecks,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String noteId,
                required String html,
                required String sourceHash,
                Value<String> brief = const Value.absent(),
                Value<String> model = const Value.absent(),
                required int madeAt,
                Value<String> state = const Value.absent(),
                Value<String> previousHtml = const Value.absent(),
                Value<String> previousSourceHash = const Value.absent(),
                Value<bool> syncChecks = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NoteWebsitesCompanion.insert(
                noteId: noteId,
                html: html,
                sourceHash: sourceHash,
                brief: brief,
                model: model,
                madeAt: madeAt,
                state: state,
                previousHtml: previousHtml,
                previousSourceHash: previousSourceHash,
                syncChecks: syncChecks,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$NoteWebsitesTable, NoteWebsiteRow>(table),
                  $$NoteWebsitesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({noteId = false}) {
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
                    if (noteId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.noteId,
                        referencedTable: $$NoteWebsitesTableReferences
                            ._noteIdTable(db),
                        referencedColumn: $$NoteWebsitesTableReferences
                            ._noteIdTable(db)
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

typedef $$NoteWebsitesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $NoteWebsitesTable,
      NoteWebsiteRow,
      $$NoteWebsitesTableFilterComposer,
      $$NoteWebsitesTableOrderingComposer,
      $$NoteWebsitesTableAnnotationComposer,
      $$NoteWebsitesTableCreateCompanionBuilder,
      $$NoteWebsitesTableUpdateCompanionBuilder,
      (NoteWebsiteRow, $$NoteWebsitesTableReferences),
      NoteWebsiteRow,
      PrefetchHooks Function({bool noteId})
    >;
typedef $$NoteChatTurnsTableCreateCompanionBuilder =
    NoteChatTurnsCompanion Function({
      required String id,
      required String noteId,
      required int at,
      required String ask,
      Value<String> reply,
      Value<String> actions,
      Value<int> rowid,
    });
typedef $$NoteChatTurnsTableUpdateCompanionBuilder =
    NoteChatTurnsCompanion Function({
      Value<String> id,
      Value<String> noteId,
      Value<int> at,
      Value<String> ask,
      Value<String> reply,
      Value<String> actions,
      Value<int> rowid,
    });

class $$NoteChatTurnsTableFilterComposer
    extends Composer<_$AppDatabase, $NoteChatTurnsTable> {
  $$NoteChatTurnsTableFilterComposer({
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

  ColumnFilters<String> get noteId => $composableBuilder(
    column: $table.noteId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get at => $composableBuilder(
    column: $table.at,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ask => $composableBuilder(
    column: $table.ask,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reply => $composableBuilder(
    column: $table.reply,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get actions => $composableBuilder(
    column: $table.actions,
    builder: (column) => ColumnFilters(column),
  );
}

class $$NoteChatTurnsTableOrderingComposer
    extends Composer<_$AppDatabase, $NoteChatTurnsTable> {
  $$NoteChatTurnsTableOrderingComposer({
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

  ColumnOrderings<String> get noteId => $composableBuilder(
    column: $table.noteId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get at => $composableBuilder(
    column: $table.at,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ask => $composableBuilder(
    column: $table.ask,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reply => $composableBuilder(
    column: $table.reply,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get actions => $composableBuilder(
    column: $table.actions,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$NoteChatTurnsTableAnnotationComposer
    extends Composer<_$AppDatabase, $NoteChatTurnsTable> {
  $$NoteChatTurnsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get noteId =>
      $composableBuilder(column: $table.noteId, builder: (column) => column);

  GeneratedColumn<int> get at =>
      $composableBuilder(column: $table.at, builder: (column) => column);

  GeneratedColumn<String> get ask =>
      $composableBuilder(column: $table.ask, builder: (column) => column);

  GeneratedColumn<String> get reply =>
      $composableBuilder(column: $table.reply, builder: (column) => column);

  GeneratedColumn<String> get actions =>
      $composableBuilder(column: $table.actions, builder: (column) => column);
}

class $$NoteChatTurnsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $NoteChatTurnsTable,
          NoteChatTurnRow,
          $$NoteChatTurnsTableFilterComposer,
          $$NoteChatTurnsTableOrderingComposer,
          $$NoteChatTurnsTableAnnotationComposer,
          $$NoteChatTurnsTableCreateCompanionBuilder,
          $$NoteChatTurnsTableUpdateCompanionBuilder,
          (
            NoteChatTurnRow,
            BaseReferences<_$AppDatabase, $NoteChatTurnsTable, NoteChatTurnRow>,
          ),
          NoteChatTurnRow,
          PrefetchHooks Function()
        > {
  $$NoteChatTurnsTableTableManager(_$AppDatabase db, $NoteChatTurnsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NoteChatTurnsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$NoteChatTurnsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$NoteChatTurnsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> noteId = const Value.absent(),
                Value<int> at = const Value.absent(),
                Value<String> ask = const Value.absent(),
                Value<String> reply = const Value.absent(),
                Value<String> actions = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NoteChatTurnsCompanion(
                id: id,
                noteId: noteId,
                at: at,
                ask: ask,
                reply: reply,
                actions: actions,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String noteId,
                required int at,
                required String ask,
                Value<String> reply = const Value.absent(),
                Value<String> actions = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NoteChatTurnsCompanion.insert(
                id: id,
                noteId: noteId,
                at: at,
                ask: ask,
                reply: reply,
                actions: actions,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$NoteChatTurnsTable, NoteChatTurnRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $NoteChatTurnsTable,
                    NoteChatTurnRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$NoteChatTurnsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $NoteChatTurnsTable,
      NoteChatTurnRow,
      $$NoteChatTurnsTableFilterComposer,
      $$NoteChatTurnsTableOrderingComposer,
      $$NoteChatTurnsTableAnnotationComposer,
      $$NoteChatTurnsTableCreateCompanionBuilder,
      $$NoteChatTurnsTableUpdateCompanionBuilder,
      (
        NoteChatTurnRow,
        BaseReferences<_$AppDatabase, $NoteChatTurnsTable, NoteChatTurnRow>,
      ),
      NoteChatTurnRow,
      PrefetchHooks Function()
    >;
typedef $$DiaryEntriesTableCreateCompanionBuilder =
    DiaryEntriesCompanion Function({
      required String id,
      required String periodKey,
      required String body,
      Value<String> photos,
      required int revision,
      required int createdAt,
      required int updatedAt,
      Value<int?> deletedAt,
      Value<String> kind,
      Value<int> rowid,
    });
typedef $$DiaryEntriesTableUpdateCompanionBuilder =
    DiaryEntriesCompanion Function({
      Value<String> id,
      Value<String> periodKey,
      Value<String> body,
      Value<String> photos,
      Value<int> revision,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<int?> deletedAt,
      Value<String> kind,
      Value<int> rowid,
    });

class $$DiaryEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $DiaryEntriesTable> {
  $$DiaryEntriesTableFilterComposer({
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

  ColumnFilters<String> get periodKey => $composableBuilder(
    column: $table.periodKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get photos => $composableBuilder(
    column: $table.photos,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DiaryEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $DiaryEntriesTable> {
  $$DiaryEntriesTableOrderingComposer({
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

  ColumnOrderings<String> get periodKey => $composableBuilder(
    column: $table.periodKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get photos => $composableBuilder(
    column: $table.photos,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DiaryEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $DiaryEntriesTable> {
  $$DiaryEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get periodKey =>
      $composableBuilder(column: $table.periodKey, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<String> get photos =>
      $composableBuilder(column: $table.photos, builder: (column) => column);

  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);
}

class $$DiaryEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DiaryEntriesTable,
          DiaryEntryRow,
          $$DiaryEntriesTableFilterComposer,
          $$DiaryEntriesTableOrderingComposer,
          $$DiaryEntriesTableAnnotationComposer,
          $$DiaryEntriesTableCreateCompanionBuilder,
          $$DiaryEntriesTableUpdateCompanionBuilder,
          (
            DiaryEntryRow,
            BaseReferences<_$AppDatabase, $DiaryEntriesTable, DiaryEntryRow>,
          ),
          DiaryEntryRow,
          PrefetchHooks Function()
        > {
  $$DiaryEntriesTableTableManager(_$AppDatabase db, $DiaryEntriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DiaryEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DiaryEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DiaryEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> periodKey = const Value.absent(),
                Value<String> body = const Value.absent(),
                Value<String> photos = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DiaryEntriesCompanion(
                id: id,
                periodKey: periodKey,
                body: body,
                photos: photos,
                revision: revision,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                kind: kind,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String periodKey,
                required String body,
                Value<String> photos = const Value.absent(),
                required int revision,
                required int createdAt,
                required int updatedAt,
                Value<int?> deletedAt = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DiaryEntriesCompanion.insert(
                id: id,
                periodKey: periodKey,
                body: body,
                photos: photos,
                revision: revision,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                kind: kind,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$DiaryEntriesTable, DiaryEntryRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $DiaryEntriesTable,
                    DiaryEntryRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DiaryEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DiaryEntriesTable,
      DiaryEntryRow,
      $$DiaryEntriesTableFilterComposer,
      $$DiaryEntriesTableOrderingComposer,
      $$DiaryEntriesTableAnnotationComposer,
      $$DiaryEntriesTableCreateCompanionBuilder,
      $$DiaryEntriesTableUpdateCompanionBuilder,
      (
        DiaryEntryRow,
        BaseReferences<_$AppDatabase, $DiaryEntriesTable, DiaryEntryRow>,
      ),
      DiaryEntryRow,
      PrefetchHooks Function()
    >;
typedef $$DiaryDaysTableCreateCompanionBuilder = DiaryDaysCompanion Function({
  required String periodKey,
  required String heading,
  Value<String?> mood,
  Value<String> themes,
  required int revision,
  Value<int> rowid,
});
typedef $$DiaryDaysTableUpdateCompanionBuilder = DiaryDaysCompanion Function({
  Value<String> periodKey,
  Value<String> heading,
  Value<String?> mood,
  Value<String> themes,
  Value<int> revision,
  Value<int> rowid,
});

class $$DiaryDaysTableFilterComposer
    extends Composer<_$AppDatabase, $DiaryDaysTable> {
  $$DiaryDaysTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get periodKey => $composableBuilder(
    column: $table.periodKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get heading => $composableBuilder(
    column: $table.heading,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mood => $composableBuilder(
    column: $table.mood,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get themes => $composableBuilder(
    column: $table.themes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DiaryDaysTableOrderingComposer
    extends Composer<_$AppDatabase, $DiaryDaysTable> {
  $$DiaryDaysTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get periodKey => $composableBuilder(
    column: $table.periodKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get heading => $composableBuilder(
    column: $table.heading,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mood => $composableBuilder(
    column: $table.mood,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get themes => $composableBuilder(
    column: $table.themes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DiaryDaysTableAnnotationComposer
    extends Composer<_$AppDatabase, $DiaryDaysTable> {
  $$DiaryDaysTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get periodKey =>
      $composableBuilder(column: $table.periodKey, builder: (column) => column);

  GeneratedColumn<String> get heading =>
      $composableBuilder(column: $table.heading, builder: (column) => column);

  GeneratedColumn<String> get mood =>
      $composableBuilder(column: $table.mood, builder: (column) => column);

  GeneratedColumn<String> get themes =>
      $composableBuilder(column: $table.themes, builder: (column) => column);

  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);
}

class $$DiaryDaysTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DiaryDaysTable,
          DiaryDayRow,
          $$DiaryDaysTableFilterComposer,
          $$DiaryDaysTableOrderingComposer,
          $$DiaryDaysTableAnnotationComposer,
          $$DiaryDaysTableCreateCompanionBuilder,
          $$DiaryDaysTableUpdateCompanionBuilder,
          (
            DiaryDayRow,
            BaseReferences<_$AppDatabase, $DiaryDaysTable, DiaryDayRow>,
          ),
          DiaryDayRow,
          PrefetchHooks Function()
        > {
  $$DiaryDaysTableTableManager(_$AppDatabase db, $DiaryDaysTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DiaryDaysTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DiaryDaysTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DiaryDaysTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> periodKey = const Value.absent(),
                Value<String> heading = const Value.absent(),
                Value<String?> mood = const Value.absent(),
                Value<String> themes = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DiaryDaysCompanion(
                periodKey: periodKey,
                heading: heading,
                mood: mood,
                themes: themes,
                revision: revision,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String periodKey,
                required String heading,
                Value<String?> mood = const Value.absent(),
                Value<String> themes = const Value.absent(),
                required int revision,
                Value<int> rowid = const Value.absent(),
              }) => DiaryDaysCompanion.insert(
                periodKey: periodKey,
                heading: heading,
                mood: mood,
                themes: themes,
                revision: revision,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$DiaryDaysTable, DiaryDayRow>(table),
                  BaseReferences<_$AppDatabase, $DiaryDaysTable, DiaryDayRow>(
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

typedef $$DiaryDaysTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DiaryDaysTable,
      DiaryDayRow,
      $$DiaryDaysTableFilterComposer,
      $$DiaryDaysTableOrderingComposer,
      $$DiaryDaysTableAnnotationComposer,
      $$DiaryDaysTableCreateCompanionBuilder,
      $$DiaryDaysTableUpdateCompanionBuilder,
      (
        DiaryDayRow,
        BaseReferences<_$AppDatabase, $DiaryDaysTable, DiaryDayRow>,
      ),
      DiaryDayRow,
      PrefetchHooks Function()
    >;
typedef $$DiaryMediaOpsTableCreateCompanionBuilder =
    DiaryMediaOpsCompanion Function({
      required String path,
      required String action,
      required String owner,
      required int created,
      Value<int> rowid,
    });
typedef $$DiaryMediaOpsTableUpdateCompanionBuilder =
    DiaryMediaOpsCompanion Function({
      Value<String> path,
      Value<String> action,
      Value<String> owner,
      Value<int> created,
      Value<int> rowid,
    });

class $$DiaryMediaOpsTableFilterComposer
    extends Composer<_$AppDatabase, $DiaryMediaOpsTable> {
  $$DiaryMediaOpsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get action => $composableBuilder(
    column: $table.action,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get owner => $composableBuilder(
    column: $table.owner,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get created => $composableBuilder(
    column: $table.created,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DiaryMediaOpsTableOrderingComposer
    extends Composer<_$AppDatabase, $DiaryMediaOpsTable> {
  $$DiaryMediaOpsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get action => $composableBuilder(
    column: $table.action,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get owner => $composableBuilder(
    column: $table.owner,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get created => $composableBuilder(
    column: $table.created,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DiaryMediaOpsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DiaryMediaOpsTable> {
  $$DiaryMediaOpsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => column);

  GeneratedColumn<String> get action =>
      $composableBuilder(column: $table.action, builder: (column) => column);

  GeneratedColumn<String> get owner =>
      $composableBuilder(column: $table.owner, builder: (column) => column);

  GeneratedColumn<int> get created =>
      $composableBuilder(column: $table.created, builder: (column) => column);
}

class $$DiaryMediaOpsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DiaryMediaOpsTable,
          DiaryMediaOpRow,
          $$DiaryMediaOpsTableFilterComposer,
          $$DiaryMediaOpsTableOrderingComposer,
          $$DiaryMediaOpsTableAnnotationComposer,
          $$DiaryMediaOpsTableCreateCompanionBuilder,
          $$DiaryMediaOpsTableUpdateCompanionBuilder,
          (
            DiaryMediaOpRow,
            BaseReferences<_$AppDatabase, $DiaryMediaOpsTable, DiaryMediaOpRow>,
          ),
          DiaryMediaOpRow,
          PrefetchHooks Function()
        > {
  $$DiaryMediaOpsTableTableManager(_$AppDatabase db, $DiaryMediaOpsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DiaryMediaOpsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DiaryMediaOpsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DiaryMediaOpsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> path = const Value.absent(),
                Value<String> action = const Value.absent(),
                Value<String> owner = const Value.absent(),
                Value<int> created = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DiaryMediaOpsCompanion(
                path: path,
                action: action,
                owner: owner,
                created: created,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String path,
                required String action,
                required String owner,
                required int created,
                Value<int> rowid = const Value.absent(),
              }) => DiaryMediaOpsCompanion.insert(
                path: path,
                action: action,
                owner: owner,
                created: created,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$DiaryMediaOpsTable, DiaryMediaOpRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $DiaryMediaOpsTable,
                    DiaryMediaOpRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DiaryMediaOpsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DiaryMediaOpsTable,
      DiaryMediaOpRow,
      $$DiaryMediaOpsTableFilterComposer,
      $$DiaryMediaOpsTableOrderingComposer,
      $$DiaryMediaOpsTableAnnotationComposer,
      $$DiaryMediaOpsTableCreateCompanionBuilder,
      $$DiaryMediaOpsTableUpdateCompanionBuilder,
      (
        DiaryMediaOpRow,
        BaseReferences<_$AppDatabase, $DiaryMediaOpsTable, DiaryMediaOpRow>,
      ),
      DiaryMediaOpRow,
      PrefetchHooks Function()
    >;
typedef $$DiarySearchHistoryTableCreateCompanionBuilder =
    DiarySearchHistoryCompanion Function({
      required String query,
      required int sequence,
      Value<int> rowid,
    });
typedef $$DiarySearchHistoryTableUpdateCompanionBuilder =
    DiarySearchHistoryCompanion Function({
      Value<String> query,
      Value<int> sequence,
      Value<int> rowid,
    });

class $$DiarySearchHistoryTableFilterComposer
    extends Composer<_$AppDatabase, $DiarySearchHistoryTable> {
  $$DiarySearchHistoryTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get query => $composableBuilder(
    column: $table.query,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sequence => $composableBuilder(
    column: $table.sequence,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DiarySearchHistoryTableOrderingComposer
    extends Composer<_$AppDatabase, $DiarySearchHistoryTable> {
  $$DiarySearchHistoryTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get query => $composableBuilder(
    column: $table.query,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sequence => $composableBuilder(
    column: $table.sequence,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DiarySearchHistoryTableAnnotationComposer
    extends Composer<_$AppDatabase, $DiarySearchHistoryTable> {
  $$DiarySearchHistoryTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get query =>
      $composableBuilder(column: $table.query, builder: (column) => column);

  GeneratedColumn<int> get sequence =>
      $composableBuilder(column: $table.sequence, builder: (column) => column);
}

class $$DiarySearchHistoryTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DiarySearchHistoryTable,
          DiarySearchHistoryRow,
          $$DiarySearchHistoryTableFilterComposer,
          $$DiarySearchHistoryTableOrderingComposer,
          $$DiarySearchHistoryTableAnnotationComposer,
          $$DiarySearchHistoryTableCreateCompanionBuilder,
          $$DiarySearchHistoryTableUpdateCompanionBuilder,
          (
            DiarySearchHistoryRow,
            BaseReferences<
              _$AppDatabase,
              $DiarySearchHistoryTable,
              DiarySearchHistoryRow
            >,
          ),
          DiarySearchHistoryRow,
          PrefetchHooks Function()
        > {
  $$DiarySearchHistoryTableTableManager(
    _$AppDatabase db,
    $DiarySearchHistoryTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DiarySearchHistoryTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DiarySearchHistoryTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DiarySearchHistoryTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> query = const Value.absent(),
                Value<int> sequence = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DiarySearchHistoryCompanion(
                query: query,
                sequence: sequence,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String query,
                required int sequence,
                Value<int> rowid = const Value.absent(),
              }) => DiarySearchHistoryCompanion.insert(
                query: query,
                sequence: sequence,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$DiarySearchHistoryTable, DiarySearchHistoryRow>(
                    table,
                  ),
                  BaseReferences<
                    _$AppDatabase,
                    $DiarySearchHistoryTable,
                    DiarySearchHistoryRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DiarySearchHistoryTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DiarySearchHistoryTable,
      DiarySearchHistoryRow,
      $$DiarySearchHistoryTableFilterComposer,
      $$DiarySearchHistoryTableOrderingComposer,
      $$DiarySearchHistoryTableAnnotationComposer,
      $$DiarySearchHistoryTableCreateCompanionBuilder,
      $$DiarySearchHistoryTableUpdateCompanionBuilder,
      (
        DiarySearchHistoryRow,
        BaseReferences<
          _$AppDatabase,
          $DiarySearchHistoryTable,
          DiarySearchHistoryRow
        >,
      ),
      DiarySearchHistoryRow,
      PrefetchHooks Function()
    >;
typedef $$WatchCatalogTableCreateCompanionBuilder =
    WatchCatalogCompanion Function({
      required String mediaKey,
      required String data,
      Value<String> seasons,
      Value<bool> detailed,
      Value<double> popularity,
      required int fetchedAt,
      Value<int> rowid,
    });
typedef $$WatchCatalogTableUpdateCompanionBuilder =
    WatchCatalogCompanion Function({
      Value<String> mediaKey,
      Value<String> data,
      Value<String> seasons,
      Value<bool> detailed,
      Value<double> popularity,
      Value<int> fetchedAt,
      Value<int> rowid,
    });

class $$WatchCatalogTableFilterComposer
    extends Composer<_$AppDatabase, $WatchCatalogTable> {
  $$WatchCatalogTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get mediaKey => $composableBuilder(
    column: $table.mediaKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get seasons => $composableBuilder(
    column: $table.seasons,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get detailed => $composableBuilder(
    column: $table.detailed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get popularity => $composableBuilder(
    column: $table.popularity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get fetchedAt => $composableBuilder(
    column: $table.fetchedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$WatchCatalogTableOrderingComposer
    extends Composer<_$AppDatabase, $WatchCatalogTable> {
  $$WatchCatalogTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get mediaKey => $composableBuilder(
    column: $table.mediaKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get seasons => $composableBuilder(
    column: $table.seasons,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get detailed => $composableBuilder(
    column: $table.detailed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get popularity => $composableBuilder(
    column: $table.popularity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get fetchedAt => $composableBuilder(
    column: $table.fetchedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WatchCatalogTableAnnotationComposer
    extends Composer<_$AppDatabase, $WatchCatalogTable> {
  $$WatchCatalogTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get mediaKey =>
      $composableBuilder(column: $table.mediaKey, builder: (column) => column);

  GeneratedColumn<String> get data =>
      $composableBuilder(column: $table.data, builder: (column) => column);

  GeneratedColumn<String> get seasons =>
      $composableBuilder(column: $table.seasons, builder: (column) => column);

  GeneratedColumn<bool> get detailed =>
      $composableBuilder(column: $table.detailed, builder: (column) => column);

  GeneratedColumn<double> get popularity => $composableBuilder(
    column: $table.popularity,
    builder: (column) => column,
  );

  GeneratedColumn<int> get fetchedAt =>
      $composableBuilder(column: $table.fetchedAt, builder: (column) => column);
}

class $$WatchCatalogTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WatchCatalogTable,
          WatchCatalogRow,
          $$WatchCatalogTableFilterComposer,
          $$WatchCatalogTableOrderingComposer,
          $$WatchCatalogTableAnnotationComposer,
          $$WatchCatalogTableCreateCompanionBuilder,
          $$WatchCatalogTableUpdateCompanionBuilder,
          (
            WatchCatalogRow,
            BaseReferences<_$AppDatabase, $WatchCatalogTable, WatchCatalogRow>,
          ),
          WatchCatalogRow,
          PrefetchHooks Function()
        > {
  $$WatchCatalogTableTableManager(_$AppDatabase db, $WatchCatalogTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WatchCatalogTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WatchCatalogTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WatchCatalogTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> mediaKey = const Value.absent(),
                Value<String> data = const Value.absent(),
                Value<String> seasons = const Value.absent(),
                Value<bool> detailed = const Value.absent(),
                Value<double> popularity = const Value.absent(),
                Value<int> fetchedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WatchCatalogCompanion(
                mediaKey: mediaKey,
                data: data,
                seasons: seasons,
                detailed: detailed,
                popularity: popularity,
                fetchedAt: fetchedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String mediaKey,
                required String data,
                Value<String> seasons = const Value.absent(),
                Value<bool> detailed = const Value.absent(),
                Value<double> popularity = const Value.absent(),
                required int fetchedAt,
                Value<int> rowid = const Value.absent(),
              }) => WatchCatalogCompanion.insert(
                mediaKey: mediaKey,
                data: data,
                seasons: seasons,
                detailed: detailed,
                popularity: popularity,
                fetchedAt: fetchedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$WatchCatalogTable, WatchCatalogRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $WatchCatalogTable,
                    WatchCatalogRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$WatchCatalogTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WatchCatalogTable,
      WatchCatalogRow,
      $$WatchCatalogTableFilterComposer,
      $$WatchCatalogTableOrderingComposer,
      $$WatchCatalogTableAnnotationComposer,
      $$WatchCatalogTableCreateCompanionBuilder,
      $$WatchCatalogTableUpdateCompanionBuilder,
      (
        WatchCatalogRow,
        BaseReferences<_$AppDatabase, $WatchCatalogTable, WatchCatalogRow>,
      ),
      WatchCatalogRow,
      PrefetchHooks Function()
    >;
typedef $$WatchTitlesTableCreateCompanionBuilder =
    WatchTitlesCompanion Function({
      required String id,
      required String mediaKey,
      required String title,
      Value<String?> posterPath,
      Value<int?> year,
      Value<String?> status,
      Value<int?> rating,
      Value<String> note,
      Value<String?> swipe,
      Value<String?> matchState,
      Value<int?> matchedAt,
      Value<int?> expiresAt,
      Value<int?> nightAt,
      Value<String?> outcome,
      Value<int?> checkedInAt,
      Value<String> episodes,
      required int revision,
      required int createdAt,
      required int updatedAt,
      Value<int?> deletedAt,
      Value<int> rowid,
    });
typedef $$WatchTitlesTableUpdateCompanionBuilder =
    WatchTitlesCompanion Function({
      Value<String> id,
      Value<String> mediaKey,
      Value<String> title,
      Value<String?> posterPath,
      Value<int?> year,
      Value<String?> status,
      Value<int?> rating,
      Value<String> note,
      Value<String?> swipe,
      Value<String?> matchState,
      Value<int?> matchedAt,
      Value<int?> expiresAt,
      Value<int?> nightAt,
      Value<String?> outcome,
      Value<int?> checkedInAt,
      Value<String> episodes,
      Value<int> revision,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<int?> deletedAt,
      Value<int> rowid,
    });

class $$WatchTitlesTableFilterComposer
    extends Composer<_$AppDatabase, $WatchTitlesTable> {
  $$WatchTitlesTableFilterComposer({
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

  ColumnFilters<String> get mediaKey => $composableBuilder(
    column: $table.mediaKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get posterPath => $composableBuilder(
    column: $table.posterPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get year => $composableBuilder(
    column: $table.year,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get rating => $composableBuilder(
    column: $table.rating,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get swipe => $composableBuilder(
    column: $table.swipe,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get matchState => $composableBuilder(
    column: $table.matchState,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get matchedAt => $composableBuilder(
    column: $table.matchedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get nightAt => $composableBuilder(
    column: $table.nightAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get outcome => $composableBuilder(
    column: $table.outcome,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get checkedInAt => $composableBuilder(
    column: $table.checkedInAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get episodes => $composableBuilder(
    column: $table.episodes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$WatchTitlesTableOrderingComposer
    extends Composer<_$AppDatabase, $WatchTitlesTable> {
  $$WatchTitlesTableOrderingComposer({
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

  ColumnOrderings<String> get mediaKey => $composableBuilder(
    column: $table.mediaKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get posterPath => $composableBuilder(
    column: $table.posterPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get year => $composableBuilder(
    column: $table.year,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get rating => $composableBuilder(
    column: $table.rating,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get swipe => $composableBuilder(
    column: $table.swipe,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get matchState => $composableBuilder(
    column: $table.matchState,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get matchedAt => $composableBuilder(
    column: $table.matchedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get nightAt => $composableBuilder(
    column: $table.nightAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get outcome => $composableBuilder(
    column: $table.outcome,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get checkedInAt => $composableBuilder(
    column: $table.checkedInAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get episodes => $composableBuilder(
    column: $table.episodes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WatchTitlesTableAnnotationComposer
    extends Composer<_$AppDatabase, $WatchTitlesTable> {
  $$WatchTitlesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get mediaKey =>
      $composableBuilder(column: $table.mediaKey, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get posterPath => $composableBuilder(
    column: $table.posterPath,
    builder: (column) => column,
  );

  GeneratedColumn<int> get year =>
      $composableBuilder(column: $table.year, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get rating =>
      $composableBuilder(column: $table.rating, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<String> get swipe =>
      $composableBuilder(column: $table.swipe, builder: (column) => column);

  GeneratedColumn<String> get matchState => $composableBuilder(
    column: $table.matchState,
    builder: (column) => column,
  );

  GeneratedColumn<int> get matchedAt =>
      $composableBuilder(column: $table.matchedAt, builder: (column) => column);

  GeneratedColumn<int> get expiresAt =>
      $composableBuilder(column: $table.expiresAt, builder: (column) => column);

  GeneratedColumn<int> get nightAt =>
      $composableBuilder(column: $table.nightAt, builder: (column) => column);

  GeneratedColumn<String> get outcome =>
      $composableBuilder(column: $table.outcome, builder: (column) => column);

  GeneratedColumn<int> get checkedInAt => $composableBuilder(
    column: $table.checkedInAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get episodes =>
      $composableBuilder(column: $table.episodes, builder: (column) => column);

  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$WatchTitlesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WatchTitlesTable,
          WatchTitleRow,
          $$WatchTitlesTableFilterComposer,
          $$WatchTitlesTableOrderingComposer,
          $$WatchTitlesTableAnnotationComposer,
          $$WatchTitlesTableCreateCompanionBuilder,
          $$WatchTitlesTableUpdateCompanionBuilder,
          (
            WatchTitleRow,
            BaseReferences<_$AppDatabase, $WatchTitlesTable, WatchTitleRow>,
          ),
          WatchTitleRow,
          PrefetchHooks Function()
        > {
  $$WatchTitlesTableTableManager(_$AppDatabase db, $WatchTitlesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WatchTitlesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WatchTitlesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WatchTitlesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> mediaKey = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> posterPath = const Value.absent(),
                Value<int?> year = const Value.absent(),
                Value<String?> status = const Value.absent(),
                Value<int?> rating = const Value.absent(),
                Value<String> note = const Value.absent(),
                Value<String?> swipe = const Value.absent(),
                Value<String?> matchState = const Value.absent(),
                Value<int?> matchedAt = const Value.absent(),
                Value<int?> expiresAt = const Value.absent(),
                Value<int?> nightAt = const Value.absent(),
                Value<String?> outcome = const Value.absent(),
                Value<int?> checkedInAt = const Value.absent(),
                Value<String> episodes = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WatchTitlesCompanion(
                id: id,
                mediaKey: mediaKey,
                title: title,
                posterPath: posterPath,
                year: year,
                status: status,
                rating: rating,
                note: note,
                swipe: swipe,
                matchState: matchState,
                matchedAt: matchedAt,
                expiresAt: expiresAt,
                nightAt: nightAt,
                outcome: outcome,
                checkedInAt: checkedInAt,
                episodes: episodes,
                revision: revision,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String mediaKey,
                required String title,
                Value<String?> posterPath = const Value.absent(),
                Value<int?> year = const Value.absent(),
                Value<String?> status = const Value.absent(),
                Value<int?> rating = const Value.absent(),
                Value<String> note = const Value.absent(),
                Value<String?> swipe = const Value.absent(),
                Value<String?> matchState = const Value.absent(),
                Value<int?> matchedAt = const Value.absent(),
                Value<int?> expiresAt = const Value.absent(),
                Value<int?> nightAt = const Value.absent(),
                Value<String?> outcome = const Value.absent(),
                Value<int?> checkedInAt = const Value.absent(),
                Value<String> episodes = const Value.absent(),
                required int revision,
                required int createdAt,
                required int updatedAt,
                Value<int?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WatchTitlesCompanion.insert(
                id: id,
                mediaKey: mediaKey,
                title: title,
                posterPath: posterPath,
                year: year,
                status: status,
                rating: rating,
                note: note,
                swipe: swipe,
                matchState: matchState,
                matchedAt: matchedAt,
                expiresAt: expiresAt,
                nightAt: nightAt,
                outcome: outcome,
                checkedInAt: checkedInAt,
                episodes: episodes,
                revision: revision,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$WatchTitlesTable, WatchTitleRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $WatchTitlesTable,
                    WatchTitleRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$WatchTitlesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WatchTitlesTable,
      WatchTitleRow,
      $$WatchTitlesTableFilterComposer,
      $$WatchTitlesTableOrderingComposer,
      $$WatchTitlesTableAnnotationComposer,
      $$WatchTitlesTableCreateCompanionBuilder,
      $$WatchTitlesTableUpdateCompanionBuilder,
      (
        WatchTitleRow,
        BaseReferences<_$AppDatabase, $WatchTitlesTable, WatchTitleRow>,
      ),
      WatchTitleRow,
      PrefetchHooks Function()
    >;
typedef $$WatchListsTableCreateCompanionBuilder = WatchListsCompanion Function({
  required String id,
  required String name,
  Value<String> items,
  required int revision,
  required int createdAt,
  required int updatedAt,
  Value<int?> deletedAt,
  Value<int> rowid,
});
typedef $$WatchListsTableUpdateCompanionBuilder = WatchListsCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<String> items,
  Value<int> revision,
  Value<int> createdAt,
  Value<int> updatedAt,
  Value<int?> deletedAt,
  Value<int> rowid,
});

class $$WatchListsTableFilterComposer
    extends Composer<_$AppDatabase, $WatchListsTable> {
  $$WatchListsTableFilterComposer({
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

  ColumnFilters<String> get items => $composableBuilder(
    column: $table.items,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$WatchListsTableOrderingComposer
    extends Composer<_$AppDatabase, $WatchListsTable> {
  $$WatchListsTableOrderingComposer({
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

  ColumnOrderings<String> get items => $composableBuilder(
    column: $table.items,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WatchListsTableAnnotationComposer
    extends Composer<_$AppDatabase, $WatchListsTable> {
  $$WatchListsTableAnnotationComposer({
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

  GeneratedColumn<String> get items =>
      $composableBuilder(column: $table.items, builder: (column) => column);

  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$WatchListsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WatchListsTable,
          WatchListRow,
          $$WatchListsTableFilterComposer,
          $$WatchListsTableOrderingComposer,
          $$WatchListsTableAnnotationComposer,
          $$WatchListsTableCreateCompanionBuilder,
          $$WatchListsTableUpdateCompanionBuilder,
          (
            WatchListRow,
            BaseReferences<_$AppDatabase, $WatchListsTable, WatchListRow>,
          ),
          WatchListRow,
          PrefetchHooks Function()
        > {
  $$WatchListsTableTableManager(_$AppDatabase db, $WatchListsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WatchListsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WatchListsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WatchListsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> items = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WatchListsCompanion(
                id: id,
                name: name,
                items: items,
                revision: revision,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<String> items = const Value.absent(),
                required int revision,
                required int createdAt,
                required int updatedAt,
                Value<int?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WatchListsCompanion.insert(
                id: id,
                name: name,
                items: items,
                revision: revision,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$WatchListsTable, WatchListRow>(table),
                  BaseReferences<_$AppDatabase, $WatchListsTable, WatchListRow>(
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

typedef $$WatchListsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WatchListsTable,
      WatchListRow,
      $$WatchListsTableFilterComposer,
      $$WatchListsTableOrderingComposer,
      $$WatchListsTableAnnotationComposer,
      $$WatchListsTableCreateCompanionBuilder,
      $$WatchListsTableUpdateCompanionBuilder,
      (
        WatchListRow,
        BaseReferences<_$AppDatabase, $WatchListsTable, WatchListRow>,
      ),
      WatchListRow,
      PrefetchHooks Function()
    >;
typedef $$WatchProfilesTableCreateCompanionBuilder =
    WatchProfilesCompanion Function({
      required String id,
      Value<String> state,
      required int revision,
      required int createdAt,
      required int updatedAt,
      Value<int?> deletedAt,
      Value<int> rowid,
    });
typedef $$WatchProfilesTableUpdateCompanionBuilder =
    WatchProfilesCompanion Function({
      Value<String> id,
      Value<String> state,
      Value<int> revision,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<int?> deletedAt,
      Value<int> rowid,
    });

class $$WatchProfilesTableFilterComposer
    extends Composer<_$AppDatabase, $WatchProfilesTable> {
  $$WatchProfilesTableFilterComposer({
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

  ColumnFilters<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$WatchProfilesTableOrderingComposer
    extends Composer<_$AppDatabase, $WatchProfilesTable> {
  $$WatchProfilesTableOrderingComposer({
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

  ColumnOrderings<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WatchProfilesTableAnnotationComposer
    extends Composer<_$AppDatabase, $WatchProfilesTable> {
  $$WatchProfilesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$WatchProfilesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WatchProfilesTable,
          WatchProfileRow,
          $$WatchProfilesTableFilterComposer,
          $$WatchProfilesTableOrderingComposer,
          $$WatchProfilesTableAnnotationComposer,
          $$WatchProfilesTableCreateCompanionBuilder,
          $$WatchProfilesTableUpdateCompanionBuilder,
          (
            WatchProfileRow,
            BaseReferences<_$AppDatabase, $WatchProfilesTable, WatchProfileRow>,
          ),
          WatchProfileRow,
          PrefetchHooks Function()
        > {
  $$WatchProfilesTableTableManager(_$AppDatabase db, $WatchProfilesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WatchProfilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WatchProfilesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WatchProfilesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WatchProfilesCompanion(
                id: id,
                state: state,
                revision: revision,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String> state = const Value.absent(),
                required int revision,
                required int createdAt,
                required int updatedAt,
                Value<int?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WatchProfilesCompanion.insert(
                id: id,
                state: state,
                revision: revision,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$WatchProfilesTable, WatchProfileRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $WatchProfilesTable,
                    WatchProfileRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$WatchProfilesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WatchProfilesTable,
      WatchProfileRow,
      $$WatchProfilesTableFilterComposer,
      $$WatchProfilesTableOrderingComposer,
      $$WatchProfilesTableAnnotationComposer,
      $$WatchProfilesTableCreateCompanionBuilder,
      $$WatchProfilesTableUpdateCompanionBuilder,
      (
        WatchProfileRow,
        BaseReferences<_$AppDatabase, $WatchProfilesTable, WatchProfileRow>,
      ),
      WatchProfileRow,
      PrefetchHooks Function()
    >;
typedef $$WatchChatTurnsTableCreateCompanionBuilder =
    WatchChatTurnsCompanion Function({
      required String id,
      required String titleId,
      required int at,
      required bool fromReader,
      required String body,
      Value<int> rowid,
    });
typedef $$WatchChatTurnsTableUpdateCompanionBuilder =
    WatchChatTurnsCompanion Function({
      Value<String> id,
      Value<String> titleId,
      Value<int> at,
      Value<bool> fromReader,
      Value<String> body,
      Value<int> rowid,
    });

class $$WatchChatTurnsTableFilterComposer
    extends Composer<_$AppDatabase, $WatchChatTurnsTable> {
  $$WatchChatTurnsTableFilterComposer({
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

  ColumnFilters<String> get titleId => $composableBuilder(
    column: $table.titleId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get at => $composableBuilder(
    column: $table.at,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get fromReader => $composableBuilder(
    column: $table.fromReader,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnFilters(column),
  );
}

class $$WatchChatTurnsTableOrderingComposer
    extends Composer<_$AppDatabase, $WatchChatTurnsTable> {
  $$WatchChatTurnsTableOrderingComposer({
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

  ColumnOrderings<String> get titleId => $composableBuilder(
    column: $table.titleId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get at => $composableBuilder(
    column: $table.at,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get fromReader => $composableBuilder(
    column: $table.fromReader,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WatchChatTurnsTableAnnotationComposer
    extends Composer<_$AppDatabase, $WatchChatTurnsTable> {
  $$WatchChatTurnsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get titleId =>
      $composableBuilder(column: $table.titleId, builder: (column) => column);

  GeneratedColumn<int> get at =>
      $composableBuilder(column: $table.at, builder: (column) => column);

  GeneratedColumn<bool> get fromReader => $composableBuilder(
    column: $table.fromReader,
    builder: (column) => column,
  );

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);
}

class $$WatchChatTurnsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WatchChatTurnsTable,
          WatchChatTurnRow,
          $$WatchChatTurnsTableFilterComposer,
          $$WatchChatTurnsTableOrderingComposer,
          $$WatchChatTurnsTableAnnotationComposer,
          $$WatchChatTurnsTableCreateCompanionBuilder,
          $$WatchChatTurnsTableUpdateCompanionBuilder,
          (
            WatchChatTurnRow,
            BaseReferences<
              _$AppDatabase,
              $WatchChatTurnsTable,
              WatchChatTurnRow
            >,
          ),
          WatchChatTurnRow,
          PrefetchHooks Function()
        > {
  $$WatchChatTurnsTableTableManager(
    _$AppDatabase db,
    $WatchChatTurnsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WatchChatTurnsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WatchChatTurnsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WatchChatTurnsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> titleId = const Value.absent(),
                Value<int> at = const Value.absent(),
                Value<bool> fromReader = const Value.absent(),
                Value<String> body = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WatchChatTurnsCompanion(
                id: id,
                titleId: titleId,
                at: at,
                fromReader: fromReader,
                body: body,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String titleId,
                required int at,
                required bool fromReader,
                required String body,
                Value<int> rowid = const Value.absent(),
              }) => WatchChatTurnsCompanion.insert(
                id: id,
                titleId: titleId,
                at: at,
                fromReader: fromReader,
                body: body,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$WatchChatTurnsTable, WatchChatTurnRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $WatchChatTurnsTable,
                    WatchChatTurnRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$WatchChatTurnsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WatchChatTurnsTable,
      WatchChatTurnRow,
      $$WatchChatTurnsTableFilterComposer,
      $$WatchChatTurnsTableOrderingComposer,
      $$WatchChatTurnsTableAnnotationComposer,
      $$WatchChatTurnsTableCreateCompanionBuilder,
      $$WatchChatTurnsTableUpdateCompanionBuilder,
      (
        WatchChatTurnRow,
        BaseReferences<_$AppDatabase, $WatchChatTurnsTable, WatchChatTurnRow>,
      ),
      WatchChatTurnRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$AiUsageMonthsTableTableManager get aiUsageMonths =>
      $$AiUsageMonthsTableTableManager(_db, _db.aiUsageMonths);
  $$AppearanceSettingsTableTableManager get appearanceSettings =>
      $$AppearanceSettingsTableTableManager(_db, _db.appearanceSettings);
  $$OnboardingCompletionTableTableManager get onboardingCompletion =>
      $$OnboardingCompletionTableTableManager(_db, _db.onboardingCompletion);
  $$NotesTableTableManager get notes =>
      $$NotesTableTableManager(_db, _db.notes);
  $$NoteTagsTableTableManager get noteTags =>
      $$NoteTagsTableTableManager(_db, _db.noteTags);
  $$NoteMediaOpsTableTableManager get noteMediaOps =>
      $$NoteMediaOpsTableTableManager(_db, _db.noteMediaOps);
  $$NoteWebsitesTableTableManager get noteWebsites =>
      $$NoteWebsitesTableTableManager(_db, _db.noteWebsites);
  $$NoteChatTurnsTableTableManager get noteChatTurns =>
      $$NoteChatTurnsTableTableManager(_db, _db.noteChatTurns);
  $$DiaryEntriesTableTableManager get diaryEntries =>
      $$DiaryEntriesTableTableManager(_db, _db.diaryEntries);
  $$DiaryDaysTableTableManager get diaryDays =>
      $$DiaryDaysTableTableManager(_db, _db.diaryDays);
  $$DiaryMediaOpsTableTableManager get diaryMediaOps =>
      $$DiaryMediaOpsTableTableManager(_db, _db.diaryMediaOps);
  $$DiarySearchHistoryTableTableManager get diarySearchHistory =>
      $$DiarySearchHistoryTableTableManager(_db, _db.diarySearchHistory);
  $$WatchCatalogTableTableManager get watchCatalog =>
      $$WatchCatalogTableTableManager(_db, _db.watchCatalog);
  $$WatchTitlesTableTableManager get watchTitles =>
      $$WatchTitlesTableTableManager(_db, _db.watchTitles);
  $$WatchListsTableTableManager get watchLists =>
      $$WatchListsTableTableManager(_db, _db.watchLists);
  $$WatchProfilesTableTableManager get watchProfiles =>
      $$WatchProfilesTableTableManager(_db, _db.watchProfiles);
  $$WatchChatTurnsTableTableManager get watchChatTurns =>
      $$WatchChatTurnsTableTableManager(_db, _db.watchChatTurns);
}
