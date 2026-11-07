import 'note_details.dart';

/// A bounded projection for collection cards; full writing stays in storage.
class NoteCollectionEntry {
  const NoteCollectionEntry({
    required this.id,
    this.details = const NoteDetails(),
    required this.title,
    required this.excerpt,
    required this.updatedAt,
    required this.pinned,
    this.hasWebsite = false,
  });

  static const excerptCharacters = 600;
  final String id;
  final NoteDetails details;
  final String title;
  final String excerpt;
  final DateTime updatedAt;
  final bool pinned;

  /// Whether this device holds a generated website for the note.
  final bool hasWebsite;
}
