class AiPreferences {
  const AiPreferences({
    this.collections = const {'note', 'diary', 'thought'},
    this.paused = false,
  });

  /// Kinds of writing the search index covers.
  final Set<String> collections;
  final bool paused;
}
