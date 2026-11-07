import 'website/website_contract.dart';

/// A note's generated website. The note's text stays in the note; this page
/// is made from it and kept beside it.
class NoteWebsite {
  const NoteWebsite({
    required this.noteId,
    required this.html,
    required this.sourceHash,
    this.brief = '',
    this.model = '',
    required this.madeAt,
  });

  final String noteId;

  /// The sanitized page.
  final String html;

  /// [websiteContentHash] of the note body the page was made from.
  final String sourceHash;

  /// How the person described the website, reused when it is regenerated.
  final String brief;
  final String model;
  final DateTime madeAt;

  /// Whether [body] changed since this website was made.
  bool isOutdatedFor(String body) => websiteContentHash(body) != sourceHash;
}
