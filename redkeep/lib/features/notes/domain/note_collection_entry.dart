/// A bounded projection for collection cards; full writing stays in storage.
class NoteCollectionEntry {
  const NoteCollectionEntry({
    required this.id,
    required this.title,
    required this.excerpt,
    required this.updatedAt,
    required this.pinned,
    required this.isDraft,
    required this.sourceUnavailable,
  });

  static const excerptCharacters = 600;
  final String id;
  final String title;
  final String excerpt;
  final DateTime updatedAt;
  final bool pinned;
  final bool isDraft;
  final bool sourceUnavailable;
}
