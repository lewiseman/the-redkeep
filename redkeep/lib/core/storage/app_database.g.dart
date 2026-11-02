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

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $AppearanceSettingsTable appearanceSettings =
      $AppearanceSettingsTable(this);
  late final $OnboardingCompletionTable onboardingCompletion =
      $OnboardingCompletionTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    appearanceSettings,
    onboardingCompletion,
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

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$AppearanceSettingsTableTableManager get appearanceSettings =>
      $$AppearanceSettingsTableTableManager(_db, _db.appearanceSettings);
  $$OnboardingCompletionTableTableManager get onboardingCompletion =>
      $$OnboardingCompletionTableTableManager(_db, _db.onboardingCompletion);
}
