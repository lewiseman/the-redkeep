// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
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
  final bool reduceMotion;
  final bool simplerEffects;
  const AppearanceRow({
    required this.id,
    required this.theme,
    required this.reduceMotion,
    required this.simplerEffects,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['theme'] = Variable<String>(theme);
    map['reduce_motion'] = Variable<bool>(reduceMotion);
    map['simpler_effects'] = Variable<bool>(simplerEffects);
    return map;
  }

  AppearanceSettingsCompanion toCompanion(bool nullToAbsent) {
    return AppearanceSettingsCompanion(
      id: Value(id),
      theme: Value(theme),
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
      'reduceMotion': serializer.toJson<bool>(reduceMotion),
      'simplerEffects': serializer.toJson<bool>(simplerEffects),
    };
  }

  AppearanceRow copyWith({
    int? id,
    String? theme,
    bool? reduceMotion,
    bool? simplerEffects,
  }) => AppearanceRow(
    id: id ?? this.id,
    theme: theme ?? this.theme,
    reduceMotion: reduceMotion ?? this.reduceMotion,
    simplerEffects: simplerEffects ?? this.simplerEffects,
  );
  AppearanceRow copyWithCompanion(AppearanceSettingsCompanion data) {
    return AppearanceRow(
      id: data.id.present ? data.id.value : this.id,
      theme: data.theme.present ? data.theme.value : this.theme,
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
          ..write('reduceMotion: $reduceMotion, ')
          ..write('simplerEffects: $simplerEffects')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, theme, reduceMotion, simplerEffects);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppearanceRow &&
          other.id == this.id &&
          other.theme == this.theme &&
          other.reduceMotion == this.reduceMotion &&
          other.simplerEffects == this.simplerEffects);
}

class AppearanceSettingsCompanion extends UpdateCompanion<AppearanceRow> {
  final Value<int> id;
  final Value<String> theme;
  final Value<bool> reduceMotion;
  final Value<bool> simplerEffects;
  const AppearanceSettingsCompanion({
    this.id = const Value.absent(),
    this.theme = const Value.absent(),
    this.reduceMotion = const Value.absent(),
    this.simplerEffects = const Value.absent(),
  });
  AppearanceSettingsCompanion.insert({
    this.id = const Value.absent(),
    this.theme = const Value.absent(),
    this.reduceMotion = const Value.absent(),
    this.simplerEffects = const Value.absent(),
  });
  static Insertable<AppearanceRow> custom({
    Expression<int>? id,
    Expression<String>? theme,
    Expression<bool>? reduceMotion,
    Expression<bool>? simplerEffects,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (theme != null) 'theme': theme,
      if (reduceMotion != null) 'reduce_motion': reduceMotion,
      if (simplerEffects != null) 'simpler_effects': simplerEffects,
    });
  }

  AppearanceSettingsCompanion copyWith({
    Value<int>? id,
    Value<String>? theme,
    Value<bool>? reduceMotion,
    Value<bool>? simplerEffects,
  }) {
    return AppearanceSettingsCompanion(
      id: id ?? this.id,
      theme: theme ?? this.theme,
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
  @override
  List<GeneratedColumn> get $columns => [id];
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
  const OnboardingCompletionRow({required this.id});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    return map;
  }

  OnboardingCompletionCompanion toCompanion(bool nullToAbsent) {
    return OnboardingCompletionCompanion(id: Value(id));
  }

  factory OnboardingCompletionRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OnboardingCompletionRow(id: serializer.fromJson<int>(json['id']));
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{'id': serializer.toJson<int>(id)};
  }

  OnboardingCompletionRow copyWith({int? id}) =>
      OnboardingCompletionRow(id: id ?? this.id);
  OnboardingCompletionRow copyWithCompanion(
    OnboardingCompletionCompanion data,
  ) {
    return OnboardingCompletionRow(
      id: data.id.present ? data.id.value : this.id,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OnboardingCompletionRow(')
          ..write('id: $id')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => id.hashCode;
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OnboardingCompletionRow && other.id == this.id);
}

class OnboardingCompletionCompanion
    extends UpdateCompanion<OnboardingCompletionRow> {
  final Value<int> id;
  const OnboardingCompletionCompanion({this.id = const Value.absent()});
  OnboardingCompletionCompanion.insert({this.id = const Value.absent()});
  static Insertable<OnboardingCompletionRow> custom({Expression<int>? id}) {
    return RawValuesInsertable({if (id != null) 'id': id});
  }

  OnboardingCompletionCompanion copyWith({Value<int>? id}) {
    return OnboardingCompletionCompanion(id: id ?? this.id);
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OnboardingCompletionCompanion(')
          ..write('id: $id')
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

class $DiaryDraftsTable extends DiaryDrafts
    with TableInfo<$DiaryDraftsTable, DiaryDraftRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DiaryDraftsTable(this.attachedDatabase, [this._alias]);
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
    dateKey,
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
  static const String $name = 'diary_drafts';
  @override
  VerificationContext validateIntegrity(
    Insertable<DiaryDraftRow> instance, {
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
  DiaryDraftRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DiaryDraftRow(
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
  $DiaryDraftsTable createAlias(String alias) {
    return $DiaryDraftsTable(attachedDatabase, alias);
  }
}

class DiaryDraftRow extends DataClass implements Insertable<DiaryDraftRow> {
  final String id;
  final String dateKey;
  final String title;
  final String body;
  final int baseRevision;
  final int draftRevision;
  final int updatedAt;
  const DiaryDraftRow({
    required this.id,
    required this.dateKey,
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
    map['date_key'] = Variable<String>(dateKey);
    map['title'] = Variable<String>(title);
    map['body'] = Variable<String>(body);
    map['base_revision'] = Variable<int>(baseRevision);
    map['draft_revision'] = Variable<int>(draftRevision);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  DiaryDraftsCompanion toCompanion(bool nullToAbsent) {
    return DiaryDraftsCompanion(
      id: Value(id),
      dateKey: Value(dateKey),
      title: Value(title),
      body: Value(body),
      baseRevision: Value(baseRevision),
      draftRevision: Value(draftRevision),
      updatedAt: Value(updatedAt),
    );
  }

  factory DiaryDraftRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DiaryDraftRow(
      id: serializer.fromJson<String>(json['id']),
      dateKey: serializer.fromJson<String>(json['dateKey']),
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
      'dateKey': serializer.toJson<String>(dateKey),
      'title': serializer.toJson<String>(title),
      'body': serializer.toJson<String>(body),
      'baseRevision': serializer.toJson<int>(baseRevision),
      'draftRevision': serializer.toJson<int>(draftRevision),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  DiaryDraftRow copyWith({
    String? id,
    String? dateKey,
    String? title,
    String? body,
    int? baseRevision,
    int? draftRevision,
    int? updatedAt,
  }) => DiaryDraftRow(
    id: id ?? this.id,
    dateKey: dateKey ?? this.dateKey,
    title: title ?? this.title,
    body: body ?? this.body,
    baseRevision: baseRevision ?? this.baseRevision,
    draftRevision: draftRevision ?? this.draftRevision,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  DiaryDraftRow copyWithCompanion(DiaryDraftsCompanion data) {
    return DiaryDraftRow(
      id: data.id.present ? data.id.value : this.id,
      dateKey: data.dateKey.present ? data.dateKey.value : this.dateKey,
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
    return (StringBuffer('DiaryDraftRow(')
          ..write('id: $id, ')
          ..write('dateKey: $dateKey, ')
          ..write('title: $title, ')
          ..write('body: $body, ')
          ..write('baseRevision: $baseRevision, ')
          ..write('draftRevision: $draftRevision, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    dateKey,
    title,
    body,
    baseRevision,
    draftRevision,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DiaryDraftRow &&
          other.id == this.id &&
          other.dateKey == this.dateKey &&
          other.title == this.title &&
          other.body == this.body &&
          other.baseRevision == this.baseRevision &&
          other.draftRevision == this.draftRevision &&
          other.updatedAt == this.updatedAt);
}

class DiaryDraftsCompanion extends UpdateCompanion<DiaryDraftRow> {
  final Value<String> id;
  final Value<String> dateKey;
  final Value<String> title;
  final Value<String> body;
  final Value<int> baseRevision;
  final Value<int> draftRevision;
  final Value<int> updatedAt;
  const DiaryDraftsCompanion({
    this.id = const Value.absent(),
    this.dateKey = const Value.absent(),
    this.title = const Value.absent(),
    this.body = const Value.absent(),
    this.baseRevision = const Value.absent(),
    this.draftRevision = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  DiaryDraftsCompanion.insert({
    required String id,
    required String dateKey,
    required String title,
    required String body,
    required int baseRevision,
    this.draftRevision = const Value.absent(),
    required int updatedAt,
  }) : id = Value(id),
       dateKey = Value(dateKey),
       title = Value(title),
       body = Value(body),
       baseRevision = Value(baseRevision),
       updatedAt = Value(updatedAt);
  static Insertable<DiaryDraftRow> custom({
    Expression<String>? id,
    Expression<String>? dateKey,
    Expression<String>? title,
    Expression<String>? body,
    Expression<int>? baseRevision,
    Expression<int>? draftRevision,
    Expression<int>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (dateKey != null) 'date_key': dateKey,
      if (title != null) 'title': title,
      if (body != null) 'body': body,
      if (baseRevision != null) 'base_revision': baseRevision,
      if (draftRevision != null) 'draft_revision': draftRevision,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  DiaryDraftsCompanion copyWith({
    Value<String>? id,
    Value<String>? dateKey,
    Value<String>? title,
    Value<String>? body,
    Value<int>? baseRevision,
    Value<int>? draftRevision,
    Value<int>? updatedAt,
  }) {
    return DiaryDraftsCompanion(
      id: id ?? this.id,
      dateKey: dateKey ?? this.dateKey,
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
    if (dateKey.present) {
      map['date_key'] = Variable<String>(dateKey.value);
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
    return (StringBuffer('DiaryDraftsCompanion(')
          ..write('id: $id, ')
          ..write('dateKey: $dateKey, ')
          ..write('title: $title, ')
          ..write('body: $body, ')
          ..write('baseRevision: $baseRevision, ')
          ..write('draftRevision: $draftRevision, ')
          ..write('updatedAt: $updatedAt')
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
  List<GeneratedColumn> get $columns => [dateKey, heading, revision];
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
  final int revision;
  const DiaryDayRow({
    required this.dateKey,
    required this.heading,
    required this.revision,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['date_key'] = Variable<String>(dateKey);
    map['heading'] = Variable<String>(heading);
    map['revision'] = Variable<int>(revision);
    return map;
  }

  DiaryDaysCompanion toCompanion(bool nullToAbsent) {
    return DiaryDaysCompanion(
      dateKey: Value(dateKey),
      heading: Value(heading),
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
      revision: serializer.fromJson<int>(json['revision']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'dateKey': serializer.toJson<String>(dateKey),
      'heading': serializer.toJson<String>(heading),
      'revision': serializer.toJson<int>(revision),
    };
  }

  DiaryDayRow copyWith({String? dateKey, String? heading, int? revision}) =>
      DiaryDayRow(
        dateKey: dateKey ?? this.dateKey,
        heading: heading ?? this.heading,
        revision: revision ?? this.revision,
      );
  DiaryDayRow copyWithCompanion(DiaryDaysCompanion data) {
    return DiaryDayRow(
      dateKey: data.dateKey.present ? data.dateKey.value : this.dateKey,
      heading: data.heading.present ? data.heading.value : this.heading,
      revision: data.revision.present ? data.revision.value : this.revision,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DiaryDayRow(')
          ..write('dateKey: $dateKey, ')
          ..write('heading: $heading, ')
          ..write('revision: $revision')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(dateKey, heading, revision);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DiaryDayRow &&
          other.dateKey == this.dateKey &&
          other.heading == this.heading &&
          other.revision == this.revision);
}

class DiaryDaysCompanion extends UpdateCompanion<DiaryDayRow> {
  final Value<String> dateKey;
  final Value<String> heading;
  final Value<int> revision;
  final Value<int> rowid;
  const DiaryDaysCompanion({
    this.dateKey = const Value.absent(),
    this.heading = const Value.absent(),
    this.revision = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DiaryDaysCompanion.insert({
    required String dateKey,
    required String heading,
    required int revision,
    this.rowid = const Value.absent(),
  }) : dateKey = Value(dateKey),
       heading = Value(heading),
       revision = Value(revision);
  static Insertable<DiaryDayRow> custom({
    Expression<String>? dateKey,
    Expression<String>? heading,
    Expression<int>? revision,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (dateKey != null) 'date_key': dateKey,
      if (heading != null) 'heading': heading,
      if (revision != null) 'revision': revision,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DiaryDaysCompanion copyWith({
    Value<String>? dateKey,
    Value<String>? heading,
    Value<int>? revision,
    Value<int>? rowid,
  }) {
    return DiaryDaysCompanion(
      dateKey: dateKey ?? this.dateKey,
      heading: heading ?? this.heading,
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

class $FlowDraftsTable extends FlowDrafts
    with TableInfo<$FlowDraftsTable, ThoughtDraftRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FlowDraftsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _captureMeta = const VerificationMeta(
    'capture',
  );
  @override
  late final GeneratedColumn<bool> capture = GeneratedColumn<bool>(
    'capture',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("capture" IN (0, 1))',
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
    body,
    baseRevision,
    draftRevision,
    capture,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'flow_drafts';
  @override
  VerificationContext validateIntegrity(
    Insertable<ThoughtDraftRow> instance, {
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
    if (data.containsKey('capture')) {
      context.handle(
        _captureMeta,
        capture.isAcceptableOrUnknown(data['capture']!, _captureMeta),
      );
    } else if (isInserting) {
      context.missing(_captureMeta);
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
  ThoughtDraftRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ThoughtDraftRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
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
      capture: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}capture'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $FlowDraftsTable createAlias(String alias) {
    return $FlowDraftsTable(attachedDatabase, alias);
  }
}

class ThoughtDraftRow extends DataClass implements Insertable<ThoughtDraftRow> {
  final String id;
  final String body;
  final int baseRevision;
  final int draftRevision;
  final bool capture;
  final int updatedAt;
  const ThoughtDraftRow({
    required this.id,
    required this.body,
    required this.baseRevision,
    required this.draftRevision,
    required this.capture,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['body'] = Variable<String>(body);
    map['base_revision'] = Variable<int>(baseRevision);
    map['draft_revision'] = Variable<int>(draftRevision);
    map['capture'] = Variable<bool>(capture);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  FlowDraftsCompanion toCompanion(bool nullToAbsent) {
    return FlowDraftsCompanion(
      id: Value(id),
      body: Value(body),
      baseRevision: Value(baseRevision),
      draftRevision: Value(draftRevision),
      capture: Value(capture),
      updatedAt: Value(updatedAt),
    );
  }

  factory ThoughtDraftRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ThoughtDraftRow(
      id: serializer.fromJson<String>(json['id']),
      body: serializer.fromJson<String>(json['body']),
      baseRevision: serializer.fromJson<int>(json['baseRevision']),
      draftRevision: serializer.fromJson<int>(json['draftRevision']),
      capture: serializer.fromJson<bool>(json['capture']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'body': serializer.toJson<String>(body),
      'baseRevision': serializer.toJson<int>(baseRevision),
      'draftRevision': serializer.toJson<int>(draftRevision),
      'capture': serializer.toJson<bool>(capture),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  ThoughtDraftRow copyWith({
    String? id,
    String? body,
    int? baseRevision,
    int? draftRevision,
    bool? capture,
    int? updatedAt,
  }) => ThoughtDraftRow(
    id: id ?? this.id,
    body: body ?? this.body,
    baseRevision: baseRevision ?? this.baseRevision,
    draftRevision: draftRevision ?? this.draftRevision,
    capture: capture ?? this.capture,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ThoughtDraftRow copyWithCompanion(FlowDraftsCompanion data) {
    return ThoughtDraftRow(
      id: data.id.present ? data.id.value : this.id,
      body: data.body.present ? data.body.value : this.body,
      baseRevision: data.baseRevision.present
          ? data.baseRevision.value
          : this.baseRevision,
      draftRevision: data.draftRevision.present
          ? data.draftRevision.value
          : this.draftRevision,
      capture: data.capture.present ? data.capture.value : this.capture,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ThoughtDraftRow(')
          ..write('id: $id, ')
          ..write('body: $body, ')
          ..write('baseRevision: $baseRevision, ')
          ..write('draftRevision: $draftRevision, ')
          ..write('capture: $capture, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, body, baseRevision, draftRevision, capture, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ThoughtDraftRow &&
          other.id == this.id &&
          other.body == this.body &&
          other.baseRevision == this.baseRevision &&
          other.draftRevision == this.draftRevision &&
          other.capture == this.capture &&
          other.updatedAt == this.updatedAt);
}

class FlowDraftsCompanion extends UpdateCompanion<ThoughtDraftRow> {
  final Value<String> id;
  final Value<String> body;
  final Value<int> baseRevision;
  final Value<int> draftRevision;
  final Value<bool> capture;
  final Value<int> updatedAt;
  const FlowDraftsCompanion({
    this.id = const Value.absent(),
    this.body = const Value.absent(),
    this.baseRevision = const Value.absent(),
    this.draftRevision = const Value.absent(),
    this.capture = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  FlowDraftsCompanion.insert({
    required String id,
    required String body,
    required int baseRevision,
    this.draftRevision = const Value.absent(),
    required bool capture,
    required int updatedAt,
  }) : id = Value(id),
       body = Value(body),
       baseRevision = Value(baseRevision),
       capture = Value(capture),
       updatedAt = Value(updatedAt);
  static Insertable<ThoughtDraftRow> custom({
    Expression<String>? id,
    Expression<String>? body,
    Expression<int>? baseRevision,
    Expression<int>? draftRevision,
    Expression<bool>? capture,
    Expression<int>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (body != null) 'body': body,
      if (baseRevision != null) 'base_revision': baseRevision,
      if (draftRevision != null) 'draft_revision': draftRevision,
      if (capture != null) 'capture': capture,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  FlowDraftsCompanion copyWith({
    Value<String>? id,
    Value<String>? body,
    Value<int>? baseRevision,
    Value<int>? draftRevision,
    Value<bool>? capture,
    Value<int>? updatedAt,
  }) {
    return FlowDraftsCompanion(
      id: id ?? this.id,
      body: body ?? this.body,
      baseRevision: baseRevision ?? this.baseRevision,
      draftRevision: draftRevision ?? this.draftRevision,
      capture: capture ?? this.capture,
      updatedAt: updatedAt ?? this.updatedAt,
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
    if (baseRevision.present) {
      map['base_revision'] = Variable<int>(baseRevision.value);
    }
    if (draftRevision.present) {
      map['draft_revision'] = Variable<int>(draftRevision.value);
    }
    if (capture.present) {
      map['capture'] = Variable<bool>(capture.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FlowDraftsCompanion(')
          ..write('id: $id, ')
          ..write('body: $body, ')
          ..write('baseRevision: $baseRevision, ')
          ..write('draftRevision: $draftRevision, ')
          ..write('capture: $capture, ')
          ..write('updatedAt: $updatedAt')
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

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $AppearanceSettingsTable appearanceSettings =
      $AppearanceSettingsTable(this);
  late final $OnboardingCompletionTable onboardingCompletion =
      $OnboardingCompletionTable(this);
  late final $NotesTable notes = $NotesTable(this);
  late final $NoteDraftsTable noteDrafts = $NoteDraftsTable(this);
  late final $NoteTagsTable noteTags = $NoteTagsTable(this);
  late final $DiaryEntriesTable diaryEntries = $DiaryEntriesTable(this);
  late final $DiaryDraftsTable diaryDrafts = $DiaryDraftsTable(this);
  late final $DiaryDaysTable diaryDays = $DiaryDaysTable(this);
  late final $FlowThoughtsTable flowThoughts = $FlowThoughtsTable(this);
  late final $FlowDraftsTable flowDrafts = $FlowDraftsTable(this);
  late final $BrainAssignmentsTableTable brainAssignmentsTable =
      $BrainAssignmentsTableTable(this);
  late final Index diaryEntriesDayOrder = Index(
    'diary_entries_day_order',
    'CREATE INDEX diary_entries_day_order ON diary_entries (date_key, created_at, id)',
  );
  late final Index flowThoughtsOrder = Index(
    'flow_thoughts_order',
    'CREATE INDEX flow_thoughts_order ON flow_thoughts (created_at DESC, id DESC)',
  );
  late final Index flowSingleCapture = Index(
    'flow_single_capture',
    'CREATE UNIQUE INDEX flow_single_capture ON flow_drafts (capture) WHERE capture = 1',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    appearanceSettings,
    onboardingCompletion,
    notes,
    noteDrafts,
    noteTags,
    diaryEntries,
    diaryDrafts,
    diaryDays,
    flowThoughts,
    flowDrafts,
    brainAssignmentsTable,
    diaryEntriesDayOrder,
    flowThoughtsOrder,
    flowSingleCapture,
  ];
}

typedef $$AppearanceSettingsTableCreateCompanionBuilder =
    AppearanceSettingsCompanion Function({
      Value<int> id,
      Value<String> theme,
      Value<bool> reduceMotion,
      Value<bool> simplerEffects,
    });
typedef $$AppearanceSettingsTableUpdateCompanionBuilder =
    AppearanceSettingsCompanion Function({
      Value<int> id,
      Value<String> theme,
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
                Value<bool> reduceMotion = const Value.absent(),
                Value<bool> simplerEffects = const Value.absent(),
              }) => AppearanceSettingsCompanion(
                id: id,
                theme: theme,
                reduceMotion: reduceMotion,
                simplerEffects: simplerEffects,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> theme = const Value.absent(),
                Value<bool> reduceMotion = const Value.absent(),
                Value<bool> simplerEffects = const Value.absent(),
              }) => AppearanceSettingsCompanion.insert(
                id: id,
                theme: theme,
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
    OnboardingCompletionCompanion Function({Value<int> id});
typedef $$OnboardingCompletionTableUpdateCompanionBuilder =
    OnboardingCompletionCompanion Function({Value<int> id});

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
          updateCompanionCallback: ({Value<int> id = const Value.absent()}) =>
              OnboardingCompletionCompanion(id: id),
          createCompanionCallback: ({Value<int> id = const Value.absent()}) =>
              OnboardingCompletionCompanion.insert(id: id),
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
typedef $$DiaryDraftsTableCreateCompanionBuilder =
    DiaryDraftsCompanion Function({
      required String id,
      required String dateKey,
      required String title,
      required String body,
      required int baseRevision,
      Value<int> draftRevision,
      required int updatedAt,
    });
typedef $$DiaryDraftsTableUpdateCompanionBuilder =
    DiaryDraftsCompanion Function({
      Value<String> id,
      Value<String> dateKey,
      Value<String> title,
      Value<String> body,
      Value<int> baseRevision,
      Value<int> draftRevision,
      Value<int> updatedAt,
    });

class $$DiaryDraftsTableFilterComposer
    extends Composer<_$AppDatabase, $DiaryDraftsTable> {
  $$DiaryDraftsTableFilterComposer({
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

class $$DiaryDraftsTableOrderingComposer
    extends Composer<_$AppDatabase, $DiaryDraftsTable> {
  $$DiaryDraftsTableOrderingComposer({
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

class $$DiaryDraftsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DiaryDraftsTable> {
  $$DiaryDraftsTableAnnotationComposer({
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

class $$DiaryDraftsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DiaryDraftsTable,
          DiaryDraftRow,
          $$DiaryDraftsTableFilterComposer,
          $$DiaryDraftsTableOrderingComposer,
          $$DiaryDraftsTableAnnotationComposer,
          $$DiaryDraftsTableCreateCompanionBuilder,
          $$DiaryDraftsTableUpdateCompanionBuilder,
          (
            DiaryDraftRow,
            BaseReferences<_$AppDatabase, $DiaryDraftsTable, DiaryDraftRow>,
          ),
          DiaryDraftRow,
          PrefetchHooks Function()
        > {
  $$DiaryDraftsTableTableManager(_$AppDatabase db, $DiaryDraftsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DiaryDraftsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DiaryDraftsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DiaryDraftsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> dateKey = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> body = const Value.absent(),
                Value<int> baseRevision = const Value.absent(),
                Value<int> draftRevision = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
              }) => DiaryDraftsCompanion(
                id: id,
                dateKey: dateKey,
                title: title,
                body: body,
                baseRevision: baseRevision,
                draftRevision: draftRevision,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String dateKey,
                required String title,
                required String body,
                required int baseRevision,
                Value<int> draftRevision = const Value.absent(),
                required int updatedAt,
              }) => DiaryDraftsCompanion.insert(
                id: id,
                dateKey: dateKey,
                title: title,
                body: body,
                baseRevision: baseRevision,
                draftRevision: draftRevision,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$DiaryDraftsTable, DiaryDraftRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $DiaryDraftsTable,
                    DiaryDraftRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DiaryDraftsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DiaryDraftsTable,
      DiaryDraftRow,
      $$DiaryDraftsTableFilterComposer,
      $$DiaryDraftsTableOrderingComposer,
      $$DiaryDraftsTableAnnotationComposer,
      $$DiaryDraftsTableCreateCompanionBuilder,
      $$DiaryDraftsTableUpdateCompanionBuilder,
      (
        DiaryDraftRow,
        BaseReferences<_$AppDatabase, $DiaryDraftsTable, DiaryDraftRow>,
      ),
      DiaryDraftRow,
      PrefetchHooks Function()
    >;
typedef $$DiaryDaysTableCreateCompanionBuilder = DiaryDaysCompanion Function({
  required String dateKey,
  required String heading,
  required int revision,
  Value<int> rowid,
});
typedef $$DiaryDaysTableUpdateCompanionBuilder = DiaryDaysCompanion Function({
  Value<String> dateKey,
  Value<String> heading,
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
                Value<int> revision = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DiaryDaysCompanion(
                dateKey: dateKey,
                heading: heading,
                revision: revision,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String dateKey,
                required String heading,
                required int revision,
                Value<int> rowid = const Value.absent(),
              }) => DiaryDaysCompanion.insert(
                dateKey: dateKey,
                heading: heading,
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
typedef $$FlowDraftsTableCreateCompanionBuilder = FlowDraftsCompanion Function({
  required String id,
  required String body,
  required int baseRevision,
  Value<int> draftRevision,
  required bool capture,
  required int updatedAt,
});
typedef $$FlowDraftsTableUpdateCompanionBuilder = FlowDraftsCompanion Function({
  Value<String> id,
  Value<String> body,
  Value<int> baseRevision,
  Value<int> draftRevision,
  Value<bool> capture,
  Value<int> updatedAt,
});

class $$FlowDraftsTableFilterComposer
    extends Composer<_$AppDatabase, $FlowDraftsTable> {
  $$FlowDraftsTableFilterComposer({
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

  ColumnFilters<int> get baseRevision => $composableBuilder(
    column: $table.baseRevision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get draftRevision => $composableBuilder(
    column: $table.draftRevision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get capture => $composableBuilder(
    column: $table.capture,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$FlowDraftsTableOrderingComposer
    extends Composer<_$AppDatabase, $FlowDraftsTable> {
  $$FlowDraftsTableOrderingComposer({
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

  ColumnOrderings<int> get baseRevision => $composableBuilder(
    column: $table.baseRevision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get draftRevision => $composableBuilder(
    column: $table.draftRevision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get capture => $composableBuilder(
    column: $table.capture,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$FlowDraftsTableAnnotationComposer
    extends Composer<_$AppDatabase, $FlowDraftsTable> {
  $$FlowDraftsTableAnnotationComposer({
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

  GeneratedColumn<int> get baseRevision => $composableBuilder(
    column: $table.baseRevision,
    builder: (column) => column,
  );

  GeneratedColumn<int> get draftRevision => $composableBuilder(
    column: $table.draftRevision,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get capture =>
      $composableBuilder(column: $table.capture, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$FlowDraftsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FlowDraftsTable,
          ThoughtDraftRow,
          $$FlowDraftsTableFilterComposer,
          $$FlowDraftsTableOrderingComposer,
          $$FlowDraftsTableAnnotationComposer,
          $$FlowDraftsTableCreateCompanionBuilder,
          $$FlowDraftsTableUpdateCompanionBuilder,
          (
            ThoughtDraftRow,
            BaseReferences<_$AppDatabase, $FlowDraftsTable, ThoughtDraftRow>,
          ),
          ThoughtDraftRow,
          PrefetchHooks Function()
        > {
  $$FlowDraftsTableTableManager(_$AppDatabase db, $FlowDraftsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FlowDraftsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FlowDraftsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FlowDraftsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> body = const Value.absent(),
                Value<int> baseRevision = const Value.absent(),
                Value<int> draftRevision = const Value.absent(),
                Value<bool> capture = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
              }) => FlowDraftsCompanion(
                id: id,
                body: body,
                baseRevision: baseRevision,
                draftRevision: draftRevision,
                capture: capture,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String body,
                required int baseRevision,
                Value<int> draftRevision = const Value.absent(),
                required bool capture,
                required int updatedAt,
              }) => FlowDraftsCompanion.insert(
                id: id,
                body: body,
                baseRevision: baseRevision,
                draftRevision: draftRevision,
                capture: capture,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$FlowDraftsTable, ThoughtDraftRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $FlowDraftsTable,
                    ThoughtDraftRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$FlowDraftsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FlowDraftsTable,
      ThoughtDraftRow,
      $$FlowDraftsTableFilterComposer,
      $$FlowDraftsTableOrderingComposer,
      $$FlowDraftsTableAnnotationComposer,
      $$FlowDraftsTableCreateCompanionBuilder,
      $$FlowDraftsTableUpdateCompanionBuilder,
      (
        ThoughtDraftRow,
        BaseReferences<_$AppDatabase, $FlowDraftsTable, ThoughtDraftRow>,
      ),
      ThoughtDraftRow,
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

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
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
  $$DiaryDraftsTableTableManager get diaryDrafts =>
      $$DiaryDraftsTableTableManager(_db, _db.diaryDrafts);
  $$DiaryDaysTableTableManager get diaryDays =>
      $$DiaryDaysTableTableManager(_db, _db.diaryDays);
  $$FlowThoughtsTableTableManager get flowThoughts =>
      $$FlowThoughtsTableTableManager(_db, _db.flowThoughts);
  $$FlowDraftsTableTableManager get flowDrafts =>
      $$FlowDraftsTableTableManager(_db, _db.flowDrafts);
  $$BrainAssignmentsTableTableTableManager get brainAssignmentsTable =>
      $$BrainAssignmentsTableTableTableManager(_db, _db.brainAssignmentsTable);
}
