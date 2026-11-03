class Thought {
  const Thought({
    required this.id,
    required this.body,
    required this.revision,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });
  final String id;
  final String body;
  final int revision;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
}

class OpenThought {
  const OpenThought({this.thought});
  final Thought? thought;
  bool get available => thought != null && thought!.deletedAt == null;
}

/// Bounded previews only. Complete text is loaded by ID.
class ThoughtListing {
  const ThoughtListing({
    required this.id,
    required this.preview,
    required this.createdAt,
  });
  final String id;
  final String preview;
  final DateTime createdAt;
}

bool isThoughtId(String value) => RegExp(r'^[0-9a-f]{32}$').hasMatch(value);

enum FlowFailure { unavailable, staleRevision, empty }

class FlowException implements Exception {
  const FlowException(this.failure);
  final FlowFailure failure;
}
