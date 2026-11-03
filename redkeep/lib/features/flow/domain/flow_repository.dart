import 'thought.dart';

abstract interface class FlowRepository {
  Stream<List<ThoughtListing>> watchThoughts();

  Stream<OpenThought> watchDocument(String id);
  Future<OpenThought> openDocument(String id);
  Future<Thought> save({
    required String id,
    required String body,
    required int expectedRevision,
  });
  Future<void> deleteThought(String id, int expectedRevision);
}
