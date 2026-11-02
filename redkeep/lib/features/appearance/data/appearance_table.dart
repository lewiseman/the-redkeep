import 'package:drift/drift.dart';

@DataClassName('AppearanceRow')
class AppearanceSettings extends Table {
  IntColumn get id => integer()();
  TextColumn get theme => text().withDefault(const Constant('system'))();
  BoolColumn get reduceMotion => boolean().withDefault(const Constant(false))();
  BoolColumn get simplerEffects =>
      boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    'CHECK (id = 1)',
    "CHECK (theme IN ('system', 'light', 'dark'))",
  ];
}
