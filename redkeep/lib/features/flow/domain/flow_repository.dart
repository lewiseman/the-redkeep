import 'thought.dart';

abstract interface class FlowRepository {
  Stream<List<ThoughtListing>> watchThoughts();

  /// Edit drafts only; the single capture draft is restored into the composer.
  Stream<List<ThoughtListing>> watchDrafts();
  Future<ThoughtDraft?> openCapture();
  Stream<OpenThought> watchDocument(String id);
  Future<OpenThought> openDocument(String id);
  Future<ThoughtDraft> putDraft({
    required String id,
    required String body,
    required int baseRevision,
    required int? expectedDraftRevision,
    required bool capture,
  });

  /// Commits the exact draft and removes it in the same transaction.
  Future<Thought> commitDraft(String id, int expectedDraftRevision);
  Future<void> deleteThought(String id, int expectedRevision);
  Future<void> discardDraft(String id, int expectedDraftRevision);
}
