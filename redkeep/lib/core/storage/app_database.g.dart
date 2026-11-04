// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $AiPreferencesTableTable extends AiPreferencesTable
    with TableInfo<$AiPreferencesTableTable, AiPreferenceRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AiPreferencesTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _modeMeta = const VerificationMeta('mode');
  @override
  late final GeneratedColumn<String> mode = GeneratedColumn<String>(
    'mode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('auto'),
  );
  static const VerificationMeta _overridesMeta = const VerificationMeta(
    'overrides',
  );
  @override
  late final GeneratedColumn<String> overrides = GeneratedColumn<String>(
    'overrides',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  static const VerificationMeta _dailyQuestionsMeta = const VerificationMeta(
    'dailyQuestions',
  );
  @override
  late final GeneratedColumn<bool> dailyQuestions = GeneratedColumn<bool>(
    'daily_questions',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("daily_questions" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _recallNotesMeta = const VerificationMeta(
    'recallNotes',
  );
  @override
  late final GeneratedColumn<bool> recallNotes = GeneratedColumn<bool>(
    'recall_notes',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("recall_notes" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _recallDiaryMeta = const VerificationMeta(
    'recallDiary',
  );
  @override
  late final GeneratedColumn<bool> recallDiary = GeneratedColumn<bool>(
    'recall_diary',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("recall_diary" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _recallFlowMeta = const VerificationMeta(
    'recallFlow',
  );
  @override
  late final GeneratedColumn<bool> recallFlow = GeneratedColumn<bool>(
    'recall_flow',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("recall_flow" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _recallPausedMeta = const VerificationMeta(
    'recallPaused',
  );
  @override
  late final GeneratedColumn<bool> recallPaused = GeneratedColumn<bool>(
    'recall_paused',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("recall_paused" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _recallCleanupRequiredMeta =
      const VerificationMeta('recallCleanupRequired');
  @override
  late final GeneratedColumn<bool> recallCleanupRequired =
      GeneratedColumn<bool>(
        'recall_cleanup_required',
        aliasedName,
        false,
        type: DriftSqlType.bool,
        requiredDuringInsert: false,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("recall_cleanup_required" IN (0, 1))',
        ),
        defaultValue: const Constant(false),
      );
  static const VerificationMeta _replyVoiceMeta = const VerificationMeta(
    'replyVoice',
  );
  @override
  late final GeneratedColumn<String> replyVoice = GeneratedColumn<String>(
    'reply_voice',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    mode,
    overrides,
    dailyQuestions,
    recallNotes,
    recallDiary,
    recallFlow,
    recallPaused,
    recallCleanupRequired,
    replyVoice,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ai_preferences_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<AiPreferenceRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('mode')) {
      context.handle(
        _modeMeta,
        mode.isAcceptableOrUnknown(data['mode']!, _modeMeta),
      );
    }
    if (data.containsKey('overrides')) {
      context.handle(
        _overridesMeta,
        overrides.isAcceptableOrUnknown(data['overrides']!, _overridesMeta),
      );
    }
    if (data.containsKey('daily_questions')) {
      context.handle(
        _dailyQuestionsMeta,
        dailyQuestions.isAcceptableOrUnknown(
          data['daily_questions']!,
          _dailyQuestionsMeta,
        ),
      );
    }
    if (data.containsKey('recall_notes')) {
      context.handle(
        _recallNotesMeta,
        recallNotes.isAcceptableOrUnknown(
          data['recall_notes']!,
          _recallNotesMeta,
        ),
      );
    }
    if (data.containsKey('recall_diary')) {
      context.handle(
        _recallDiaryMeta,
        recallDiary.isAcceptableOrUnknown(
          data['recall_diary']!,
          _recallDiaryMeta,
        ),
      );
    }
    if (data.containsKey('recall_flow')) {
      context.handle(
        _recallFlowMeta,
        recallFlow.isAcceptableOrUnknown(data['recall_flow']!, _recallFlowMeta),
      );
    }
    if (data.containsKey('recall_paused')) {
      context.handle(
        _recallPausedMeta,
        recallPaused.isAcceptableOrUnknown(
          data['recall_paused']!,
          _recallPausedMeta,
        ),
      );
    }
    if (data.containsKey('recall_cleanup_required')) {
      context.handle(
        _recallCleanupRequiredMeta,
        recallCleanupRequired.isAcceptableOrUnknown(
          data['recall_cleanup_required']!,
          _recallCleanupRequiredMeta,
        ),
      );
    }
    if (data.containsKey('reply_voice')) {
      context.handle(
        _replyVoiceMeta,
        replyVoice.isAcceptableOrUnknown(data['reply_voice']!, _replyVoiceMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AiPreferenceRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AiPreferenceRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      mode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mode'],
      )!,
      overrides: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}overrides'],
      )!,
      dailyQuestions: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}daily_questions'],
      )!,
      recallNotes: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}recall_notes'],
      )!,
      recallDiary: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}recall_diary'],
      )!,
      recallFlow: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}recall_flow'],
      )!,
      recallPaused: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}recall_paused'],
      )!,
      recallCleanupRequired: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}recall_cleanup_required'],
      )!,
      replyVoice: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reply_voice'],
      ),
    );
  }

  @override
  $AiPreferencesTableTable createAlias(String alias) {
    return $AiPreferencesTableTable(attachedDatabase, alias);
  }
}

class AiPreferenceRow extends DataClass implements Insertable<AiPreferenceRow> {
  final int id;
  final String mode;
  final String overrides;
  final bool dailyQuestions;
  final bool recallNotes;
  final bool recallDiary;
  final bool recallFlow;
  final bool recallPaused;
  final bool recallCleanupRequired;
  final String? replyVoice;
  const AiPreferenceRow({
    required this.id,
    required this.mode,
    required this.overrides,
    required this.dailyQuestions,
    required this.recallNotes,
    required this.recallDiary,
    required this.recallFlow,
    required this.recallPaused,
    required this.recallCleanupRequired,
    this.replyVoice,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['mode'] = Variable<String>(mode);
    map['overrides'] = Variable<String>(overrides);
    map['daily_questions'] = Variable<bool>(dailyQuestions);
    map['recall_notes'] = Variable<bool>(recallNotes);
    map['recall_diary'] = Variable<bool>(recallDiary);
    map['recall_flow'] = Variable<bool>(recallFlow);
    map['recall_paused'] = Variable<bool>(recallPaused);
    map['recall_cleanup_required'] = Variable<bool>(recallCleanupRequired);
    if (!nullToAbsent || replyVoice != null) {
      map['reply_voice'] = Variable<String>(replyVoice);
    }
    return map;
  }

  AiPreferencesTableCompanion toCompanion(bool nullToAbsent) {
    return AiPreferencesTableCompanion(
      id: Value(id),
      mode: Value(mode),
      overrides: Value(overrides),
      dailyQuestions: Value(dailyQuestions),
      recallNotes: Value(recallNotes),
      recallDiary: Value(recallDiary),
      recallFlow: Value(recallFlow),
      recallPaused: Value(recallPaused),
      recallCleanupRequired: Value(recallCleanupRequired),
      replyVoice: replyVoice == null && nullToAbsent
          ? const Value.absent()
          : Value(replyVoice),
    );
  }

  factory AiPreferenceRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AiPreferenceRow(
      id: serializer.fromJson<int>(json['id']),
      mode: serializer.fromJson<String>(json['mode']),
      overrides: serializer.fromJson<String>(json['overrides']),
      dailyQuestions: serializer.fromJson<bool>(json['dailyQuestions']),
      recallNotes: serializer.fromJson<bool>(json['recallNotes']),
      recallDiary: serializer.fromJson<bool>(json['recallDiary']),
      recallFlow: serializer.fromJson<bool>(json['recallFlow']),
      recallPaused: serializer.fromJson<bool>(json['recallPaused']),
      recallCleanupRequired: serializer.fromJson<bool>(
        json['recallCleanupRequired'],
      ),
      replyVoice: serializer.fromJson<String?>(json['replyVoice']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'mode': serializer.toJson<String>(mode),
      'overrides': serializer.toJson<String>(overrides),
      'dailyQuestions': serializer.toJson<bool>(dailyQuestions),
      'recallNotes': serializer.toJson<bool>(recallNotes),
      'recallDiary': serializer.toJson<bool>(recallDiary),
      'recallFlow': serializer.toJson<bool>(recallFlow),
      'recallPaused': serializer.toJson<bool>(recallPaused),
      'recallCleanupRequired': serializer.toJson<bool>(recallCleanupRequired),
      'replyVoice': serializer.toJson<String?>(replyVoice),
    };
  }

  AiPreferenceRow copyWith({
    int? id,
    String? mode,
    String? overrides,
    bool? dailyQuestions,
    bool? recallNotes,
    bool? recallDiary,
    bool? recallFlow,
    bool? recallPaused,
    bool? recallCleanupRequired,
    Value<String?> replyVoice = const Value.absent(),
  }) => AiPreferenceRow(
    id: id ?? this.id,
    mode: mode ?? this.mode,
    overrides: overrides ?? this.overrides,
    dailyQuestions: dailyQuestions ?? this.dailyQuestions,
    recallNotes: recallNotes ?? this.recallNotes,
    recallDiary: recallDiary ?? this.recallDiary,
    recallFlow: recallFlow ?? this.recallFlow,
    recallPaused: recallPaused ?? this.recallPaused,
    recallCleanupRequired: recallCleanupRequired ?? this.recallCleanupRequired,
    replyVoice: replyVoice.present ? replyVoice.value : this.replyVoice,
  );
  AiPreferenceRow copyWithCompanion(AiPreferencesTableCompanion data) {
    return AiPreferenceRow(
      id: data.id.present ? data.id.value : this.id,
      mode: data.mode.present ? data.mode.value : this.mode,
      overrides: data.overrides.present ? data.overrides.value : this.overrides,
      dailyQuestions: data.dailyQuestions.present
          ? data.dailyQuestions.value
          : this.dailyQuestions,
      recallNotes: data.recallNotes.present
          ? data.recallNotes.value
          : this.recallNotes,
      recallDiary: data.recallDiary.present
          ? data.recallDiary.value
          : this.recallDiary,
      recallFlow: data.recallFlow.present
          ? data.recallFlow.value
          : this.recallFlow,
      recallPaused: data.recallPaused.present
          ? data.recallPaused.value
          : this.recallPaused,
      recallCleanupRequired: data.recallCleanupRequired.present
          ? data.recallCleanupRequired.value
          : this.recallCleanupRequired,
      replyVoice: data.replyVoice.present
          ? data.replyVoice.value
          : this.replyVoice,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AiPreferenceRow(')
          ..write('id: $id, ')
          ..write('mode: $mode, ')
          ..write('overrides: $overrides, ')
          ..write('dailyQuestions: $dailyQuestions, ')
          ..write('recallNotes: $recallNotes, ')
          ..write('recallDiary: $recallDiary, ')
          ..write('recallFlow: $recallFlow, ')
          ..write('recallPaused: $recallPaused, ')
          ..write('recallCleanupRequired: $recallCleanupRequired, ')
          ..write('replyVoice: $replyVoice')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    mode,
    overrides,
    dailyQuestions,
    recallNotes,
    recallDiary,
    recallFlow,
    recallPaused,
    recallCleanupRequired,
    replyVoice,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AiPreferenceRow &&
          other.id == this.id &&
          other.mode == this.mode &&
          other.overrides == this.overrides &&
          other.dailyQuestions == this.dailyQuestions &&
          other.recallNotes == this.recallNotes &&
          other.recallDiary == this.recallDiary &&
          other.recallFlow == this.recallFlow &&
          other.recallPaused == this.recallPaused &&
          other.recallCleanupRequired == this.recallCleanupRequired &&
          other.replyVoice == this.replyVoice);
}

class AiPreferencesTableCompanion extends UpdateCompanion<AiPreferenceRow> {
  final Value<int> id;
  final Value<String> mode;
  final Value<String> overrides;
  final Value<bool> dailyQuestions;
  final Value<bool> recallNotes;
  final Value<bool> recallDiary;
  final Value<bool> recallFlow;
  final Value<bool> recallPaused;
  final Value<bool> recallCleanupRequired;
  final Value<String?> replyVoice;
  const AiPreferencesTableCompanion({
    this.id = const Value.absent(),
    this.mode = const Value.absent(),
    this.overrides = const Value.absent(),
    this.dailyQuestions = const Value.absent(),
    this.recallNotes = const Value.absent(),
    this.recallDiary = const Value.absent(),
    this.recallFlow = const Value.absent(),
    this.recallPaused = const Value.absent(),
    this.recallCleanupRequired = const Value.absent(),
    this.replyVoice = const Value.absent(),
  });
  AiPreferencesTableCompanion.insert({
    this.id = const Value.absent(),
    this.mode = const Value.absent(),
    this.overrides = const Value.absent(),
    this.dailyQuestions = const Value.absent(),
    this.recallNotes = const Value.absent(),
    this.recallDiary = const Value.absent(),
    this.recallFlow = const Value.absent(),
    this.recallPaused = const Value.absent(),
    this.recallCleanupRequired = const Value.absent(),
    this.replyVoice = const Value.absent(),
  });
  static Insertable<AiPreferenceRow> custom({
    Expression<int>? id,
    Expression<String>? mode,
    Expression<String>? overrides,
    Expression<bool>? dailyQuestions,
    Expression<bool>? recallNotes,
    Expression<bool>? recallDiary,
    Expression<bool>? recallFlow,
    Expression<bool>? recallPaused,
    Expression<bool>? recallCleanupRequired,
    Expression<String>? replyVoice,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (mode != null) 'mode': mode,
      if (overrides != null) 'overrides': overrides,
      if (dailyQuestions != null) 'daily_questions': dailyQuestions,
      if (recallNotes != null) 'recall_notes': recallNotes,
      if (recallDiary != null) 'recall_diary': recallDiary,
      if (recallFlow != null) 'recall_flow': recallFlow,
      if (recallPaused != null) 'recall_paused': recallPaused,
      if (recallCleanupRequired != null)
        'recall_cleanup_required': recallCleanupRequired,
      if (replyVoice != null) 'reply_voice': replyVoice,
    });
  }

  AiPreferencesTableCompanion copyWith({
    Value<int>? id,
    Value<String>? mode,
    Value<String>? overrides,
    Value<bool>? dailyQuestions,
    Value<bool>? recallNotes,
    Value<bool>? recallDiary,
    Value<bool>? recallFlow,
    Value<bool>? recallPaused,
    Value<bool>? recallCleanupRequired,
    Value<String?>? replyVoice,
  }) {
    return AiPreferencesTableCompanion(
      id: id ?? this.id,
      mode: mode ?? this.mode,
      overrides: overrides ?? this.overrides,
      dailyQuestions: dailyQuestions ?? this.dailyQuestions,
      recallNotes: recallNotes ?? this.recallNotes,
      recallDiary: recallDiary ?? this.recallDiary,
      recallFlow: recallFlow ?? this.recallFlow,
      recallPaused: recallPaused ?? this.recallPaused,
      recallCleanupRequired:
          recallCleanupRequired ?? this.recallCleanupRequired,
      replyVoice: replyVoice ?? this.replyVoice,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (mode.present) {
      map['mode'] = Variable<String>(mode.value);
    }
    if (overrides.present) {
      map['overrides'] = Variable<String>(overrides.value);
    }
    if (dailyQuestions.present) {
      map['daily_questions'] = Variable<bool>(dailyQuestions.value);
    }
    if (recallNotes.present) {
      map['recall_notes'] = Variable<bool>(recallNotes.value);
    }
    if (recallDiary.present) {
      map['recall_diary'] = Variable<bool>(recallDiary.value);
    }
    if (recallFlow.present) {
      map['recall_flow'] = Variable<bool>(recallFlow.value);
    }
    if (recallPaused.present) {
      map['recall_paused'] = Variable<bool>(recallPaused.value);
    }
    if (recallCleanupRequired.present) {
      map['recall_cleanup_required'] = Variable<bool>(
        recallCleanupRequired.value,
      );
    }
    if (replyVoice.present) {
      map['reply_voice'] = Variable<String>(replyVoice.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AiPreferencesTableCompanion(')
          ..write('id: $id, ')
          ..write('mode: $mode, ')
          ..write('overrides: $overrides, ')
          ..write('dailyQuestions: $dailyQuestions, ')
          ..write('recallNotes: $recallNotes, ')
          ..write('recallDiary: $recallDiary, ')
          ..write('recallFlow: $recallFlow, ')
          ..write('recallPaused: $recallPaused, ')
          ..write('recallCleanupRequired: $recallCleanupRequired, ')
          ..write('replyVoice: $replyVoice')
          ..write(')'))
        .toString();
  }
}

class $AiJobReceiptsTable extends AiJobReceipts
    with TableInfo<$AiJobReceiptsTable, AiJobReceiptRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AiJobReceiptsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _metadataMeta = const VerificationMeta(
    'metadata',
  );
  @override
  late final GeneratedColumn<String> metadata = GeneratedColumn<String>(
    'metadata',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _activeMeta = const VerificationMeta('active');
  @override
  late final GeneratedColumn<bool> active = GeneratedColumn<bool>(
    'active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("active" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
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
  List<GeneratedColumn> get $columns => [id, metadata, active, created];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ai_job_receipts';
  @override
  VerificationContext validateIntegrity(
    Insertable<AiJobReceiptRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('metadata')) {
      context.handle(
        _metadataMeta,
        metadata.isAcceptableOrUnknown(data['metadata']!, _metadataMeta),
      );
    } else if (isInserting) {
      context.missing(_metadataMeta);
    }
    if (data.containsKey('active')) {
      context.handle(
        _activeMeta,
        active.isAcceptableOrUnknown(data['active']!, _activeMeta),
      );
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
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AiJobReceiptRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AiJobReceiptRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      metadata: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}metadata'],
      )!,
      active: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}active'],
      )!,
      created: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created'],
      )!,
    );
  }

  @override
  $AiJobReceiptsTable createAlias(String alias) {
    return $AiJobReceiptsTable(attachedDatabase, alias);
  }
}

class AiJobReceiptRow extends DataClass implements Insertable<AiJobReceiptRow> {
  final String id;
  final String metadata;
  final bool active;
  final int created;
  const AiJobReceiptRow({
    required this.id,
    required this.metadata,
    required this.active,
    required this.created,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['metadata'] = Variable<String>(metadata);
    map['active'] = Variable<bool>(active);
    map['created'] = Variable<int>(created);
    return map;
  }

  AiJobReceiptsCompanion toCompanion(bool nullToAbsent) {
    return AiJobReceiptsCompanion(
      id: Value(id),
      metadata: Value(metadata),
      active: Value(active),
      created: Value(created),
    );
  }

  factory AiJobReceiptRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AiJobReceiptRow(
      id: serializer.fromJson<String>(json['id']),
      metadata: serializer.fromJson<String>(json['metadata']),
      active: serializer.fromJson<bool>(json['active']),
      created: serializer.fromJson<int>(json['created']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'metadata': serializer.toJson<String>(metadata),
      'active': serializer.toJson<bool>(active),
      'created': serializer.toJson<int>(created),
    };
  }

  AiJobReceiptRow copyWith({
    String? id,
    String? metadata,
    bool? active,
    int? created,
  }) => AiJobReceiptRow(
    id: id ?? this.id,
    metadata: metadata ?? this.metadata,
    active: active ?? this.active,
    created: created ?? this.created,
  );
  AiJobReceiptRow copyWithCompanion(AiJobReceiptsCompanion data) {
    return AiJobReceiptRow(
      id: data.id.present ? data.id.value : this.id,
      metadata: data.metadata.present ? data.metadata.value : this.metadata,
      active: data.active.present ? data.active.value : this.active,
      created: data.created.present ? data.created.value : this.created,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AiJobReceiptRow(')
          ..write('id: $id, ')
          ..write('metadata: $metadata, ')
          ..write('active: $active, ')
          ..write('created: $created')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, metadata, active, created);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AiJobReceiptRow &&
          other.id == this.id &&
          other.metadata == this.metadata &&
          other.active == this.active &&
          other.created == this.created);
}

class AiJobReceiptsCompanion extends UpdateCompanion<AiJobReceiptRow> {
  final Value<String> id;
  final Value<String> metadata;
  final Value<bool> active;
  final Value<int> created;
  final Value<int> rowid;
  const AiJobReceiptsCompanion({
    this.id = const Value.absent(),
    this.metadata = const Value.absent(),
    this.active = const Value.absent(),
    this.created = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AiJobReceiptsCompanion.insert({
    required String id,
    required String metadata,
    this.active = const Value.absent(),
    required int created,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       metadata = Value(metadata),
       created = Value(created);
  static Insertable<AiJobReceiptRow> custom({
    Expression<String>? id,
    Expression<String>? metadata,
    Expression<bool>? active,
    Expression<int>? created,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (metadata != null) 'metadata': metadata,
      if (active != null) 'active': active,
      if (created != null) 'created': created,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AiJobReceiptsCompanion copyWith({
    Value<String>? id,
    Value<String>? metadata,
    Value<bool>? active,
    Value<int>? created,
    Value<int>? rowid,
  }) {
    return AiJobReceiptsCompanion(
      id: id ?? this.id,
      metadata: metadata ?? this.metadata,
      active: active ?? this.active,
      created: created ?? this.created,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (metadata.present) {
      map['metadata'] = Variable<String>(metadata.value);
    }
    if (active.present) {
      map['active'] = Variable<bool>(active.value);
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
    return (StringBuffer('AiJobReceiptsCompanion(')
          ..write('id: $id, ')
          ..write('metadata: $metadata, ')
          ..write('active: $active, ')
          ..write('created: $created, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RecallQueueTable extends RecallQueue
    with TableInfo<$RecallQueueTable, RecallQueueRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RecallQueueTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceIdMeta = const VerificationMeta(
    'sourceId',
  );
  @override
  late final GeneratedColumn<String> sourceId = GeneratedColumn<String>(
    'source_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _generationMeta = const VerificationMeta(
    'generation',
  );
  @override
  late final GeneratedColumn<int> generation = GeneratedColumn<int>(
    'generation',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  @override
  List<GeneratedColumn> get $columns => [kind, sourceId, generation];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'recall_queue';
  @override
  VerificationContext validateIntegrity(
    Insertable<RecallQueueRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('source_id')) {
      context.handle(
        _sourceIdMeta,
        sourceId.isAcceptableOrUnknown(data['source_id']!, _sourceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceIdMeta);
    }
    if (data.containsKey('generation')) {
      context.handle(
        _generationMeta,
        generation.isAcceptableOrUnknown(data['generation']!, _generationMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {kind, sourceId};
  @override
  RecallQueueRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RecallQueueRow(
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      sourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_id'],
      )!,
      generation: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}generation'],
      )!,
    );
  }

  @override
  $RecallQueueTable createAlias(String alias) {
    return $RecallQueueTable(attachedDatabase, alias);
  }
}

class RecallQueueRow extends DataClass implements Insertable<RecallQueueRow> {
  final String kind;
  final String sourceId;
  final int generation;
  const RecallQueueRow({
    required this.kind,
    required this.sourceId,
    required this.generation,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['kind'] = Variable<String>(kind);
    map['source_id'] = Variable<String>(sourceId);
    map['generation'] = Variable<int>(generation);
    return map;
  }

  RecallQueueCompanion toCompanion(bool nullToAbsent) {
    return RecallQueueCompanion(
      kind: Value(kind),
      sourceId: Value(sourceId),
      generation: Value(generation),
    );
  }

  factory RecallQueueRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RecallQueueRow(
      kind: serializer.fromJson<String>(json['kind']),
      sourceId: serializer.fromJson<String>(json['sourceId']),
      generation: serializer.fromJson<int>(json['generation']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'kind': serializer.toJson<String>(kind),
      'sourceId': serializer.toJson<String>(sourceId),
      'generation': serializer.toJson<int>(generation),
    };
  }

  RecallQueueRow copyWith({String? kind, String? sourceId, int? generation}) =>
      RecallQueueRow(
        kind: kind ?? this.kind,
        sourceId: sourceId ?? this.sourceId,
        generation: generation ?? this.generation,
      );
  RecallQueueRow copyWithCompanion(RecallQueueCompanion data) {
    return RecallQueueRow(
      kind: data.kind.present ? data.kind.value : this.kind,
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      generation: data.generation.present
          ? data.generation.value
          : this.generation,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RecallQueueRow(')
          ..write('kind: $kind, ')
          ..write('sourceId: $sourceId, ')
          ..write('generation: $generation')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(kind, sourceId, generation);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RecallQueueRow &&
          other.kind == this.kind &&
          other.sourceId == this.sourceId &&
          other.generation == this.generation);
}

class RecallQueueCompanion extends UpdateCompanion<RecallQueueRow> {
  final Value<String> kind;
  final Value<String> sourceId;
  final Value<int> generation;
  final Value<int> rowid;
  const RecallQueueCompanion({
    this.kind = const Value.absent(),
    this.sourceId = const Value.absent(),
    this.generation = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RecallQueueCompanion.insert({
    required String kind,
    required String sourceId,
    this.generation = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : kind = Value(kind),
       sourceId = Value(sourceId);
  static Insertable<RecallQueueRow> custom({
    Expression<String>? kind,
    Expression<String>? sourceId,
    Expression<int>? generation,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (kind != null) 'kind': kind,
      if (sourceId != null) 'source_id': sourceId,
      if (generation != null) 'generation': generation,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RecallQueueCompanion copyWith({
    Value<String>? kind,
    Value<String>? sourceId,
    Value<int>? generation,
    Value<int>? rowid,
  }) {
    return RecallQueueCompanion(
      kind: kind ?? this.kind,
      sourceId: sourceId ?? this.sourceId,
      generation: generation ?? this.generation,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (sourceId.present) {
      map['source_id'] = Variable<String>(sourceId.value);
    }
    if (generation.present) {
      map['generation'] = Variable<int>(generation.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RecallQueueCompanion(')
          ..write('kind: $kind, ')
          ..write('sourceId: $sourceId, ')
          ..write('generation: $generation, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RecallManifestsTable extends RecallManifests
    with TableInfo<$RecallManifestsTable, RecallManifestRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RecallManifestsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _profileMeta = const VerificationMeta(
    'profile',
  );
  @override
  late final GeneratedColumn<String> profile = GeneratedColumn<String>(
    'profile',
    aliasedName,
    false,
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
  static const VerificationMeta _sourceIdMeta = const VerificationMeta(
    'sourceId',
  );
  @override
  late final GeneratedColumn<String> sourceId = GeneratedColumn<String>(
    'source_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _hashMeta = const VerificationMeta('hash');
  @override
  late final GeneratedColumn<String> hash = GeneratedColumn<String>(
    'hash',
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
  );
  static const VerificationMeta _chunksMeta = const VerificationMeta('chunks');
  @override
  late final GeneratedColumn<String> chunks = GeneratedColumn<String>(
    'chunks',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _completeMeta = const VerificationMeta(
    'complete',
  );
  @override
  late final GeneratedColumn<bool> complete = GeneratedColumn<bool>(
    'complete',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("complete" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    profile,
    kind,
    sourceId,
    hash,
    revision,
    chunks,
    complete,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'recall_manifests';
  @override
  VerificationContext validateIntegrity(
    Insertable<RecallManifestRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('profile')) {
      context.handle(
        _profileMeta,
        profile.isAcceptableOrUnknown(data['profile']!, _profileMeta),
      );
    } else if (isInserting) {
      context.missing(_profileMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('source_id')) {
      context.handle(
        _sourceIdMeta,
        sourceId.isAcceptableOrUnknown(data['source_id']!, _sourceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceIdMeta);
    }
    if (data.containsKey('hash')) {
      context.handle(
        _hashMeta,
        hash.isAcceptableOrUnknown(data['hash']!, _hashMeta),
      );
    } else if (isInserting) {
      context.missing(_hashMeta);
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
      );
    } else if (isInserting) {
      context.missing(_revisionMeta);
    }
    if (data.containsKey('chunks')) {
      context.handle(
        _chunksMeta,
        chunks.isAcceptableOrUnknown(data['chunks']!, _chunksMeta),
      );
    } else if (isInserting) {
      context.missing(_chunksMeta);
    }
    if (data.containsKey('complete')) {
      context.handle(
        _completeMeta,
        complete.isAcceptableOrUnknown(data['complete']!, _completeMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {profile, kind, sourceId};
  @override
  RecallManifestRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RecallManifestRow(
      profile: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}profile'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      sourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_id'],
      )!,
      hash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}hash'],
      )!,
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revision'],
      )!,
      chunks: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}chunks'],
      )!,
      complete: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}complete'],
      )!,
    );
  }

  @override
  $RecallManifestsTable createAlias(String alias) {
    return $RecallManifestsTable(attachedDatabase, alias);
  }
}

class RecallManifestRow extends DataClass
    implements Insertable<RecallManifestRow> {
  final String profile;
  final String kind;
  final String sourceId;
  final String hash;
  final int revision;
  final String chunks;
  final bool complete;
  const RecallManifestRow({
    required this.profile,
    required this.kind,
    required this.sourceId,
    required this.hash,
    required this.revision,
    required this.chunks,
    required this.complete,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['profile'] = Variable<String>(profile);
    map['kind'] = Variable<String>(kind);
    map['source_id'] = Variable<String>(sourceId);
    map['hash'] = Variable<String>(hash);
    map['revision'] = Variable<int>(revision);
    map['chunks'] = Variable<String>(chunks);
    map['complete'] = Variable<bool>(complete);
    return map;
  }

  RecallManifestsCompanion toCompanion(bool nullToAbsent) {
    return RecallManifestsCompanion(
      profile: Value(profile),
      kind: Value(kind),
      sourceId: Value(sourceId),
      hash: Value(hash),
      revision: Value(revision),
      chunks: Value(chunks),
      complete: Value(complete),
    );
  }

  factory RecallManifestRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RecallManifestRow(
      profile: serializer.fromJson<String>(json['profile']),
      kind: serializer.fromJson<String>(json['kind']),
      sourceId: serializer.fromJson<String>(json['sourceId']),
      hash: serializer.fromJson<String>(json['hash']),
      revision: serializer.fromJson<int>(json['revision']),
      chunks: serializer.fromJson<String>(json['chunks']),
      complete: serializer.fromJson<bool>(json['complete']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'profile': serializer.toJson<String>(profile),
      'kind': serializer.toJson<String>(kind),
      'sourceId': serializer.toJson<String>(sourceId),
      'hash': serializer.toJson<String>(hash),
      'revision': serializer.toJson<int>(revision),
      'chunks': serializer.toJson<String>(chunks),
      'complete': serializer.toJson<bool>(complete),
    };
  }

  RecallManifestRow copyWith({
    String? profile,
    String? kind,
    String? sourceId,
    String? hash,
    int? revision,
    String? chunks,
    bool? complete,
  }) => RecallManifestRow(
    profile: profile ?? this.profile,
    kind: kind ?? this.kind,
    sourceId: sourceId ?? this.sourceId,
    hash: hash ?? this.hash,
    revision: revision ?? this.revision,
    chunks: chunks ?? this.chunks,
    complete: complete ?? this.complete,
  );
  RecallManifestRow copyWithCompanion(RecallManifestsCompanion data) {
    return RecallManifestRow(
      profile: data.profile.present ? data.profile.value : this.profile,
      kind: data.kind.present ? data.kind.value : this.kind,
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      hash: data.hash.present ? data.hash.value : this.hash,
      revision: data.revision.present ? data.revision.value : this.revision,
      chunks: data.chunks.present ? data.chunks.value : this.chunks,
      complete: data.complete.present ? data.complete.value : this.complete,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RecallManifestRow(')
          ..write('profile: $profile, ')
          ..write('kind: $kind, ')
          ..write('sourceId: $sourceId, ')
          ..write('hash: $hash, ')
          ..write('revision: $revision, ')
          ..write('chunks: $chunks, ')
          ..write('complete: $complete')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(profile, kind, sourceId, hash, revision, chunks, complete);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RecallManifestRow &&
          other.profile == this.profile &&
          other.kind == this.kind &&
          other.sourceId == this.sourceId &&
          other.hash == this.hash &&
          other.revision == this.revision &&
          other.chunks == this.chunks &&
          other.complete == this.complete);
}

class RecallManifestsCompanion extends UpdateCompanion<RecallManifestRow> {
  final Value<String> profile;
  final Value<String> kind;
  final Value<String> sourceId;
  final Value<String> hash;
  final Value<int> revision;
  final Value<String> chunks;
  final Value<bool> complete;
  final Value<int> rowid;
  const RecallManifestsCompanion({
    this.profile = const Value.absent(),
    this.kind = const Value.absent(),
    this.sourceId = const Value.absent(),
    this.hash = const Value.absent(),
    this.revision = const Value.absent(),
    this.chunks = const Value.absent(),
    this.complete = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RecallManifestsCompanion.insert({
    required String profile,
    required String kind,
    required String sourceId,
    required String hash,
    required int revision,
    required String chunks,
    this.complete = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : profile = Value(profile),
       kind = Value(kind),
       sourceId = Value(sourceId),
       hash = Value(hash),
       revision = Value(revision),
       chunks = Value(chunks);
  static Insertable<RecallManifestRow> custom({
    Expression<String>? profile,
    Expression<String>? kind,
    Expression<String>? sourceId,
    Expression<String>? hash,
    Expression<int>? revision,
    Expression<String>? chunks,
    Expression<bool>? complete,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (profile != null) 'profile': profile,
      if (kind != null) 'kind': kind,
      if (sourceId != null) 'source_id': sourceId,
      if (hash != null) 'hash': hash,
      if (revision != null) 'revision': revision,
      if (chunks != null) 'chunks': chunks,
      if (complete != null) 'complete': complete,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RecallManifestsCompanion copyWith({
    Value<String>? profile,
    Value<String>? kind,
    Value<String>? sourceId,
    Value<String>? hash,
    Value<int>? revision,
    Value<String>? chunks,
    Value<bool>? complete,
    Value<int>? rowid,
  }) {
    return RecallManifestsCompanion(
      profile: profile ?? this.profile,
      kind: kind ?? this.kind,
      sourceId: sourceId ?? this.sourceId,
      hash: hash ?? this.hash,
      revision: revision ?? this.revision,
      chunks: chunks ?? this.chunks,
      complete: complete ?? this.complete,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (profile.present) {
      map['profile'] = Variable<String>(profile.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (sourceId.present) {
      map['source_id'] = Variable<String>(sourceId.value);
    }
    if (hash.present) {
      map['hash'] = Variable<String>(hash.value);
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (chunks.present) {
      map['chunks'] = Variable<String>(chunks.value);
    }
    if (complete.present) {
      map['complete'] = Variable<bool>(complete.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RecallManifestsCompanion(')
          ..write('profile: $profile, ')
          ..write('kind: $kind, ')
          ..write('sourceId: $sourceId, ')
          ..write('hash: $hash, ')
          ..write('revision: $revision, ')
          ..write('chunks: $chunks, ')
          ..write('complete: $complete, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DailyQuestionsTable extends DailyQuestions
    with TableInfo<$DailyQuestionsTable, DailyQuestionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DailyQuestionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dayMeta = const VerificationMeta('day');
  @override
  late final GeneratedColumn<String> day = GeneratedColumn<String>(
    'day',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _questionMeta = const VerificationMeta(
    'question',
  );
  @override
  late final GeneratedColumn<String> question = GeneratedColumn<String>(
    'question',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceDateMeta = const VerificationMeta(
    'sourceDate',
  );
  @override
  late final GeneratedColumn<String> sourceDate = GeneratedColumn<String>(
    'source_date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _sourceIdMeta = const VerificationMeta(
    'sourceId',
  );
  @override
  late final GeneratedColumn<String> sourceId = GeneratedColumn<String>(
    'source_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
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
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _evidenceMeta = const VerificationMeta(
    'evidence',
  );
  @override
  late final GeneratedColumn<String> evidence = GeneratedColumn<String>(
    'evidence',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _agoMeta = const VerificationMeta('ago');
  @override
  late final GeneratedColumn<int> ago = GeneratedColumn<int>(
    'ago',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _basisMeta = const VerificationMeta('basis');
  @override
  late final GeneratedColumn<String> basis = GeneratedColumn<String>(
    'basis',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourcesMeta = const VerificationMeta(
    'sources',
  );
  @override
  late final GeneratedColumn<String> sources = GeneratedColumn<String>(
    'sources',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _shownMeta = const VerificationMeta('shown');
  @override
  late final GeneratedColumn<bool> shown = GeneratedColumn<bool>(
    'shown',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("shown" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
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
  List<GeneratedColumn> get $columns => [
    id,
    day,
    question,
    sourceDate,
    sourceId,
    sourceHash,
    evidence,
    ago,
    basis,
    sources,
    shown,
    created,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'daily_questions';
  @override
  VerificationContext validateIntegrity(
    Insertable<DailyQuestionRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('day')) {
      context.handle(
        _dayMeta,
        day.isAcceptableOrUnknown(data['day']!, _dayMeta),
      );
    } else if (isInserting) {
      context.missing(_dayMeta);
    }
    if (data.containsKey('question')) {
      context.handle(
        _questionMeta,
        question.isAcceptableOrUnknown(data['question']!, _questionMeta),
      );
    } else if (isInserting) {
      context.missing(_questionMeta);
    }
    if (data.containsKey('source_date')) {
      context.handle(
        _sourceDateMeta,
        sourceDate.isAcceptableOrUnknown(data['source_date']!, _sourceDateMeta),
      );
    }
    if (data.containsKey('source_id')) {
      context.handle(
        _sourceIdMeta,
        sourceId.isAcceptableOrUnknown(data['source_id']!, _sourceIdMeta),
      );
    }
    if (data.containsKey('source_hash')) {
      context.handle(
        _sourceHashMeta,
        sourceHash.isAcceptableOrUnknown(data['source_hash']!, _sourceHashMeta),
      );
    }
    if (data.containsKey('evidence')) {
      context.handle(
        _evidenceMeta,
        evidence.isAcceptableOrUnknown(data['evidence']!, _evidenceMeta),
      );
    }
    if (data.containsKey('ago')) {
      context.handle(
        _agoMeta,
        ago.isAcceptableOrUnknown(data['ago']!, _agoMeta),
      );
    }
    if (data.containsKey('basis')) {
      context.handle(
        _basisMeta,
        basis.isAcceptableOrUnknown(data['basis']!, _basisMeta),
      );
    } else if (isInserting) {
      context.missing(_basisMeta);
    }
    if (data.containsKey('sources')) {
      context.handle(
        _sourcesMeta,
        sources.isAcceptableOrUnknown(data['sources']!, _sourcesMeta),
      );
    }
    if (data.containsKey('shown')) {
      context.handle(
        _shownMeta,
        shown.isAcceptableOrUnknown(data['shown']!, _shownMeta),
      );
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
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DailyQuestionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DailyQuestionRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      day: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}day'],
      )!,
      question: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}question'],
      )!,
      sourceDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_date'],
      )!,
      sourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_id'],
      )!,
      sourceHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_hash'],
      )!,
      evidence: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}evidence'],
      )!,
      ago: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ago'],
      )!,
      basis: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}basis'],
      )!,
      sources: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sources'],
      )!,
      shown: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}shown'],
      )!,
      created: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created'],
      )!,
    );
  }

  @override
  $DailyQuestionsTable createAlias(String alias) {
    return $DailyQuestionsTable(attachedDatabase, alias);
  }
}

class DailyQuestionRow extends DataClass
    implements Insertable<DailyQuestionRow> {
  final String id;
  final String day;
  final String question;
  final String sourceDate;
  final String sourceId;
  final String sourceHash;
  final String evidence;
  final int ago;
  final String basis;
  final String sources;
  final bool shown;
  final int created;
  const DailyQuestionRow({
    required this.id,
    required this.day,
    required this.question,
    required this.sourceDate,
    required this.sourceId,
    required this.sourceHash,
    required this.evidence,
    required this.ago,
    required this.basis,
    required this.sources,
    required this.shown,
    required this.created,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['day'] = Variable<String>(day);
    map['question'] = Variable<String>(question);
    map['source_date'] = Variable<String>(sourceDate);
    map['source_id'] = Variable<String>(sourceId);
    map['source_hash'] = Variable<String>(sourceHash);
    map['evidence'] = Variable<String>(evidence);
    map['ago'] = Variable<int>(ago);
    map['basis'] = Variable<String>(basis);
    map['sources'] = Variable<String>(sources);
    map['shown'] = Variable<bool>(shown);
    map['created'] = Variable<int>(created);
    return map;
  }

  DailyQuestionsCompanion toCompanion(bool nullToAbsent) {
    return DailyQuestionsCompanion(
      id: Value(id),
      day: Value(day),
      question: Value(question),
      sourceDate: Value(sourceDate),
      sourceId: Value(sourceId),
      sourceHash: Value(sourceHash),
      evidence: Value(evidence),
      ago: Value(ago),
      basis: Value(basis),
      sources: Value(sources),
      shown: Value(shown),
      created: Value(created),
    );
  }

  factory DailyQuestionRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DailyQuestionRow(
      id: serializer.fromJson<String>(json['id']),
      day: serializer.fromJson<String>(json['day']),
      question: serializer.fromJson<String>(json['question']),
      sourceDate: serializer.fromJson<String>(json['sourceDate']),
      sourceId: serializer.fromJson<String>(json['sourceId']),
      sourceHash: serializer.fromJson<String>(json['sourceHash']),
      evidence: serializer.fromJson<String>(json['evidence']),
      ago: serializer.fromJson<int>(json['ago']),
      basis: serializer.fromJson<String>(json['basis']),
      sources: serializer.fromJson<String>(json['sources']),
      shown: serializer.fromJson<bool>(json['shown']),
      created: serializer.fromJson<int>(json['created']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'day': serializer.toJson<String>(day),
      'question': serializer.toJson<String>(question),
      'sourceDate': serializer.toJson<String>(sourceDate),
      'sourceId': serializer.toJson<String>(sourceId),
      'sourceHash': serializer.toJson<String>(sourceHash),
      'evidence': serializer.toJson<String>(evidence),
      'ago': serializer.toJson<int>(ago),
      'basis': serializer.toJson<String>(basis),
      'sources': serializer.toJson<String>(sources),
      'shown': serializer.toJson<bool>(shown),
      'created': serializer.toJson<int>(created),
    };
  }

  DailyQuestionRow copyWith({
    String? id,
    String? day,
    String? question,
    String? sourceDate,
    String? sourceId,
    String? sourceHash,
    String? evidence,
    int? ago,
    String? basis,
    String? sources,
    bool? shown,
    int? created,
  }) => DailyQuestionRow(
    id: id ?? this.id,
    day: day ?? this.day,
    question: question ?? this.question,
    sourceDate: sourceDate ?? this.sourceDate,
    sourceId: sourceId ?? this.sourceId,
    sourceHash: sourceHash ?? this.sourceHash,
    evidence: evidence ?? this.evidence,
    ago: ago ?? this.ago,
    basis: basis ?? this.basis,
    sources: sources ?? this.sources,
    shown: shown ?? this.shown,
    created: created ?? this.created,
  );
  DailyQuestionRow copyWithCompanion(DailyQuestionsCompanion data) {
    return DailyQuestionRow(
      id: data.id.present ? data.id.value : this.id,
      day: data.day.present ? data.day.value : this.day,
      question: data.question.present ? data.question.value : this.question,
      sourceDate: data.sourceDate.present
          ? data.sourceDate.value
          : this.sourceDate,
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      sourceHash: data.sourceHash.present
          ? data.sourceHash.value
          : this.sourceHash,
      evidence: data.evidence.present ? data.evidence.value : this.evidence,
      ago: data.ago.present ? data.ago.value : this.ago,
      basis: data.basis.present ? data.basis.value : this.basis,
      sources: data.sources.present ? data.sources.value : this.sources,
      shown: data.shown.present ? data.shown.value : this.shown,
      created: data.created.present ? data.created.value : this.created,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DailyQuestionRow(')
          ..write('id: $id, ')
          ..write('day: $day, ')
          ..write('question: $question, ')
          ..write('sourceDate: $sourceDate, ')
          ..write('sourceId: $sourceId, ')
          ..write('sourceHash: $sourceHash, ')
          ..write('evidence: $evidence, ')
          ..write('ago: $ago, ')
          ..write('basis: $basis, ')
          ..write('sources: $sources, ')
          ..write('shown: $shown, ')
          ..write('created: $created')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    day,
    question,
    sourceDate,
    sourceId,
    sourceHash,
    evidence,
    ago,
    basis,
    sources,
    shown,
    created,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DailyQuestionRow &&
          other.id == this.id &&
          other.day == this.day &&
          other.question == this.question &&
          other.sourceDate == this.sourceDate &&
          other.sourceId == this.sourceId &&
          other.sourceHash == this.sourceHash &&
          other.evidence == this.evidence &&
          other.ago == this.ago &&
          other.basis == this.basis &&
          other.sources == this.sources &&
          other.shown == this.shown &&
          other.created == this.created);
}

class DailyQuestionsCompanion extends UpdateCompanion<DailyQuestionRow> {
  final Value<String> id;
  final Value<String> day;
  final Value<String> question;
  final Value<String> sourceDate;
  final Value<String> sourceId;
  final Value<String> sourceHash;
  final Value<String> evidence;
  final Value<int> ago;
  final Value<String> basis;
  final Value<String> sources;
  final Value<bool> shown;
  final Value<int> created;
  final Value<int> rowid;
  const DailyQuestionsCompanion({
    this.id = const Value.absent(),
    this.day = const Value.absent(),
    this.question = const Value.absent(),
    this.sourceDate = const Value.absent(),
    this.sourceId = const Value.absent(),
    this.sourceHash = const Value.absent(),
    this.evidence = const Value.absent(),
    this.ago = const Value.absent(),
    this.basis = const Value.absent(),
    this.sources = const Value.absent(),
    this.shown = const Value.absent(),
    this.created = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DailyQuestionsCompanion.insert({
    required String id,
    required String day,
    required String question,
    this.sourceDate = const Value.absent(),
    this.sourceId = const Value.absent(),
    this.sourceHash = const Value.absent(),
    this.evidence = const Value.absent(),
    this.ago = const Value.absent(),
    required String basis,
    this.sources = const Value.absent(),
    this.shown = const Value.absent(),
    required int created,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       day = Value(day),
       question = Value(question),
       basis = Value(basis),
       created = Value(created);
  static Insertable<DailyQuestionRow> custom({
    Expression<String>? id,
    Expression<String>? day,
    Expression<String>? question,
    Expression<String>? sourceDate,
    Expression<String>? sourceId,
    Expression<String>? sourceHash,
    Expression<String>? evidence,
    Expression<int>? ago,
    Expression<String>? basis,
    Expression<String>? sources,
    Expression<bool>? shown,
    Expression<int>? created,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (day != null) 'day': day,
      if (question != null) 'question': question,
      if (sourceDate != null) 'source_date': sourceDate,
      if (sourceId != null) 'source_id': sourceId,
      if (sourceHash != null) 'source_hash': sourceHash,
      if (evidence != null) 'evidence': evidence,
      if (ago != null) 'ago': ago,
      if (basis != null) 'basis': basis,
      if (sources != null) 'sources': sources,
      if (shown != null) 'shown': shown,
      if (created != null) 'created': created,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DailyQuestionsCompanion copyWith({
    Value<String>? id,
    Value<String>? day,
    Value<String>? question,
    Value<String>? sourceDate,
    Value<String>? sourceId,
    Value<String>? sourceHash,
    Value<String>? evidence,
    Value<int>? ago,
    Value<String>? basis,
    Value<String>? sources,
    Value<bool>? shown,
    Value<int>? created,
    Value<int>? rowid,
  }) {
    return DailyQuestionsCompanion(
      id: id ?? this.id,
      day: day ?? this.day,
      question: question ?? this.question,
      sourceDate: sourceDate ?? this.sourceDate,
      sourceId: sourceId ?? this.sourceId,
      sourceHash: sourceHash ?? this.sourceHash,
      evidence: evidence ?? this.evidence,
      ago: ago ?? this.ago,
      basis: basis ?? this.basis,
      sources: sources ?? this.sources,
      shown: shown ?? this.shown,
      created: created ?? this.created,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (day.present) {
      map['day'] = Variable<String>(day.value);
    }
    if (question.present) {
      map['question'] = Variable<String>(question.value);
    }
    if (sourceDate.present) {
      map['source_date'] = Variable<String>(sourceDate.value);
    }
    if (sourceId.present) {
      map['source_id'] = Variable<String>(sourceId.value);
    }
    if (sourceHash.present) {
      map['source_hash'] = Variable<String>(sourceHash.value);
    }
    if (evidence.present) {
      map['evidence'] = Variable<String>(evidence.value);
    }
    if (ago.present) {
      map['ago'] = Variable<int>(ago.value);
    }
    if (basis.present) {
      map['basis'] = Variable<String>(basis.value);
    }
    if (sources.present) {
      map['sources'] = Variable<String>(sources.value);
    }
    if (shown.present) {
      map['shown'] = Variable<bool>(shown.value);
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
    return (StringBuffer('DailyQuestionsCompanion(')
          ..write('id: $id, ')
          ..write('day: $day, ')
          ..write('question: $question, ')
          ..write('sourceDate: $sourceDate, ')
          ..write('sourceId: $sourceId, ')
          ..write('sourceHash: $sourceHash, ')
          ..write('evidence: $evidence, ')
          ..write('ago: $ago, ')
          ..write('basis: $basis, ')
          ..write('sources: $sources, ')
          ..write('shown: $shown, ')
          ..write('created: $created, ')
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
        defaultValue: const Constant('Lora'),
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
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints:
        'CHECK (name IS NULL OR length(trim(name)) BETWEEN 1 AND 160)',
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
      ),
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
  final String? name;
  const OnboardingCompletionRow({required this.id, this.name});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || name != null) {
      map['name'] = Variable<String>(name);
    }
    return map;
  }

  OnboardingCompletionCompanion toCompanion(bool nullToAbsent) {
    return OnboardingCompletionCompanion(
      id: Value(id),
      name: name == null && nullToAbsent ? const Value.absent() : Value(name),
    );
  }

  factory OnboardingCompletionRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OnboardingCompletionRow(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String?>(json['name']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String?>(name),
    };
  }

  OnboardingCompletionRow copyWith({
    int? id,
    Value<String?> name = const Value.absent(),
  }) => OnboardingCompletionRow(
    id: id ?? this.id,
    name: name.present ? name.value : this.name,
  );
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
  final Value<String?> name;
  const OnboardingCompletionCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
  });
  OnboardingCompletionCompanion.insert({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
  });
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
    Value<String?>? name,
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
  final String id;
  final String title;
  final String body;
  final int revision;
  final int createdAt;
  final int updatedAt;
  final bool pinned;
  final int? deletedAt;
  const Note({
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
    String? id,
    String? title,
    String? body,
    int? revision,
    int? createdAt,
    int? updatedAt,
    bool? pinned,
    Value<int?> deletedAt = const Value.absent(),
  }) => Note(
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

class $NoteDraftsTable extends NoteDrafts
    with TableInfo<$NoteDraftsTable, NoteDraft> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NoteDraftsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
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
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'body',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _baseRevisionMeta = const VerificationMeta(
    'baseRevision',
  );
  @override
  late final GeneratedColumn<int> baseRevision = GeneratedColumn<int>(
    'base_revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (base_revision >= 0)',
  );
  static const VerificationMeta _draftRevisionMeta = const VerificationMeta(
    'draftRevision',
  );
  @override
  late final GeneratedColumn<int> draftRevision = GeneratedColumn<int>(
    'draft_revision',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    body,
    baseRevision,
    draftRevision,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'note_drafts';
  @override
  VerificationContext validateIntegrity(
    Insertable<NoteDraft> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
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
    if (data.containsKey('base_revision')) {
      context.handle(
        _baseRevisionMeta,
        baseRevision.isAcceptableOrUnknown(
          data['base_revision']!,
          _baseRevisionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_baseRevisionMeta);
    }
    if (data.containsKey('draft_revision')) {
      context.handle(
        _draftRevisionMeta,
        draftRevision.isAcceptableOrUnknown(
          data['draft_revision']!,
          _draftRevisionMeta,
        ),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {draftRevision};
  @override
  NoteDraft map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return NoteDraft(
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
      baseRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}base_revision'],
      )!,
      draftRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}draft_revision'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $NoteDraftsTable createAlias(String alias) {
    return $NoteDraftsTable(attachedDatabase, alias);
  }
}

class NoteDraft extends DataClass implements Insertable<NoteDraft> {
  final String id;
  final String title;
  final String body;
  final int baseRevision;
  final int draftRevision;
  final int updatedAt;
  const NoteDraft({
    required this.id,
    required this.title,
    required this.body,
    required this.baseRevision,
    required this.draftRevision,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    map['body'] = Variable<String>(body);
    map['base_revision'] = Variable<int>(baseRevision);
    map['draft_revision'] = Variable<int>(draftRevision);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  NoteDraftsCompanion toCompanion(bool nullToAbsent) {
    return NoteDraftsCompanion(
      id: Value(id),
      title: Value(title),
      body: Value(body),
      baseRevision: Value(baseRevision),
      draftRevision: Value(draftRevision),
      updatedAt: Value(updatedAt),
    );
  }

  factory NoteDraft.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return NoteDraft(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      body: serializer.fromJson<String>(json['body']),
      baseRevision: serializer.fromJson<int>(json['baseRevision']),
      draftRevision: serializer.fromJson<int>(json['draftRevision']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'body': serializer.toJson<String>(body),
      'baseRevision': serializer.toJson<int>(baseRevision),
      'draftRevision': serializer.toJson<int>(draftRevision),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  NoteDraft copyWith({
    String? id,
    String? title,
    String? body,
    int? baseRevision,
    int? draftRevision,
    int? updatedAt,
  }) => NoteDraft(
    id: id ?? this.id,
    title: title ?? this.title,
    body: body ?? this.body,
    baseRevision: baseRevision ?? this.baseRevision,
    draftRevision: draftRevision ?? this.draftRevision,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  NoteDraft copyWithCompanion(NoteDraftsCompanion data) {
    return NoteDraft(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      body: data.body.present ? data.body.value : this.body,
      baseRevision: data.baseRevision.present
          ? data.baseRevision.value
          : this.baseRevision,
      draftRevision: data.draftRevision.present
          ? data.draftRevision.value
          : this.draftRevision,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('NoteDraft(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('body: $body, ')
          ..write('baseRevision: $baseRevision, ')
          ..write('draftRevision: $draftRevision, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, title, body, baseRevision, draftRevision, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NoteDraft &&
          other.id == this.id &&
          other.title == this.title &&
          other.body == this.body &&
          other.baseRevision == this.baseRevision &&
          other.draftRevision == this.draftRevision &&
          other.updatedAt == this.updatedAt);
}

class NoteDraftsCompanion extends UpdateCompanion<NoteDraft> {
  final Value<String> id;
  final Value<String> title;
  final Value<String> body;
  final Value<int> baseRevision;
  final Value<int> draftRevision;
  final Value<int> updatedAt;
  const NoteDraftsCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.body = const Value.absent(),
    this.baseRevision = const Value.absent(),
    this.draftRevision = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  NoteDraftsCompanion.insert({
    required String id,
    required String title,
    required String body,
    required int baseRevision,
    this.draftRevision = const Value.absent(),
    required int updatedAt,
  }) : id = Value(id),
       title = Value(title),
       body = Value(body),
       baseRevision = Value(baseRevision),
       updatedAt = Value(updatedAt);
  static Insertable<NoteDraft> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? body,
    Expression<int>? baseRevision,
    Expression<int>? draftRevision,
    Expression<int>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (body != null) 'body': body,
      if (baseRevision != null) 'base_revision': baseRevision,
      if (draftRevision != null) 'draft_revision': draftRevision,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  NoteDraftsCompanion copyWith({
    Value<String>? id,
    Value<String>? title,
    Value<String>? body,
    Value<int>? baseRevision,
    Value<int>? draftRevision,
    Value<int>? updatedAt,
  }) {
    return NoteDraftsCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      baseRevision: baseRevision ?? this.baseRevision,
      draftRevision: draftRevision ?? this.draftRevision,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (baseRevision.present) {
      map['base_revision'] = Variable<int>(baseRevision.value);
    }
    if (draftRevision.present) {
      map['draft_revision'] = Variable<int>(draftRevision.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NoteDraftsCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('body: $body, ')
          ..write('baseRevision: $baseRevision, ')
          ..write('draftRevision: $draftRevision, ')
          ..write('updatedAt: $updatedAt')
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
  static const VerificationMeta _dateKeyMeta = const VerificationMeta(
    'dateKey',
  );
  @override
  late final GeneratedColumn<String> dateKey = GeneratedColumn<String>(
    'date_key',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 10,
      maxTextLength: 10,
    ),
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
    dateKey,
    title,
    body,
    revision,
    createdAt,
    updatedAt,
    deletedAt,
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
    if (data.containsKey('date_key')) {
      context.handle(
        _dateKeyMeta,
        dateKey.isAcceptableOrUnknown(data['date_key']!, _dateKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_dateKeyMeta);
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
  DiaryEntryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DiaryEntryRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      dateKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}date_key'],
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
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $DiaryEntriesTable createAlias(String alias) {
    return $DiaryEntriesTable(attachedDatabase, alias);
  }
}

class DiaryEntryRow extends DataClass implements Insertable<DiaryEntryRow> {
  final String id;
  final String dateKey;
  final String title;
  final String body;
  final int revision;
  final int createdAt;
  final int updatedAt;
  final int? deletedAt;
  const DiaryEntryRow({
    required this.id,
    required this.dateKey,
    required this.title,
    required this.body,
    required this.revision,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['date_key'] = Variable<String>(dateKey);
    map['title'] = Variable<String>(title);
    map['body'] = Variable<String>(body);
    map['revision'] = Variable<int>(revision);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    return map;
  }

  DiaryEntriesCompanion toCompanion(bool nullToAbsent) {
    return DiaryEntriesCompanion(
      id: Value(id),
      dateKey: Value(dateKey),
      title: Value(title),
      body: Value(body),
      revision: Value(revision),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory DiaryEntryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DiaryEntryRow(
      id: serializer.fromJson<String>(json['id']),
      dateKey: serializer.fromJson<String>(json['dateKey']),
      title: serializer.fromJson<String>(json['title']),
      body: serializer.fromJson<String>(json['body']),
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
      'dateKey': serializer.toJson<String>(dateKey),
      'title': serializer.toJson<String>(title),
      'body': serializer.toJson<String>(body),
      'revision': serializer.toJson<int>(revision),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'deletedAt': serializer.toJson<int?>(deletedAt),
    };
  }

  DiaryEntryRow copyWith({
    String? id,
    String? dateKey,
    String? title,
    String? body,
    int? revision,
    int? createdAt,
    int? updatedAt,
    Value<int?> deletedAt = const Value.absent(),
  }) => DiaryEntryRow(
    id: id ?? this.id,
    dateKey: dateKey ?? this.dateKey,
    title: title ?? this.title,
    body: body ?? this.body,
    revision: revision ?? this.revision,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  DiaryEntryRow copyWithCompanion(DiaryEntriesCompanion data) {
    return DiaryEntryRow(
      id: data.id.present ? data.id.value : this.id,
      dateKey: data.dateKey.present ? data.dateKey.value : this.dateKey,
      title: data.title.present ? data.title.value : this.title,
      body: data.body.present ? data.body.value : this.body,
      revision: data.revision.present ? data.revision.value : this.revision,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DiaryEntryRow(')
          ..write('id: $id, ')
          ..write('dateKey: $dateKey, ')
          ..write('title: $title, ')
          ..write('body: $body, ')
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
    dateKey,
    title,
    body,
    revision,
    createdAt,
    updatedAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DiaryEntryRow &&
          other.id == this.id &&
          other.dateKey == this.dateKey &&
          other.title == this.title &&
          other.body == this.body &&
          other.revision == this.revision &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class DiaryEntriesCompanion extends UpdateCompanion<DiaryEntryRow> {
  final Value<String> id;
  final Value<String> dateKey;
  final Value<String> title;
  final Value<String> body;
  final Value<int> revision;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int?> deletedAt;
  final Value<int> rowid;
  const DiaryEntriesCompanion({
    this.id = const Value.absent(),
    this.dateKey = const Value.absent(),
    this.title = const Value.absent(),
    this.body = const Value.absent(),
    this.revision = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DiaryEntriesCompanion.insert({
    required String id,
    required String dateKey,
    required String title,
    required String body,
    required int revision,
    required int createdAt,
    required int updatedAt,
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       dateKey = Value(dateKey),
       title = Value(title),
       body = Value(body),
       revision = Value(revision),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<DiaryEntryRow> custom({
    Expression<String>? id,
    Expression<String>? dateKey,
    Expression<String>? title,
    Expression<String>? body,
    Expression<int>? revision,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (dateKey != null) 'date_key': dateKey,
      if (title != null) 'title': title,
      if (body != null) 'body': body,
      if (revision != null) 'revision': revision,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DiaryEntriesCompanion copyWith({
    Value<String>? id,
    Value<String>? dateKey,
    Value<String>? title,
    Value<String>? body,
    Value<int>? revision,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int?>? deletedAt,
    Value<int>? rowid,
  }) {
    return DiaryEntriesCompanion(
      id: id ?? this.id,
      dateKey: dateKey ?? this.dateKey,
      title: title ?? this.title,
      body: body ?? this.body,
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
    if (dateKey.present) {
      map['date_key'] = Variable<String>(dateKey.value);
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
    return (StringBuffer('DiaryEntriesCompanion(')
          ..write('id: $id, ')
          ..write('dateKey: $dateKey, ')
          ..write('title: $title, ')
          ..write('body: $body, ')
          ..write('revision: $revision, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
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
  static const VerificationMeta _dateKeyMeta = const VerificationMeta(
    'dateKey',
  );
  @override
  late final GeneratedColumn<String> dateKey = GeneratedColumn<String>(
    'date_key',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 10,
      maxTextLength: 10,
    ),
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
    dateKey,
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
    if (data.containsKey('date_key')) {
      context.handle(
        _dateKeyMeta,
        dateKey.isAcceptableOrUnknown(data['date_key']!, _dateKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_dateKeyMeta);
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
  Set<GeneratedColumn> get $primaryKey => {dateKey};
  @override
  DiaryDayRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DiaryDayRow(
      dateKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}date_key'],
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
  final String dateKey;
  final String heading;
  final String? mood;
  final String themes;
  final int revision;
  const DiaryDayRow({
    required this.dateKey,
    required this.heading,
    this.mood,
    required this.themes,
    required this.revision,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['date_key'] = Variable<String>(dateKey);
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
      dateKey: Value(dateKey),
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
      dateKey: serializer.fromJson<String>(json['dateKey']),
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
      'dateKey': serializer.toJson<String>(dateKey),
      'heading': serializer.toJson<String>(heading),
      'mood': serializer.toJson<String?>(mood),
      'themes': serializer.toJson<String>(themes),
      'revision': serializer.toJson<int>(revision),
    };
  }

  DiaryDayRow copyWith({
    String? dateKey,
    String? heading,
    Value<String?> mood = const Value.absent(),
    String? themes,
    int? revision,
  }) => DiaryDayRow(
    dateKey: dateKey ?? this.dateKey,
    heading: heading ?? this.heading,
    mood: mood.present ? mood.value : this.mood,
    themes: themes ?? this.themes,
    revision: revision ?? this.revision,
  );
  DiaryDayRow copyWithCompanion(DiaryDaysCompanion data) {
    return DiaryDayRow(
      dateKey: data.dateKey.present ? data.dateKey.value : this.dateKey,
      heading: data.heading.present ? data.heading.value : this.heading,
      mood: data.mood.present ? data.mood.value : this.mood,
      themes: data.themes.present ? data.themes.value : this.themes,
      revision: data.revision.present ? data.revision.value : this.revision,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DiaryDayRow(')
          ..write('dateKey: $dateKey, ')
          ..write('heading: $heading, ')
          ..write('mood: $mood, ')
          ..write('themes: $themes, ')
          ..write('revision: $revision')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(dateKey, heading, mood, themes, revision);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DiaryDayRow &&
          other.dateKey == this.dateKey &&
          other.heading == this.heading &&
          other.mood == this.mood &&
          other.themes == this.themes &&
          other.revision == this.revision);
}

class DiaryDaysCompanion extends UpdateCompanion<DiaryDayRow> {
  final Value<String> dateKey;
  final Value<String> heading;
  final Value<String?> mood;
  final Value<String> themes;
  final Value<int> revision;
  final Value<int> rowid;
  const DiaryDaysCompanion({
    this.dateKey = const Value.absent(),
    this.heading = const Value.absent(),
    this.mood = const Value.absent(),
    this.themes = const Value.absent(),
    this.revision = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DiaryDaysCompanion.insert({
    required String dateKey,
    required String heading,
    this.mood = const Value.absent(),
    this.themes = const Value.absent(),
    required int revision,
    this.rowid = const Value.absent(),
  }) : dateKey = Value(dateKey),
       heading = Value(heading),
       revision = Value(revision);
  static Insertable<DiaryDayRow> custom({
    Expression<String>? dateKey,
    Expression<String>? heading,
    Expression<String>? mood,
    Expression<String>? themes,
    Expression<int>? revision,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (dateKey != null) 'date_key': dateKey,
      if (heading != null) 'heading': heading,
      if (mood != null) 'mood': mood,
      if (themes != null) 'themes': themes,
      if (revision != null) 'revision': revision,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DiaryDaysCompanion copyWith({
    Value<String>? dateKey,
    Value<String>? heading,
    Value<String?>? mood,
    Value<String>? themes,
    Value<int>? revision,
    Value<int>? rowid,
  }) {
    return DiaryDaysCompanion(
      dateKey: dateKey ?? this.dateKey,
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
    if (dateKey.present) {
      map['date_key'] = Variable<String>(dateKey.value);
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
          ..write('dateKey: $dateKey, ')
          ..write('heading: $heading, ')
          ..write('mood: $mood, ')
          ..write('themes: $themes, ')
          ..write('revision: $revision, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FlowThoughtsTable extends FlowThoughts
    with TableInfo<$FlowThoughtsTable, ThoughtRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FlowThoughtsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
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
    body,
    revision,
    createdAt,
    updatedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'flow_thoughts';
  @override
  VerificationContext validateIntegrity(
    Insertable<ThoughtRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
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
  ThoughtRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ThoughtRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
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
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $FlowThoughtsTable createAlias(String alias) {
    return $FlowThoughtsTable(attachedDatabase, alias);
  }
}

class ThoughtRow extends DataClass implements Insertable<ThoughtRow> {
  final String id;
  final String body;
  final int revision;
  final int createdAt;
  final int updatedAt;
  final int? deletedAt;
  const ThoughtRow({
    required this.id,
    required this.body,
    required this.revision,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['body'] = Variable<String>(body);
    map['revision'] = Variable<int>(revision);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    return map;
  }

  FlowThoughtsCompanion toCompanion(bool nullToAbsent) {
    return FlowThoughtsCompanion(
      id: Value(id),
      body: Value(body),
      revision: Value(revision),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory ThoughtRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ThoughtRow(
      id: serializer.fromJson<String>(json['id']),
      body: serializer.fromJson<String>(json['body']),
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
      'body': serializer.toJson<String>(body),
      'revision': serializer.toJson<int>(revision),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'deletedAt': serializer.toJson<int?>(deletedAt),
    };
  }

  ThoughtRow copyWith({
    String? id,
    String? body,
    int? revision,
    int? createdAt,
    int? updatedAt,
    Value<int?> deletedAt = const Value.absent(),
  }) => ThoughtRow(
    id: id ?? this.id,
    body: body ?? this.body,
    revision: revision ?? this.revision,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  ThoughtRow copyWithCompanion(FlowThoughtsCompanion data) {
    return ThoughtRow(
      id: data.id.present ? data.id.value : this.id,
      body: data.body.present ? data.body.value : this.body,
      revision: data.revision.present ? data.revision.value : this.revision,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ThoughtRow(')
          ..write('id: $id, ')
          ..write('body: $body, ')
          ..write('revision: $revision, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, body, revision, createdAt, updatedAt, deletedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ThoughtRow &&
          other.id == this.id &&
          other.body == this.body &&
          other.revision == this.revision &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class FlowThoughtsCompanion extends UpdateCompanion<ThoughtRow> {
  final Value<String> id;
  final Value<String> body;
  final Value<int> revision;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int?> deletedAt;
  final Value<int> rowid;
  const FlowThoughtsCompanion({
    this.id = const Value.absent(),
    this.body = const Value.absent(),
    this.revision = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FlowThoughtsCompanion.insert({
    required String id,
    required String body,
    required int revision,
    required int createdAt,
    required int updatedAt,
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       body = Value(body),
       revision = Value(revision),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<ThoughtRow> custom({
    Expression<String>? id,
    Expression<String>? body,
    Expression<int>? revision,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (body != null) 'body': body,
      if (revision != null) 'revision': revision,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FlowThoughtsCompanion copyWith({
    Value<String>? id,
    Value<String>? body,
    Value<int>? revision,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int?>? deletedAt,
    Value<int>? rowid,
  }) {
    return FlowThoughtsCompanion(
      id: id ?? this.id,
      body: body ?? this.body,
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
    return (StringBuffer('FlowThoughtsCompanion(')
          ..write('id: $id, ')
          ..write('body: $body, ')
          ..write('revision: $revision, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BrainAssignmentsTableTable extends BrainAssignmentsTable
    with TableInfo<$BrainAssignmentsTableTable, BrainAssignmentRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BrainAssignmentsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _capabilityMeta = const VerificationMeta(
    'capability',
  );
  @override
  late final GeneratedColumn<String> capability = GeneratedColumn<String>(
    'capability',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _modelIdMeta = const VerificationMeta(
    'modelId',
  );
  @override
  late final GeneratedColumn<String> modelId = GeneratedColumn<String>(
    'model_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('device'),
  );
  @override
  List<GeneratedColumn> get $columns => [capability, modelId, source];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'brain_assignments';
  @override
  VerificationContext validateIntegrity(
    Insertable<BrainAssignmentRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('capability')) {
      context.handle(
        _capabilityMeta,
        capability.isAcceptableOrUnknown(data['capability']!, _capabilityMeta),
      );
    } else if (isInserting) {
      context.missing(_capabilityMeta);
    }
    if (data.containsKey('model_id')) {
      context.handle(
        _modelIdMeta,
        modelId.isAcceptableOrUnknown(data['model_id']!, _modelIdMeta),
      );
    } else if (isInserting) {
      context.missing(_modelIdMeta);
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {capability};
  @override
  BrainAssignmentRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BrainAssignmentRow(
      capability: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}capability'],
      )!,
      modelId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}model_id'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
    );
  }

  @override
  $BrainAssignmentsTableTable createAlias(String alias) {
    return $BrainAssignmentsTableTable(attachedDatabase, alias);
  }
}

class BrainAssignmentRow extends DataClass
    implements Insertable<BrainAssignmentRow> {
  final String capability;
  final String modelId;
  final String source;
  const BrainAssignmentRow({
    required this.capability,
    required this.modelId,
    required this.source,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['capability'] = Variable<String>(capability);
    map['model_id'] = Variable<String>(modelId);
    map['source'] = Variable<String>(source);
    return map;
  }

  BrainAssignmentsTableCompanion toCompanion(bool nullToAbsent) {
    return BrainAssignmentsTableCompanion(
      capability: Value(capability),
      modelId: Value(modelId),
      source: Value(source),
    );
  }

  factory BrainAssignmentRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BrainAssignmentRow(
      capability: serializer.fromJson<String>(json['capability']),
      modelId: serializer.fromJson<String>(json['modelId']),
      source: serializer.fromJson<String>(json['source']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'capability': serializer.toJson<String>(capability),
      'modelId': serializer.toJson<String>(modelId),
      'source': serializer.toJson<String>(source),
    };
  }

  BrainAssignmentRow copyWith({
    String? capability,
    String? modelId,
    String? source,
  }) => BrainAssignmentRow(
    capability: capability ?? this.capability,
    modelId: modelId ?? this.modelId,
    source: source ?? this.source,
  );
  BrainAssignmentRow copyWithCompanion(BrainAssignmentsTableCompanion data) {
    return BrainAssignmentRow(
      capability: data.capability.present
          ? data.capability.value
          : this.capability,
      modelId: data.modelId.present ? data.modelId.value : this.modelId,
      source: data.source.present ? data.source.value : this.source,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BrainAssignmentRow(')
          ..write('capability: $capability, ')
          ..write('modelId: $modelId, ')
          ..write('source: $source')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(capability, modelId, source);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BrainAssignmentRow &&
          other.capability == this.capability &&
          other.modelId == this.modelId &&
          other.source == this.source);
}

class BrainAssignmentsTableCompanion
    extends UpdateCompanion<BrainAssignmentRow> {
  final Value<String> capability;
  final Value<String> modelId;
  final Value<String> source;
  final Value<int> rowid;
  const BrainAssignmentsTableCompanion({
    this.capability = const Value.absent(),
    this.modelId = const Value.absent(),
    this.source = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BrainAssignmentsTableCompanion.insert({
    required String capability,
    required String modelId,
    this.source = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : capability = Value(capability),
       modelId = Value(modelId);
  static Insertable<BrainAssignmentRow> custom({
    Expression<String>? capability,
    Expression<String>? modelId,
    Expression<String>? source,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (capability != null) 'capability': capability,
      if (modelId != null) 'model_id': modelId,
      if (source != null) 'source': source,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BrainAssignmentsTableCompanion copyWith({
    Value<String>? capability,
    Value<String>? modelId,
    Value<String>? source,
    Value<int>? rowid,
  }) {
    return BrainAssignmentsTableCompanion(
      capability: capability ?? this.capability,
      modelId: modelId ?? this.modelId,
      source: source ?? this.source,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (capability.present) {
      map['capability'] = Variable<String>(capability.value);
    }
    if (modelId.present) {
      map['model_id'] = Variable<String>(modelId.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BrainAssignmentsTableCompanion(')
          ..write('capability: $capability, ')
          ..write('modelId: $modelId, ')
          ..write('source: $source, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncOperationsTable extends SyncOperations
    with TableInfo<$SyncOperationsTable, SyncOperation> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncOperationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
  static const VerificationMeta _documentIdMeta = const VerificationMeta(
    'documentId',
  );
  @override
  late final GeneratedColumn<String> documentId = GeneratedColumn<String>(
    'document_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [type, id, documentId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_operations';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncOperation> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('document_id')) {
      context.handle(
        _documentIdMeta,
        documentId.isAcceptableOrUnknown(data['document_id']!, _documentIdMeta),
      );
    } else if (isInserting) {
      context.missing(_documentIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {type, id};
  @override
  SyncOperation map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncOperation(
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      documentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}document_id'],
      )!,
    );
  }

  @override
  $SyncOperationsTable createAlias(String alias) {
    return $SyncOperationsTable(attachedDatabase, alias);
  }
}

class SyncOperation extends DataClass implements Insertable<SyncOperation> {
  final String type;
  final String id;
  final String documentId;
  const SyncOperation({
    required this.type,
    required this.id,
    required this.documentId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['type'] = Variable<String>(type);
    map['id'] = Variable<String>(id);
    map['document_id'] = Variable<String>(documentId);
    return map;
  }

  SyncOperationsCompanion toCompanion(bool nullToAbsent) {
    return SyncOperationsCompanion(
      type: Value(type),
      id: Value(id),
      documentId: Value(documentId),
    );
  }

  factory SyncOperation.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncOperation(
      type: serializer.fromJson<String>(json['type']),
      id: serializer.fromJson<String>(json['id']),
      documentId: serializer.fromJson<String>(json['documentId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'type': serializer.toJson<String>(type),
      'id': serializer.toJson<String>(id),
      'documentId': serializer.toJson<String>(documentId),
    };
  }

  SyncOperation copyWith({String? type, String? id, String? documentId}) =>
      SyncOperation(
        type: type ?? this.type,
        id: id ?? this.id,
        documentId: documentId ?? this.documentId,
      );
  SyncOperation copyWithCompanion(SyncOperationsCompanion data) {
    return SyncOperation(
      type: data.type.present ? data.type.value : this.type,
      id: data.id.present ? data.id.value : this.id,
      documentId: data.documentId.present
          ? data.documentId.value
          : this.documentId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncOperation(')
          ..write('type: $type, ')
          ..write('id: $id, ')
          ..write('documentId: $documentId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(type, id, documentId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncOperation &&
          other.type == this.type &&
          other.id == this.id &&
          other.documentId == this.documentId);
}

class SyncOperationsCompanion extends UpdateCompanion<SyncOperation> {
  final Value<String> type;
  final Value<String> id;
  final Value<String> documentId;
  final Value<int> rowid;
  const SyncOperationsCompanion({
    this.type = const Value.absent(),
    this.id = const Value.absent(),
    this.documentId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncOperationsCompanion.insert({
    required String type,
    required String id,
    required String documentId,
    this.rowid = const Value.absent(),
  }) : type = Value(type),
       id = Value(id),
       documentId = Value(documentId);
  static Insertable<SyncOperation> custom({
    Expression<String>? type,
    Expression<String>? id,
    Expression<String>? documentId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (type != null) 'type': type,
      if (id != null) 'id': id,
      if (documentId != null) 'document_id': documentId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncOperationsCompanion copyWith({
    Value<String>? type,
    Value<String>? id,
    Value<String>? documentId,
    Value<int>? rowid,
  }) {
    return SyncOperationsCompanion(
      type: type ?? this.type,
      id: id ?? this.id,
      documentId: documentId ?? this.documentId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (documentId.present) {
      map['document_id'] = Variable<String>(documentId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncOperationsCompanion(')
          ..write('type: $type, ')
          ..write('id: $id, ')
          ..write('documentId: $documentId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncValuesTable extends SyncValues
    with TableInfo<$SyncValuesTable, SyncValue> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncValuesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
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
  static const String $name = 'sync_values';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncValue> instance, {
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
  SyncValue map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncValue(
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
  $SyncValuesTable createAlias(String alias) {
    return $SyncValuesTable(attachedDatabase, alias);
  }
}

class SyncValue extends DataClass implements Insertable<SyncValue> {
  final String key;
  final String value;
  const SyncValue({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  SyncValuesCompanion toCompanion(bool nullToAbsent) {
    return SyncValuesCompanion(key: Value(key), value: Value(value));
  }

  factory SyncValue.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncValue(
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

  SyncValue copyWith({String? key, String? value}) =>
      SyncValue(key: key ?? this.key, value: value ?? this.value);
  SyncValue copyWithCompanion(SyncValuesCompanion data) {
    return SyncValue(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncValue(')
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
      (other is SyncValue &&
          other.key == this.key &&
          other.value == this.value);
}

class SyncValuesCompanion extends UpdateCompanion<SyncValue> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const SyncValuesCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncValuesCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<SyncValue> custom({
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

  SyncValuesCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return SyncValuesCompanion(
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
    return (StringBuffer('SyncValuesCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncRecordsTable extends SyncRecords
    with TableInfo<$SyncRecordsTable, SyncRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _documentIdMeta = const VerificationMeta(
    'documentId',
  );
  @override
  late final GeneratedColumn<String> documentId = GeneratedColumn<String>(
    'document_id',
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
    defaultValue: const Constant('pending'),
  );
  static const VerificationMeta _removedMeta = const VerificationMeta(
    'removed',
  );
  @override
  late final GeneratedColumn<bool> removed = GeneratedColumn<bool>(
    'removed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("removed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [type, documentId, state, removed];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_records';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('document_id')) {
      context.handle(
        _documentIdMeta,
        documentId.isAcceptableOrUnknown(data['document_id']!, _documentIdMeta),
      );
    } else if (isInserting) {
      context.missing(_documentIdMeta);
    }
    if (data.containsKey('state')) {
      context.handle(
        _stateMeta,
        state.isAcceptableOrUnknown(data['state']!, _stateMeta),
      );
    }
    if (data.containsKey('removed')) {
      context.handle(
        _removedMeta,
        removed.isAcceptableOrUnknown(data['removed']!, _removedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {type, documentId};
  @override
  SyncRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncRecord(
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      documentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}document_id'],
      )!,
      state: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}state'],
      )!,
      removed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}removed'],
      )!,
    );
  }

  @override
  $SyncRecordsTable createAlias(String alias) {
    return $SyncRecordsTable(attachedDatabase, alias);
  }
}

class SyncRecord extends DataClass implements Insertable<SyncRecord> {
  final String type;
  final String documentId;
  final String state;
  final bool removed;
  const SyncRecord({
    required this.type,
    required this.documentId,
    required this.state,
    required this.removed,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['type'] = Variable<String>(type);
    map['document_id'] = Variable<String>(documentId);
    map['state'] = Variable<String>(state);
    map['removed'] = Variable<bool>(removed);
    return map;
  }

  SyncRecordsCompanion toCompanion(bool nullToAbsent) {
    return SyncRecordsCompanion(
      type: Value(type),
      documentId: Value(documentId),
      state: Value(state),
      removed: Value(removed),
    );
  }

  factory SyncRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncRecord(
      type: serializer.fromJson<String>(json['type']),
      documentId: serializer.fromJson<String>(json['documentId']),
      state: serializer.fromJson<String>(json['state']),
      removed: serializer.fromJson<bool>(json['removed']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'type': serializer.toJson<String>(type),
      'documentId': serializer.toJson<String>(documentId),
      'state': serializer.toJson<String>(state),
      'removed': serializer.toJson<bool>(removed),
    };
  }

  SyncRecord copyWith({
    String? type,
    String? documentId,
    String? state,
    bool? removed,
  }) => SyncRecord(
    type: type ?? this.type,
    documentId: documentId ?? this.documentId,
    state: state ?? this.state,
    removed: removed ?? this.removed,
  );
  SyncRecord copyWithCompanion(SyncRecordsCompanion data) {
    return SyncRecord(
      type: data.type.present ? data.type.value : this.type,
      documentId: data.documentId.present
          ? data.documentId.value
          : this.documentId,
      state: data.state.present ? data.state.value : this.state,
      removed: data.removed.present ? data.removed.value : this.removed,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncRecord(')
          ..write('type: $type, ')
          ..write('documentId: $documentId, ')
          ..write('state: $state, ')
          ..write('removed: $removed')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(type, documentId, state, removed);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncRecord &&
          other.type == this.type &&
          other.documentId == this.documentId &&
          other.state == this.state &&
          other.removed == this.removed);
}

class SyncRecordsCompanion extends UpdateCompanion<SyncRecord> {
  final Value<String> type;
  final Value<String> documentId;
  final Value<String> state;
  final Value<bool> removed;
  final Value<int> rowid;
  const SyncRecordsCompanion({
    this.type = const Value.absent(),
    this.documentId = const Value.absent(),
    this.state = const Value.absent(),
    this.removed = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncRecordsCompanion.insert({
    required String type,
    required String documentId,
    this.state = const Value.absent(),
    this.removed = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : type = Value(type),
       documentId = Value(documentId);
  static Insertable<SyncRecord> custom({
    Expression<String>? type,
    Expression<String>? documentId,
    Expression<String>? state,
    Expression<bool>? removed,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (type != null) 'type': type,
      if (documentId != null) 'document_id': documentId,
      if (state != null) 'state': state,
      if (removed != null) 'removed': removed,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncRecordsCompanion copyWith({
    Value<String>? type,
    Value<String>? documentId,
    Value<String>? state,
    Value<bool>? removed,
    Value<int>? rowid,
  }) {
    return SyncRecordsCompanion(
      type: type ?? this.type,
      documentId: documentId ?? this.documentId,
      state: state ?? this.state,
      removed: removed ?? this.removed,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (documentId.present) {
      map['document_id'] = Variable<String>(documentId.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(state.value);
    }
    if (removed.present) {
      map['removed'] = Variable<bool>(removed.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncRecordsCompanion(')
          ..write('type: $type, ')
          ..write('documentId: $documentId, ')
          ..write('state: $state, ')
          ..write('removed: $removed, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $AiPreferencesTableTable aiPreferencesTable =
      $AiPreferencesTableTable(this);
  late final $AiJobReceiptsTable aiJobReceipts = $AiJobReceiptsTable(this);
  late final $RecallQueueTable recallQueue = $RecallQueueTable(this);
  late final $RecallManifestsTable recallManifests = $RecallManifestsTable(
    this,
  );
  late final $DailyQuestionsTable dailyQuestions = $DailyQuestionsTable(this);
  late final $AppearanceSettingsTable appearanceSettings =
      $AppearanceSettingsTable(this);
  late final $OnboardingCompletionTable onboardingCompletion =
      $OnboardingCompletionTable(this);
  late final $NotesTable notes = $NotesTable(this);
  late final $NoteDraftsTable noteDrafts = $NoteDraftsTable(this);
  late final $NoteTagsTable noteTags = $NoteTagsTable(this);
  late final $DiaryEntriesTable diaryEntries = $DiaryEntriesTable(this);
  late final $DiaryDaysTable diaryDays = $DiaryDaysTable(this);
  late final $FlowThoughtsTable flowThoughts = $FlowThoughtsTable(this);
  late final $BrainAssignmentsTableTable brainAssignmentsTable =
      $BrainAssignmentsTableTable(this);
  late final $SyncOperationsTable syncOperations = $SyncOperationsTable(this);
  late final $SyncValuesTable syncValues = $SyncValuesTable(this);
  late final $SyncRecordsTable syncRecords = $SyncRecordsTable(this);
  late final Index diaryEntriesDayOrder = Index(
    'diary_entries_day_order',
    'CREATE INDEX diary_entries_day_order ON diary_entries (date_key, created_at, id)',
  );
  late final Index flowThoughtsOrder = Index(
    'flow_thoughts_order',
    'CREATE INDEX flow_thoughts_order ON flow_thoughts (created_at DESC, id DESC)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    aiPreferencesTable,
    aiJobReceipts,
    recallQueue,
    recallManifests,
    dailyQuestions,
    appearanceSettings,
    onboardingCompletion,
    notes,
    noteDrafts,
    noteTags,
    diaryEntries,
    diaryDays,
    flowThoughts,
    brainAssignmentsTable,
    syncOperations,
    syncValues,
    syncRecords,
    diaryEntriesDayOrder,
    flowThoughtsOrder,
  ];
}

typedef $$AiPreferencesTableTableCreateCompanionBuilder =
    AiPreferencesTableCompanion Function({
      Value<int> id,
      Value<String> mode,
      Value<String> overrides,
      Value<bool> dailyQuestions,
      Value<bool> recallNotes,
      Value<bool> recallDiary,
      Value<bool> recallFlow,
      Value<bool> recallPaused,
      Value<bool> recallCleanupRequired,
      Value<String?> replyVoice,
    });
typedef $$AiPreferencesTableTableUpdateCompanionBuilder =
    AiPreferencesTableCompanion Function({
      Value<int> id,
      Value<String> mode,
      Value<String> overrides,
      Value<bool> dailyQuestions,
      Value<bool> recallNotes,
      Value<bool> recallDiary,
      Value<bool> recallFlow,
      Value<bool> recallPaused,
      Value<bool> recallCleanupRequired,
      Value<String?> replyVoice,
    });

class $$AiPreferencesTableTableFilterComposer
    extends Composer<_$AppDatabase, $AiPreferencesTableTable> {
  $$AiPreferencesTableTableFilterComposer({
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

  ColumnFilters<String> get mode => $composableBuilder(
    column: $table.mode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get overrides => $composableBuilder(
    column: $table.overrides,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get dailyQuestions => $composableBuilder(
    column: $table.dailyQuestions,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get recallNotes => $composableBuilder(
    column: $table.recallNotes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get recallDiary => $composableBuilder(
    column: $table.recallDiary,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get recallFlow => $composableBuilder(
    column: $table.recallFlow,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get recallPaused => $composableBuilder(
    column: $table.recallPaused,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get recallCleanupRequired => $composableBuilder(
    column: $table.recallCleanupRequired,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get replyVoice => $composableBuilder(
    column: $table.replyVoice,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AiPreferencesTableTableOrderingComposer
    extends Composer<_$AppDatabase, $AiPreferencesTableTable> {
  $$AiPreferencesTableTableOrderingComposer({
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

  ColumnOrderings<String> get mode => $composableBuilder(
    column: $table.mode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get overrides => $composableBuilder(
    column: $table.overrides,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get dailyQuestions => $composableBuilder(
    column: $table.dailyQuestions,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get recallNotes => $composableBuilder(
    column: $table.recallNotes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get recallDiary => $composableBuilder(
    column: $table.recallDiary,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get recallFlow => $composableBuilder(
    column: $table.recallFlow,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get recallPaused => $composableBuilder(
    column: $table.recallPaused,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get recallCleanupRequired => $composableBuilder(
    column: $table.recallCleanupRequired,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get replyVoice => $composableBuilder(
    column: $table.replyVoice,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AiPreferencesTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $AiPreferencesTableTable> {
  $$AiPreferencesTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get mode =>
      $composableBuilder(column: $table.mode, builder: (column) => column);

  GeneratedColumn<String> get overrides =>
      $composableBuilder(column: $table.overrides, builder: (column) => column);

  GeneratedColumn<bool> get dailyQuestions => $composableBuilder(
    column: $table.dailyQuestions,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get recallNotes => $composableBuilder(
    column: $table.recallNotes,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get recallDiary => $composableBuilder(
    column: $table.recallDiary,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get recallFlow => $composableBuilder(
    column: $table.recallFlow,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get recallPaused => $composableBuilder(
    column: $table.recallPaused,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get recallCleanupRequired => $composableBuilder(
    column: $table.recallCleanupRequired,
    builder: (column) => column,
  );

  GeneratedColumn<String> get replyVoice => $composableBuilder(
    column: $table.replyVoice,
    builder: (column) => column,
  );
}

class $$AiPreferencesTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AiPreferencesTableTable,
          AiPreferenceRow,
          $$AiPreferencesTableTableFilterComposer,
          $$AiPreferencesTableTableOrderingComposer,
          $$AiPreferencesTableTableAnnotationComposer,
          $$AiPreferencesTableTableCreateCompanionBuilder,
          $$AiPreferencesTableTableUpdateCompanionBuilder,
          (
            AiPreferenceRow,
            BaseReferences<
              _$AppDatabase,
              $AiPreferencesTableTable,
              AiPreferenceRow
            >,
          ),
          AiPreferenceRow,
          PrefetchHooks Function()
        > {
  $$AiPreferencesTableTableTableManager(
    _$AppDatabase db,
    $AiPreferencesTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AiPreferencesTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AiPreferencesTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AiPreferencesTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> mode = const Value.absent(),
                Value<String> overrides = const Value.absent(),
                Value<bool> dailyQuestions = const Value.absent(),
                Value<bool> recallNotes = const Value.absent(),
                Value<bool> recallDiary = const Value.absent(),
                Value<bool> recallFlow = const Value.absent(),
                Value<bool> recallPaused = const Value.absent(),
                Value<bool> recallCleanupRequired = const Value.absent(),
                Value<String?> replyVoice = const Value.absent(),
              }) => AiPreferencesTableCompanion(
                id: id,
                mode: mode,
                overrides: overrides,
                dailyQuestions: dailyQuestions,
                recallNotes: recallNotes,
                recallDiary: recallDiary,
                recallFlow: recallFlow,
                recallPaused: recallPaused,
                recallCleanupRequired: recallCleanupRequired,
                replyVoice: replyVoice,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> mode = const Value.absent(),
                Value<String> overrides = const Value.absent(),
                Value<bool> dailyQuestions = const Value.absent(),
                Value<bool> recallNotes = const Value.absent(),
                Value<bool> recallDiary = const Value.absent(),
                Value<bool> recallFlow = const Value.absent(),
                Value<bool> recallPaused = const Value.absent(),
                Value<bool> recallCleanupRequired = const Value.absent(),
                Value<String?> replyVoice = const Value.absent(),
              }) => AiPreferencesTableCompanion.insert(
                id: id,
                mode: mode,
                overrides: overrides,
                dailyQuestions: dailyQuestions,
                recallNotes: recallNotes,
                recallDiary: recallDiary,
                recallFlow: recallFlow,
                recallPaused: recallPaused,
                recallCleanupRequired: recallCleanupRequired,
                replyVoice: replyVoice,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AiPreferencesTableTable, AiPreferenceRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $AiPreferencesTableTable,
                    AiPreferenceRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AiPreferencesTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AiPreferencesTableTable,
      AiPreferenceRow,
      $$AiPreferencesTableTableFilterComposer,
      $$AiPreferencesTableTableOrderingComposer,
      $$AiPreferencesTableTableAnnotationComposer,
      $$AiPreferencesTableTableCreateCompanionBuilder,
      $$AiPreferencesTableTableUpdateCompanionBuilder,
      (
        AiPreferenceRow,
        BaseReferences<
          _$AppDatabase,
          $AiPreferencesTableTable,
          AiPreferenceRow
        >,
      ),
      AiPreferenceRow,
      PrefetchHooks Function()
    >;
typedef $$AiJobReceiptsTableCreateCompanionBuilder =
    AiJobReceiptsCompanion Function({
      required String id,
      required String metadata,
      Value<bool> active,
      required int created,
      Value<int> rowid,
    });
typedef $$AiJobReceiptsTableUpdateCompanionBuilder =
    AiJobReceiptsCompanion Function({
      Value<String> id,
      Value<String> metadata,
      Value<bool> active,
      Value<int> created,
      Value<int> rowid,
    });

class $$AiJobReceiptsTableFilterComposer
    extends Composer<_$AppDatabase, $AiJobReceiptsTable> {
  $$AiJobReceiptsTableFilterComposer({
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

  ColumnFilters<String> get metadata => $composableBuilder(
    column: $table.metadata,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get active => $composableBuilder(
    column: $table.active,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get created => $composableBuilder(
    column: $table.created,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AiJobReceiptsTableOrderingComposer
    extends Composer<_$AppDatabase, $AiJobReceiptsTable> {
  $$AiJobReceiptsTableOrderingComposer({
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

  ColumnOrderings<String> get metadata => $composableBuilder(
    column: $table.metadata,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get active => $composableBuilder(
    column: $table.active,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get created => $composableBuilder(
    column: $table.created,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AiJobReceiptsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AiJobReceiptsTable> {
  $$AiJobReceiptsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get metadata =>
      $composableBuilder(column: $table.metadata, builder: (column) => column);

  GeneratedColumn<bool> get active =>
      $composableBuilder(column: $table.active, builder: (column) => column);

  GeneratedColumn<int> get created =>
      $composableBuilder(column: $table.created, builder: (column) => column);
}

class $$AiJobReceiptsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AiJobReceiptsTable,
          AiJobReceiptRow,
          $$AiJobReceiptsTableFilterComposer,
          $$AiJobReceiptsTableOrderingComposer,
          $$AiJobReceiptsTableAnnotationComposer,
          $$AiJobReceiptsTableCreateCompanionBuilder,
          $$AiJobReceiptsTableUpdateCompanionBuilder,
          (
            AiJobReceiptRow,
            BaseReferences<_$AppDatabase, $AiJobReceiptsTable, AiJobReceiptRow>,
          ),
          AiJobReceiptRow,
          PrefetchHooks Function()
        > {
  $$AiJobReceiptsTableTableManager(_$AppDatabase db, $AiJobReceiptsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AiJobReceiptsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AiJobReceiptsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AiJobReceiptsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> metadata = const Value.absent(),
                Value<bool> active = const Value.absent(),
                Value<int> created = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AiJobReceiptsCompanion(
                id: id,
                metadata: metadata,
                active: active,
                created: created,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String metadata,
                Value<bool> active = const Value.absent(),
                required int created,
                Value<int> rowid = const Value.absent(),
              }) => AiJobReceiptsCompanion.insert(
                id: id,
                metadata: metadata,
                active: active,
                created: created,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AiJobReceiptsTable, AiJobReceiptRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $AiJobReceiptsTable,
                    AiJobReceiptRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AiJobReceiptsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AiJobReceiptsTable,
      AiJobReceiptRow,
      $$AiJobReceiptsTableFilterComposer,
      $$AiJobReceiptsTableOrderingComposer,
      $$AiJobReceiptsTableAnnotationComposer,
      $$AiJobReceiptsTableCreateCompanionBuilder,
      $$AiJobReceiptsTableUpdateCompanionBuilder,
      (
        AiJobReceiptRow,
        BaseReferences<_$AppDatabase, $AiJobReceiptsTable, AiJobReceiptRow>,
      ),
      AiJobReceiptRow,
      PrefetchHooks Function()
    >;
typedef $$RecallQueueTableCreateCompanionBuilder =
    RecallQueueCompanion Function({
      required String kind,
      required String sourceId,
      Value<int> generation,
      Value<int> rowid,
    });
typedef $$RecallQueueTableUpdateCompanionBuilder =
    RecallQueueCompanion Function({
      Value<String> kind,
      Value<String> sourceId,
      Value<int> generation,
      Value<int> rowid,
    });

class $$RecallQueueTableFilterComposer
    extends Composer<_$AppDatabase, $RecallQueueTable> {
  $$RecallQueueTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get generation => $composableBuilder(
    column: $table.generation,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RecallQueueTableOrderingComposer
    extends Composer<_$AppDatabase, $RecallQueueTable> {
  $$RecallQueueTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get generation => $composableBuilder(
    column: $table.generation,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RecallQueueTableAnnotationComposer
    extends Composer<_$AppDatabase, $RecallQueueTable> {
  $$RecallQueueTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get sourceId =>
      $composableBuilder(column: $table.sourceId, builder: (column) => column);

  GeneratedColumn<int> get generation => $composableBuilder(
    column: $table.generation,
    builder: (column) => column,
  );
}

class $$RecallQueueTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RecallQueueTable,
          RecallQueueRow,
          $$RecallQueueTableFilterComposer,
          $$RecallQueueTableOrderingComposer,
          $$RecallQueueTableAnnotationComposer,
          $$RecallQueueTableCreateCompanionBuilder,
          $$RecallQueueTableUpdateCompanionBuilder,
          (
            RecallQueueRow,
            BaseReferences<_$AppDatabase, $RecallQueueTable, RecallQueueRow>,
          ),
          RecallQueueRow,
          PrefetchHooks Function()
        > {
  $$RecallQueueTableTableManager(_$AppDatabase db, $RecallQueueTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RecallQueueTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RecallQueueTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RecallQueueTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> kind = const Value.absent(),
                Value<String> sourceId = const Value.absent(),
                Value<int> generation = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RecallQueueCompanion(
                kind: kind,
                sourceId: sourceId,
                generation: generation,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String kind,
                required String sourceId,
                Value<int> generation = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RecallQueueCompanion.insert(
                kind: kind,
                sourceId: sourceId,
                generation: generation,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$RecallQueueTable, RecallQueueRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $RecallQueueTable,
                    RecallQueueRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RecallQueueTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RecallQueueTable,
      RecallQueueRow,
      $$RecallQueueTableFilterComposer,
      $$RecallQueueTableOrderingComposer,
      $$RecallQueueTableAnnotationComposer,
      $$RecallQueueTableCreateCompanionBuilder,
      $$RecallQueueTableUpdateCompanionBuilder,
      (
        RecallQueueRow,
        BaseReferences<_$AppDatabase, $RecallQueueTable, RecallQueueRow>,
      ),
      RecallQueueRow,
      PrefetchHooks Function()
    >;
typedef $$RecallManifestsTableCreateCompanionBuilder =
    RecallManifestsCompanion Function({
      required String profile,
      required String kind,
      required String sourceId,
      required String hash,
      required int revision,
      required String chunks,
      Value<bool> complete,
      Value<int> rowid,
    });
typedef $$RecallManifestsTableUpdateCompanionBuilder =
    RecallManifestsCompanion Function({
      Value<String> profile,
      Value<String> kind,
      Value<String> sourceId,
      Value<String> hash,
      Value<int> revision,
      Value<String> chunks,
      Value<bool> complete,
      Value<int> rowid,
    });

class $$RecallManifestsTableFilterComposer
    extends Composer<_$AppDatabase, $RecallManifestsTable> {
  $$RecallManifestsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get profile => $composableBuilder(
    column: $table.profile,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get hash => $composableBuilder(
    column: $table.hash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get chunks => $composableBuilder(
    column: $table.chunks,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get complete => $composableBuilder(
    column: $table.complete,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RecallManifestsTableOrderingComposer
    extends Composer<_$AppDatabase, $RecallManifestsTable> {
  $$RecallManifestsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get profile => $composableBuilder(
    column: $table.profile,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get hash => $composableBuilder(
    column: $table.hash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get chunks => $composableBuilder(
    column: $table.chunks,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get complete => $composableBuilder(
    column: $table.complete,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RecallManifestsTableAnnotationComposer
    extends Composer<_$AppDatabase, $RecallManifestsTable> {
  $$RecallManifestsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get profile =>
      $composableBuilder(column: $table.profile, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get sourceId =>
      $composableBuilder(column: $table.sourceId, builder: (column) => column);

  GeneratedColumn<String> get hash =>
      $composableBuilder(column: $table.hash, builder: (column) => column);

  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);

  GeneratedColumn<String> get chunks =>
      $composableBuilder(column: $table.chunks, builder: (column) => column);

  GeneratedColumn<bool> get complete =>
      $composableBuilder(column: $table.complete, builder: (column) => column);
}

class $$RecallManifestsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RecallManifestsTable,
          RecallManifestRow,
          $$RecallManifestsTableFilterComposer,
          $$RecallManifestsTableOrderingComposer,
          $$RecallManifestsTableAnnotationComposer,
          $$RecallManifestsTableCreateCompanionBuilder,
          $$RecallManifestsTableUpdateCompanionBuilder,
          (
            RecallManifestRow,
            BaseReferences<
              _$AppDatabase,
              $RecallManifestsTable,
              RecallManifestRow
            >,
          ),
          RecallManifestRow,
          PrefetchHooks Function()
        > {
  $$RecallManifestsTableTableManager(
    _$AppDatabase db,
    $RecallManifestsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RecallManifestsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RecallManifestsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RecallManifestsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> profile = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> sourceId = const Value.absent(),
                Value<String> hash = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<String> chunks = const Value.absent(),
                Value<bool> complete = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RecallManifestsCompanion(
                profile: profile,
                kind: kind,
                sourceId: sourceId,
                hash: hash,
                revision: revision,
                chunks: chunks,
                complete: complete,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String profile,
                required String kind,
                required String sourceId,
                required String hash,
                required int revision,
                required String chunks,
                Value<bool> complete = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RecallManifestsCompanion.insert(
                profile: profile,
                kind: kind,
                sourceId: sourceId,
                hash: hash,
                revision: revision,
                chunks: chunks,
                complete: complete,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$RecallManifestsTable, RecallManifestRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $RecallManifestsTable,
                    RecallManifestRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RecallManifestsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RecallManifestsTable,
      RecallManifestRow,
      $$RecallManifestsTableFilterComposer,
      $$RecallManifestsTableOrderingComposer,
      $$RecallManifestsTableAnnotationComposer,
      $$RecallManifestsTableCreateCompanionBuilder,
      $$RecallManifestsTableUpdateCompanionBuilder,
      (
        RecallManifestRow,
        BaseReferences<_$AppDatabase, $RecallManifestsTable, RecallManifestRow>,
      ),
      RecallManifestRow,
      PrefetchHooks Function()
    >;
typedef $$DailyQuestionsTableCreateCompanionBuilder =
    DailyQuestionsCompanion Function({
      required String id,
      required String day,
      required String question,
      Value<String> sourceDate,
      Value<String> sourceId,
      Value<String> sourceHash,
      Value<String> evidence,
      Value<int> ago,
      required String basis,
      Value<String> sources,
      Value<bool> shown,
      required int created,
      Value<int> rowid,
    });
typedef $$DailyQuestionsTableUpdateCompanionBuilder =
    DailyQuestionsCompanion Function({
      Value<String> id,
      Value<String> day,
      Value<String> question,
      Value<String> sourceDate,
      Value<String> sourceId,
      Value<String> sourceHash,
      Value<String> evidence,
      Value<int> ago,
      Value<String> basis,
      Value<String> sources,
      Value<bool> shown,
      Value<int> created,
      Value<int> rowid,
    });

class $$DailyQuestionsTableFilterComposer
    extends Composer<_$AppDatabase, $DailyQuestionsTable> {
  $$DailyQuestionsTableFilterComposer({
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

  ColumnFilters<String> get day => $composableBuilder(
    column: $table.day,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get question => $composableBuilder(
    column: $table.question,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceDate => $composableBuilder(
    column: $table.sourceDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceHash => $composableBuilder(
    column: $table.sourceHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get evidence => $composableBuilder(
    column: $table.evidence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get ago => $composableBuilder(
    column: $table.ago,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get basis => $composableBuilder(
    column: $table.basis,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sources => $composableBuilder(
    column: $table.sources,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get shown => $composableBuilder(
    column: $table.shown,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get created => $composableBuilder(
    column: $table.created,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DailyQuestionsTableOrderingComposer
    extends Composer<_$AppDatabase, $DailyQuestionsTable> {
  $$DailyQuestionsTableOrderingComposer({
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

  ColumnOrderings<String> get day => $composableBuilder(
    column: $table.day,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get question => $composableBuilder(
    column: $table.question,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceDate => $composableBuilder(
    column: $table.sourceDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceHash => $composableBuilder(
    column: $table.sourceHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get evidence => $composableBuilder(
    column: $table.evidence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get ago => $composableBuilder(
    column: $table.ago,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get basis => $composableBuilder(
    column: $table.basis,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sources => $composableBuilder(
    column: $table.sources,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get shown => $composableBuilder(
    column: $table.shown,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get created => $composableBuilder(
    column: $table.created,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DailyQuestionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DailyQuestionsTable> {
  $$DailyQuestionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get day =>
      $composableBuilder(column: $table.day, builder: (column) => column);

  GeneratedColumn<String> get question =>
      $composableBuilder(column: $table.question, builder: (column) => column);

  GeneratedColumn<String> get sourceDate => $composableBuilder(
    column: $table.sourceDate,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceId =>
      $composableBuilder(column: $table.sourceId, builder: (column) => column);

  GeneratedColumn<String> get sourceHash => $composableBuilder(
    column: $table.sourceHash,
    builder: (column) => column,
  );

  GeneratedColumn<String> get evidence =>
      $composableBuilder(column: $table.evidence, builder: (column) => column);

  GeneratedColumn<int> get ago =>
      $composableBuilder(column: $table.ago, builder: (column) => column);

  GeneratedColumn<String> get basis =>
      $composableBuilder(column: $table.basis, builder: (column) => column);

  GeneratedColumn<String> get sources =>
      $composableBuilder(column: $table.sources, builder: (column) => column);

  GeneratedColumn<bool> get shown =>
      $composableBuilder(column: $table.shown, builder: (column) => column);

  GeneratedColumn<int> get created =>
      $composableBuilder(column: $table.created, builder: (column) => column);
}

class $$DailyQuestionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DailyQuestionsTable,
          DailyQuestionRow,
          $$DailyQuestionsTableFilterComposer,
          $$DailyQuestionsTableOrderingComposer,
          $$DailyQuestionsTableAnnotationComposer,
          $$DailyQuestionsTableCreateCompanionBuilder,
          $$DailyQuestionsTableUpdateCompanionBuilder,
          (
            DailyQuestionRow,
            BaseReferences<
              _$AppDatabase,
              $DailyQuestionsTable,
              DailyQuestionRow
            >,
          ),
          DailyQuestionRow,
          PrefetchHooks Function()
        > {
  $$DailyQuestionsTableTableManager(
    _$AppDatabase db,
    $DailyQuestionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DailyQuestionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DailyQuestionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DailyQuestionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> day = const Value.absent(),
                Value<String> question = const Value.absent(),
                Value<String> sourceDate = const Value.absent(),
                Value<String> sourceId = const Value.absent(),
                Value<String> sourceHash = const Value.absent(),
                Value<String> evidence = const Value.absent(),
                Value<int> ago = const Value.absent(),
                Value<String> basis = const Value.absent(),
                Value<String> sources = const Value.absent(),
                Value<bool> shown = const Value.absent(),
                Value<int> created = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DailyQuestionsCompanion(
                id: id,
                day: day,
                question: question,
                sourceDate: sourceDate,
                sourceId: sourceId,
                sourceHash: sourceHash,
                evidence: evidence,
                ago: ago,
                basis: basis,
                sources: sources,
                shown: shown,
                created: created,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String day,
                required String question,
                Value<String> sourceDate = const Value.absent(),
                Value<String> sourceId = const Value.absent(),
                Value<String> sourceHash = const Value.absent(),
                Value<String> evidence = const Value.absent(),
                Value<int> ago = const Value.absent(),
                required String basis,
                Value<String> sources = const Value.absent(),
                Value<bool> shown = const Value.absent(),
                required int created,
                Value<int> rowid = const Value.absent(),
              }) => DailyQuestionsCompanion.insert(
                id: id,
                day: day,
                question: question,
                sourceDate: sourceDate,
                sourceId: sourceId,
                sourceHash: sourceHash,
                evidence: evidence,
                ago: ago,
                basis: basis,
                sources: sources,
                shown: shown,
                created: created,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$DailyQuestionsTable, DailyQuestionRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $DailyQuestionsTable,
                    DailyQuestionRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DailyQuestionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DailyQuestionsTable,
      DailyQuestionRow,
      $$DailyQuestionsTableFilterComposer,
      $$DailyQuestionsTableOrderingComposer,
      $$DailyQuestionsTableAnnotationComposer,
      $$DailyQuestionsTableCreateCompanionBuilder,
      $$DailyQuestionsTableUpdateCompanionBuilder,
      (
        DailyQuestionRow,
        BaseReferences<_$AppDatabase, $DailyQuestionsTable, DailyQuestionRow>,
      ),
      DailyQuestionRow,
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
      Value<String?> name,
    });
typedef $$OnboardingCompletionTableUpdateCompanionBuilder =
    OnboardingCompletionCompanion Function({
      Value<int> id,
      Value<String?> name,
    });

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
            Value<String?> name = const Value.absent(),
          }) => OnboardingCompletionCompanion(id: id, name: name),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String?> name = const Value.absent(),
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
}

class $$NotesTableFilterComposer extends Composer<_$AppDatabase, $NotesTable> {
  $$NotesTableFilterComposer({
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
          PrefetchHooks Function({bool noteTagsRefs})
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
          prefetchHooksCallback: ({noteTagsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (noteTagsRefs) db.noteTags],
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
                          $$NotesTableReferences(db, table, p0).noteTagsRefs,
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
      PrefetchHooks Function({bool noteTagsRefs})
    >;
typedef $$NoteDraftsTableCreateCompanionBuilder = NoteDraftsCompanion Function({
  required String id,
  required String title,
  required String body,
  required int baseRevision,
  Value<int> draftRevision,
  required int updatedAt,
});
typedef $$NoteDraftsTableUpdateCompanionBuilder = NoteDraftsCompanion Function({
  Value<String> id,
  Value<String> title,
  Value<String> body,
  Value<int> baseRevision,
  Value<int> draftRevision,
  Value<int> updatedAt,
});

class $$NoteDraftsTableFilterComposer
    extends Composer<_$AppDatabase, $NoteDraftsTable> {
  $$NoteDraftsTableFilterComposer({
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

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get baseRevision => $composableBuilder(
    column: $table.baseRevision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get draftRevision => $composableBuilder(
    column: $table.draftRevision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$NoteDraftsTableOrderingComposer
    extends Composer<_$AppDatabase, $NoteDraftsTable> {
  $$NoteDraftsTableOrderingComposer({
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

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get baseRevision => $composableBuilder(
    column: $table.baseRevision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get draftRevision => $composableBuilder(
    column: $table.draftRevision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$NoteDraftsTableAnnotationComposer
    extends Composer<_$AppDatabase, $NoteDraftsTable> {
  $$NoteDraftsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<int> get baseRevision => $composableBuilder(
    column: $table.baseRevision,
    builder: (column) => column,
  );

  GeneratedColumn<int> get draftRevision => $composableBuilder(
    column: $table.draftRevision,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$NoteDraftsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $NoteDraftsTable,
          NoteDraft,
          $$NoteDraftsTableFilterComposer,
          $$NoteDraftsTableOrderingComposer,
          $$NoteDraftsTableAnnotationComposer,
          $$NoteDraftsTableCreateCompanionBuilder,
          $$NoteDraftsTableUpdateCompanionBuilder,
          (
            NoteDraft,
            BaseReferences<_$AppDatabase, $NoteDraftsTable, NoteDraft>,
          ),
          NoteDraft,
          PrefetchHooks Function()
        > {
  $$NoteDraftsTableTableManager(_$AppDatabase db, $NoteDraftsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NoteDraftsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$NoteDraftsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$NoteDraftsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> body = const Value.absent(),
                Value<int> baseRevision = const Value.absent(),
                Value<int> draftRevision = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
              }) => NoteDraftsCompanion(
                id: id,
                title: title,
                body: body,
                baseRevision: baseRevision,
                draftRevision: draftRevision,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String title,
                required String body,
                required int baseRevision,
                Value<int> draftRevision = const Value.absent(),
                required int updatedAt,
              }) => NoteDraftsCompanion.insert(
                id: id,
                title: title,
                body: body,
                baseRevision: baseRevision,
                draftRevision: draftRevision,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$NoteDraftsTable, NoteDraft>(table),
                  BaseReferences<_$AppDatabase, $NoteDraftsTable, NoteDraft>(
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

typedef $$NoteDraftsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $NoteDraftsTable,
      NoteDraft,
      $$NoteDraftsTableFilterComposer,
      $$NoteDraftsTableOrderingComposer,
      $$NoteDraftsTableAnnotationComposer,
      $$NoteDraftsTableCreateCompanionBuilder,
      $$NoteDraftsTableUpdateCompanionBuilder,
      (NoteDraft, BaseReferences<_$AppDatabase, $NoteDraftsTable, NoteDraft>),
      NoteDraft,
      PrefetchHooks Function()
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
typedef $$DiaryEntriesTableCreateCompanionBuilder =
    DiaryEntriesCompanion Function({
      required String id,
      required String dateKey,
      required String title,
      required String body,
      required int revision,
      required int createdAt,
      required int updatedAt,
      Value<int?> deletedAt,
      Value<int> rowid,
    });
typedef $$DiaryEntriesTableUpdateCompanionBuilder =
    DiaryEntriesCompanion Function({
      Value<String> id,
      Value<String> dateKey,
      Value<String> title,
      Value<String> body,
      Value<int> revision,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<int?> deletedAt,
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

  ColumnFilters<String> get dateKey => $composableBuilder(
    column: $table.dateKey,
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

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
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

  ColumnOrderings<String> get dateKey => $composableBuilder(
    column: $table.dateKey,
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

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
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

  GeneratedColumn<String> get dateKey =>
      $composableBuilder(column: $table.dateKey, builder: (column) => column);

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

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
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
                Value<String> dateKey = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> body = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DiaryEntriesCompanion(
                id: id,
                dateKey: dateKey,
                title: title,
                body: body,
                revision: revision,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String dateKey,
                required String title,
                required String body,
                required int revision,
                required int createdAt,
                required int updatedAt,
                Value<int?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DiaryEntriesCompanion.insert(
                id: id,
                dateKey: dateKey,
                title: title,
                body: body,
                revision: revision,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
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
  required String dateKey,
  required String heading,
  Value<String?> mood,
  Value<String> themes,
  required int revision,
  Value<int> rowid,
});
typedef $$DiaryDaysTableUpdateCompanionBuilder = DiaryDaysCompanion Function({
  Value<String> dateKey,
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
  ColumnFilters<String> get dateKey => $composableBuilder(
    column: $table.dateKey,
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
  ColumnOrderings<String> get dateKey => $composableBuilder(
    column: $table.dateKey,
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
  GeneratedColumn<String> get dateKey =>
      $composableBuilder(column: $table.dateKey, builder: (column) => column);

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
                Value<String> dateKey = const Value.absent(),
                Value<String> heading = const Value.absent(),
                Value<String?> mood = const Value.absent(),
                Value<String> themes = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DiaryDaysCompanion(
                dateKey: dateKey,
                heading: heading,
                mood: mood,
                themes: themes,
                revision: revision,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String dateKey,
                required String heading,
                Value<String?> mood = const Value.absent(),
                Value<String> themes = const Value.absent(),
                required int revision,
                Value<int> rowid = const Value.absent(),
              }) => DiaryDaysCompanion.insert(
                dateKey: dateKey,
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
typedef $$FlowThoughtsTableCreateCompanionBuilder =
    FlowThoughtsCompanion Function({
      required String id,
      required String body,
      required int revision,
      required int createdAt,
      required int updatedAt,
      Value<int?> deletedAt,
      Value<int> rowid,
    });
typedef $$FlowThoughtsTableUpdateCompanionBuilder =
    FlowThoughtsCompanion Function({
      Value<String> id,
      Value<String> body,
      Value<int> revision,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<int?> deletedAt,
      Value<int> rowid,
    });

class $$FlowThoughtsTableFilterComposer
    extends Composer<_$AppDatabase, $FlowThoughtsTable> {
  $$FlowThoughtsTableFilterComposer({
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

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$FlowThoughtsTableOrderingComposer
    extends Composer<_$AppDatabase, $FlowThoughtsTable> {
  $$FlowThoughtsTableOrderingComposer({
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

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$FlowThoughtsTableAnnotationComposer
    extends Composer<_$AppDatabase, $FlowThoughtsTable> {
  $$FlowThoughtsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$FlowThoughtsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FlowThoughtsTable,
          ThoughtRow,
          $$FlowThoughtsTableFilterComposer,
          $$FlowThoughtsTableOrderingComposer,
          $$FlowThoughtsTableAnnotationComposer,
          $$FlowThoughtsTableCreateCompanionBuilder,
          $$FlowThoughtsTableUpdateCompanionBuilder,
          (
            ThoughtRow,
            BaseReferences<_$AppDatabase, $FlowThoughtsTable, ThoughtRow>,
          ),
          ThoughtRow,
          PrefetchHooks Function()
        > {
  $$FlowThoughtsTableTableManager(_$AppDatabase db, $FlowThoughtsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FlowThoughtsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FlowThoughtsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FlowThoughtsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> body = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FlowThoughtsCompanion(
                id: id,
                body: body,
                revision: revision,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String body,
                required int revision,
                required int createdAt,
                required int updatedAt,
                Value<int?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FlowThoughtsCompanion.insert(
                id: id,
                body: body,
                revision: revision,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$FlowThoughtsTable, ThoughtRow>(table),
                  BaseReferences<_$AppDatabase, $FlowThoughtsTable, ThoughtRow>(
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

typedef $$FlowThoughtsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FlowThoughtsTable,
      ThoughtRow,
      $$FlowThoughtsTableFilterComposer,
      $$FlowThoughtsTableOrderingComposer,
      $$FlowThoughtsTableAnnotationComposer,
      $$FlowThoughtsTableCreateCompanionBuilder,
      $$FlowThoughtsTableUpdateCompanionBuilder,
      (
        ThoughtRow,
        BaseReferences<_$AppDatabase, $FlowThoughtsTable, ThoughtRow>,
      ),
      ThoughtRow,
      PrefetchHooks Function()
    >;
typedef $$BrainAssignmentsTableTableCreateCompanionBuilder =
    BrainAssignmentsTableCompanion Function({
      required String capability,
      required String modelId,
      Value<String> source,
      Value<int> rowid,
    });
typedef $$BrainAssignmentsTableTableUpdateCompanionBuilder =
    BrainAssignmentsTableCompanion Function({
      Value<String> capability,
      Value<String> modelId,
      Value<String> source,
      Value<int> rowid,
    });

class $$BrainAssignmentsTableTableFilterComposer
    extends Composer<_$AppDatabase, $BrainAssignmentsTableTable> {
  $$BrainAssignmentsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get capability => $composableBuilder(
    column: $table.capability,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get modelId => $composableBuilder(
    column: $table.modelId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BrainAssignmentsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $BrainAssignmentsTableTable> {
  $$BrainAssignmentsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get capability => $composableBuilder(
    column: $table.capability,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get modelId => $composableBuilder(
    column: $table.modelId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BrainAssignmentsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $BrainAssignmentsTableTable> {
  $$BrainAssignmentsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get capability => $composableBuilder(
    column: $table.capability,
    builder: (column) => column,
  );

  GeneratedColumn<String> get modelId =>
      $composableBuilder(column: $table.modelId, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);
}

class $$BrainAssignmentsTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BrainAssignmentsTableTable,
          BrainAssignmentRow,
          $$BrainAssignmentsTableTableFilterComposer,
          $$BrainAssignmentsTableTableOrderingComposer,
          $$BrainAssignmentsTableTableAnnotationComposer,
          $$BrainAssignmentsTableTableCreateCompanionBuilder,
          $$BrainAssignmentsTableTableUpdateCompanionBuilder,
          (
            BrainAssignmentRow,
            BaseReferences<
              _$AppDatabase,
              $BrainAssignmentsTableTable,
              BrainAssignmentRow
            >,
          ),
          BrainAssignmentRow,
          PrefetchHooks Function()
        > {
  $$BrainAssignmentsTableTableTableManager(
    _$AppDatabase db,
    $BrainAssignmentsTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BrainAssignmentsTableTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$BrainAssignmentsTableTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$BrainAssignmentsTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> capability = const Value.absent(),
                Value<String> modelId = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BrainAssignmentsTableCompanion(
                capability: capability,
                modelId: modelId,
                source: source,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String capability,
                required String modelId,
                Value<String> source = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BrainAssignmentsTableCompanion.insert(
                capability: capability,
                modelId: modelId,
                source: source,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$BrainAssignmentsTableTable, BrainAssignmentRow>(
                    table,
                  ),
                  BaseReferences<
                    _$AppDatabase,
                    $BrainAssignmentsTableTable,
                    BrainAssignmentRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BrainAssignmentsTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BrainAssignmentsTableTable,
      BrainAssignmentRow,
      $$BrainAssignmentsTableTableFilterComposer,
      $$BrainAssignmentsTableTableOrderingComposer,
      $$BrainAssignmentsTableTableAnnotationComposer,
      $$BrainAssignmentsTableTableCreateCompanionBuilder,
      $$BrainAssignmentsTableTableUpdateCompanionBuilder,
      (
        BrainAssignmentRow,
        BaseReferences<
          _$AppDatabase,
          $BrainAssignmentsTableTable,
          BrainAssignmentRow
        >,
      ),
      BrainAssignmentRow,
      PrefetchHooks Function()
    >;
typedef $$SyncOperationsTableCreateCompanionBuilder =
    SyncOperationsCompanion Function({
      required String type,
      required String id,
      required String documentId,
      Value<int> rowid,
    });
typedef $$SyncOperationsTableUpdateCompanionBuilder =
    SyncOperationsCompanion Function({
      Value<String> type,
      Value<String> id,
      Value<String> documentId,
      Value<int> rowid,
    });

class $$SyncOperationsTableFilterComposer
    extends Composer<_$AppDatabase, $SyncOperationsTable> {
  $$SyncOperationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get documentId => $composableBuilder(
    column: $table.documentId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncOperationsTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncOperationsTable> {
  $$SyncOperationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get documentId => $composableBuilder(
    column: $table.documentId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncOperationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncOperationsTable> {
  $$SyncOperationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get documentId => $composableBuilder(
    column: $table.documentId,
    builder: (column) => column,
  );
}

class $$SyncOperationsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncOperationsTable,
          SyncOperation,
          $$SyncOperationsTableFilterComposer,
          $$SyncOperationsTableOrderingComposer,
          $$SyncOperationsTableAnnotationComposer,
          $$SyncOperationsTableCreateCompanionBuilder,
          $$SyncOperationsTableUpdateCompanionBuilder,
          (
            SyncOperation,
            BaseReferences<_$AppDatabase, $SyncOperationsTable, SyncOperation>,
          ),
          SyncOperation,
          PrefetchHooks Function()
        > {
  $$SyncOperationsTableTableManager(
    _$AppDatabase db,
    $SyncOperationsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncOperationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncOperationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncOperationsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> type = const Value.absent(),
                Value<String> id = const Value.absent(),
                Value<String> documentId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncOperationsCompanion(
                type: type,
                id: id,
                documentId: documentId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String type,
                required String id,
                required String documentId,
                Value<int> rowid = const Value.absent(),
              }) => SyncOperationsCompanion.insert(
                type: type,
                id: id,
                documentId: documentId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SyncOperationsTable, SyncOperation>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $SyncOperationsTable,
                    SyncOperation
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncOperationsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncOperationsTable,
      SyncOperation,
      $$SyncOperationsTableFilterComposer,
      $$SyncOperationsTableOrderingComposer,
      $$SyncOperationsTableAnnotationComposer,
      $$SyncOperationsTableCreateCompanionBuilder,
      $$SyncOperationsTableUpdateCompanionBuilder,
      (
        SyncOperation,
        BaseReferences<_$AppDatabase, $SyncOperationsTable, SyncOperation>,
      ),
      SyncOperation,
      PrefetchHooks Function()
    >;
typedef $$SyncValuesTableCreateCompanionBuilder = SyncValuesCompanion Function({
  required String key,
  required String value,
  Value<int> rowid,
});
typedef $$SyncValuesTableUpdateCompanionBuilder = SyncValuesCompanion Function({
  Value<String> key,
  Value<String> value,
  Value<int> rowid,
});

class $$SyncValuesTableFilterComposer
    extends Composer<_$AppDatabase, $SyncValuesTable> {
  $$SyncValuesTableFilterComposer({
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

class $$SyncValuesTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncValuesTable> {
  $$SyncValuesTableOrderingComposer({
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

class $$SyncValuesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncValuesTable> {
  $$SyncValuesTableAnnotationComposer({
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

class $$SyncValuesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncValuesTable,
          SyncValue,
          $$SyncValuesTableFilterComposer,
          $$SyncValuesTableOrderingComposer,
          $$SyncValuesTableAnnotationComposer,
          $$SyncValuesTableCreateCompanionBuilder,
          $$SyncValuesTableUpdateCompanionBuilder,
          (
            SyncValue,
            BaseReferences<_$AppDatabase, $SyncValuesTable, SyncValue>,
          ),
          SyncValue,
          PrefetchHooks Function()
        > {
  $$SyncValuesTableTableManager(_$AppDatabase db, $SyncValuesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncValuesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncValuesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncValuesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => SyncValuesCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => SyncValuesCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SyncValuesTable, SyncValue>(table),
                  BaseReferences<_$AppDatabase, $SyncValuesTable, SyncValue>(
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

typedef $$SyncValuesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncValuesTable,
      SyncValue,
      $$SyncValuesTableFilterComposer,
      $$SyncValuesTableOrderingComposer,
      $$SyncValuesTableAnnotationComposer,
      $$SyncValuesTableCreateCompanionBuilder,
      $$SyncValuesTableUpdateCompanionBuilder,
      (SyncValue, BaseReferences<_$AppDatabase, $SyncValuesTable, SyncValue>),
      SyncValue,
      PrefetchHooks Function()
    >;
typedef $$SyncRecordsTableCreateCompanionBuilder =
    SyncRecordsCompanion Function({
      required String type,
      required String documentId,
      Value<String> state,
      Value<bool> removed,
      Value<int> rowid,
    });
typedef $$SyncRecordsTableUpdateCompanionBuilder =
    SyncRecordsCompanion Function({
      Value<String> type,
      Value<String> documentId,
      Value<String> state,
      Value<bool> removed,
      Value<int> rowid,
    });

class $$SyncRecordsTableFilterComposer
    extends Composer<_$AppDatabase, $SyncRecordsTable> {
  $$SyncRecordsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get documentId => $composableBuilder(
    column: $table.documentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get removed => $composableBuilder(
    column: $table.removed,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncRecordsTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncRecordsTable> {
  $$SyncRecordsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get documentId => $composableBuilder(
    column: $table.documentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get removed => $composableBuilder(
    column: $table.removed,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncRecordsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncRecordsTable> {
  $$SyncRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get documentId => $composableBuilder(
    column: $table.documentId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<bool> get removed =>
      $composableBuilder(column: $table.removed, builder: (column) => column);
}

class $$SyncRecordsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncRecordsTable,
          SyncRecord,
          $$SyncRecordsTableFilterComposer,
          $$SyncRecordsTableOrderingComposer,
          $$SyncRecordsTableAnnotationComposer,
          $$SyncRecordsTableCreateCompanionBuilder,
          $$SyncRecordsTableUpdateCompanionBuilder,
          (
            SyncRecord,
            BaseReferences<_$AppDatabase, $SyncRecordsTable, SyncRecord>,
          ),
          SyncRecord,
          PrefetchHooks Function()
        > {
  $$SyncRecordsTableTableManager(_$AppDatabase db, $SyncRecordsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncRecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncRecordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncRecordsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> type = const Value.absent(),
                Value<String> documentId = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<bool> removed = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncRecordsCompanion(
                type: type,
                documentId: documentId,
                state: state,
                removed: removed,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String type,
                required String documentId,
                Value<String> state = const Value.absent(),
                Value<bool> removed = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncRecordsCompanion.insert(
                type: type,
                documentId: documentId,
                state: state,
                removed: removed,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SyncRecordsTable, SyncRecord>(table),
                  BaseReferences<_$AppDatabase, $SyncRecordsTable, SyncRecord>(
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

typedef $$SyncRecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncRecordsTable,
      SyncRecord,
      $$SyncRecordsTableFilterComposer,
      $$SyncRecordsTableOrderingComposer,
      $$SyncRecordsTableAnnotationComposer,
      $$SyncRecordsTableCreateCompanionBuilder,
      $$SyncRecordsTableUpdateCompanionBuilder,
      (
        SyncRecord,
        BaseReferences<_$AppDatabase, $SyncRecordsTable, SyncRecord>,
      ),
      SyncRecord,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$AiPreferencesTableTableTableManager get aiPreferencesTable =>
      $$AiPreferencesTableTableTableManager(_db, _db.aiPreferencesTable);
  $$AiJobReceiptsTableTableManager get aiJobReceipts =>
      $$AiJobReceiptsTableTableManager(_db, _db.aiJobReceipts);
  $$RecallQueueTableTableManager get recallQueue =>
      $$RecallQueueTableTableManager(_db, _db.recallQueue);
  $$RecallManifestsTableTableManager get recallManifests =>
      $$RecallManifestsTableTableManager(_db, _db.recallManifests);
  $$DailyQuestionsTableTableManager get dailyQuestions =>
      $$DailyQuestionsTableTableManager(_db, _db.dailyQuestions);
  $$AppearanceSettingsTableTableManager get appearanceSettings =>
      $$AppearanceSettingsTableTableManager(_db, _db.appearanceSettings);
  $$OnboardingCompletionTableTableManager get onboardingCompletion =>
      $$OnboardingCompletionTableTableManager(_db, _db.onboardingCompletion);
  $$NotesTableTableManager get notes =>
      $$NotesTableTableManager(_db, _db.notes);
  $$NoteDraftsTableTableManager get noteDrafts =>
      $$NoteDraftsTableTableManager(_db, _db.noteDrafts);
  $$NoteTagsTableTableManager get noteTags =>
      $$NoteTagsTableTableManager(_db, _db.noteTags);
  $$DiaryEntriesTableTableManager get diaryEntries =>
      $$DiaryEntriesTableTableManager(_db, _db.diaryEntries);
  $$DiaryDaysTableTableManager get diaryDays =>
      $$DiaryDaysTableTableManager(_db, _db.diaryDays);
  $$FlowThoughtsTableTableManager get flowThoughts =>
      $$FlowThoughtsTableTableManager(_db, _db.flowThoughts);
  $$BrainAssignmentsTableTableTableManager get brainAssignmentsTable =>
      $$BrainAssignmentsTableTableTableManager(_db, _db.brainAssignmentsTable);
  $$SyncOperationsTableTableManager get syncOperations =>
      $$SyncOperationsTableTableManager(_db, _db.syncOperations);
  $$SyncValuesTableTableManager get syncValues =>
      $$SyncValuesTableTableManager(_db, _db.syncValues);
  $$SyncRecordsTableTableManager get syncRecords =>
      $$SyncRecordsTableTableManager(_db, _db.syncRecords);
}
