import 'dart:async';

import 'package:redkeep/features/flow/domain/thought.dart';
import 'package:redkeep/features/flow/domain/flow_repository.dart';

/// Failure/commit gates wrap a disposable repository, never user storage.
class ControlledFlowRepository implements FlowRepository {
  ControlledFlowRepository(this.inner);
  final FlowRepository inner;
  bool failDraft = false;
  bool failCommit = false;
  bool failRead = false;
  Completer<void>? draftGate;
  Completer<void>? commitGate;
  int commits = 0;

  @override
  Future<ThoughtDraft> putDraft({
    required String id,
    required bool capture,
    required String body,
    required int baseRevision,
    required int? expectedDraftRevision,
  }) async {
    await draftGate?.future;
    if (failDraft) throw StateError('synthetic recovery failure');
    return inner.putDraft(
      id: id,
      capture: capture,
      body: body,
      baseRevision: baseRevision,
      expectedDraftRevision: expectedDraftRevision,
    );
  }

  @override
  Future<Thought> commitDraft(String id, int expectedDraftRevision) async {
    commits++;
    await commitGate?.future;
    if (failCommit) throw StateError('synthetic commit failure');
    return inner.commitDraft(id, expectedDraftRevision);
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
  Future<ThoughtDraft?> openCapture() async {
    if (failRead) throw StateError('synthetic read failure');
    return inner.openCapture();
  }

  @override
  Stream<List<ThoughtListing>> watchDrafts() => failRead
      ? Stream.error(StateError('synthetic read failure'))
      : inner.watchDrafts();
  @override
  Future<void> deleteThought(String id, int expectedRevision) =>
      inner.deleteThought(id, expectedRevision);
  @override
  Future<void> discardDraft(String id, int expectedDraftRevision) =>
      inner.discardDraft(id, expectedDraftRevision);
}
