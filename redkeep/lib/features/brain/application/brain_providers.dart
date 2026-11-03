import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../app/storage_providers.dart';
import '../../ai/data/flutter_edge_local_model.dart';
import '../data/drift_brain_assignments.dart';
import '../data/file_brain_models.dart';
import '../data/model_download.dart';
import '../domain/brain.dart';
import 'brain_executor.dart';

final brainCatalogProvider = Provider<List<BrainModel>>(
  (ref) => const [qualifiedBrainModel],
);
final brainAssignmentsProvider = Provider<BrainAssignments>(
  (ref) => DriftBrainAssignments(ref.watch(appDatabaseProvider)),
);
final brainModelFilesProvider = FutureProvider<BrainModelFiles>((ref) async {
  final support = await getApplicationSupportDirectory();
  return FileBrainModels(
    root: Directory('${support.path}/brain-models'),
    download: HttpModelDownload(),
    runtimeCacheRoot: support,
  );
});
final brainModelLoaderProvider = Provider<BrainModelLoader>(
  (ref) => openFlutterEdgeModel,
);
final brainExecutorProvider = FutureProvider<BrainExecutor>((ref) async {
  final files = await ref.watch(brainModelFilesProvider.future);
  if (!ref.mounted) throw const BrainException(BrainFailure.disposed);
  final executor = BrainExecutor(
    files: files,
    loadModel: ref.watch(brainModelLoaderProvider),
  );
  ref.onDispose(() => unawaited(executor.dispose()));
  return executor;
});
