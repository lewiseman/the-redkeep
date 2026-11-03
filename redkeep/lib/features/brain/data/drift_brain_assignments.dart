import '../../../core/storage/app_database.dart';
import '../domain/brain.dart';

class DriftBrainAssignments implements BrainAssignments {
  DriftBrainAssignments(this.database);
  final AppDatabase database;

  @override
  Future<List<BrainAssignment>> read() async =>
      (await database.select(database.brainAssignmentsTable).get())
          .map(
            (row) => BrainAssignment(
              capability: BrainCapability.values.byName(row.capability),
              modelId: row.modelId,
            ),
          )
          .toList(growable: false);

  @override
  Future<void> assign(BrainCapability capability, String? modelId) async {
    if (modelId == null) {
      await (database.delete(
        database.brainAssignmentsTable,
      )..where((row) => row.capability.equals(capability.name))).go();
    } else {
      await database
          .into(database.brainAssignmentsTable)
          .insertOnConflictUpdate(
            BrainAssignmentsTableCompanion.insert(
              capability: capability.name,
              modelId: modelId,
            ),
          );
    }
  }
}
