import 'dart:async';

import 'package:redkeep/features/flow/domain/thought.dart';
import 'package:redkeep/features/flow/domain/flow_repository.dart';

/// Failure/commit gates wrap a disposable repository, never user storage.
class ControlledFlowRepository implements FlowRepository {
  ControlledFlowRepository(this.inner);
  final FlowRepository inner;
  bool failCommit = false;
  bool failRead = false;
  Completer<void>? commitGate;
  int commits = 0;

  @override
  Future<Thought> save({
    required String id,
    required String body,
    required int expectedRevision,
  }) async {
    commits++;
    await commitGate?.future;
    if (failCommit) throw StateError('synthetic save failure');
    return inner.save(id: id, body: body, expectedRevision: expectedRevision);
  }

  @override
  Future<OpenThought> openDocument(String id) async {
    if (failRead) throw StateError('synthetic read failure');
    return inner.openDocument(id);
  }

  @override
  Stream<OpenThought> watchDocument(String id) => failRead
      ? Stream.error(StateError('synthetic read failure'))
      : inner.watchDocument(id);
  @override
  Stream<List<ThoughtListing>> watchThoughts() => failRead
      ? Stream.error(StateError('synthetic read failure'))
      : inner.watchThoughts();
  @override
  Future<void> deleteThought(String id, int expectedRevision) =>
      inner.deleteThought(id, expectedRevision);
}
