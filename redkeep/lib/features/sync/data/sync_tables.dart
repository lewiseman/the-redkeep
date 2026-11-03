import 'package:drift/drift.dart';

class SyncValues extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  @override
  Set<Column> get primaryKey => {key};
}

class SyncRecords extends Table {
  TextColumn get type => text()();
  TextColumn get documentId => text()();
  TextColumn get state => text().withDefault(const Constant('pending'))();
  BoolColumn get removed => boolean().withDefault(const Constant(false))();
  @override
  Set<Column> get primaryKey => {type, documentId};
}

class SyncOperations extends Table {
  TextColumn get type => text()();
  TextColumn get id => text()();
  TextColumn get documentId => text()();
  @override
  Set<Column> get primaryKey => {type, id};
}
