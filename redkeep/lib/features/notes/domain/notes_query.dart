/// Keyword tokens are literal substrings in title/body, combined with AND.
/// SQLite folds ASCII case; other scripts match exactly. Filters also use AND.
class NotesQuery {
  const NotesQuery({
    this.search = '',
    this.tag,
    this.pinnedOnly = false,
    this.trash = false,
  });
  final String search;
  final String? tag;
  final bool pinnedOnly;
  final bool trash;

  @override
  bool operator ==(Object other) =>
      other is NotesQuery &&
      search == other.search &&
      tag == other.tag &&
      pinnedOnly == other.pinnedOnly &&
      trash == other.trash;
  @override
  int get hashCode => Object.hash(search, tag, pinnedOnly, trash);
}
