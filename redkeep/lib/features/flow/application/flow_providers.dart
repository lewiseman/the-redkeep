import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/storage_providers.dart';
import '../data/drift_flow_repository.dart';
import '../domain/flow_repository.dart';
import '../domain/thought.dart';

final flowClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);
final flowIdProvider = Provider<String Function()>((ref) {
  final random = Random.secure();
  return () => List.generate(
    16,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
});
final flowRepositoryProvider = Provider<FlowRepository>(
  (ref) => DriftFlowRepository(
    ref.watch(appDatabaseProvider),
    clock: ref.watch(flowClockProvider),
  ),
);
final thoughtsProvider = StreamProvider.autoDispose<List<ThoughtListing>>(
  (ref) => ref.watch(flowRepositoryProvider).watchThoughts(),
  retry: (_, _) => null,
);

final thoughtDocumentProvider = StreamProvider.autoDispose
    .family<OpenThought, String>(
      (ref, id) => ref.watch(flowRepositoryProvider).watchDocument(id),
      retry: (_, _) => null,
    );
