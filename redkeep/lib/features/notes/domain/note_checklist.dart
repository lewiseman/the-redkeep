/// One `- [ ]` / `- [x]` line of a note.
class NoteChecklistItem {
  const NoteChecklistItem({required this.text, required this.done});

  /// The item as written, Markdown emphasis included.
  final String text;
  final bool done;

  /// The words without `**bold**` or `*italic*` markers, as a page shows them.
  String get plain => noteChecklistPlain(text);

  Map<String, Object> toJson() => {'text': text, 'plain': plain, 'done': done};
}

final _item = RegExp(r'^- \[( |x|X)\] (.*\S)\s*$', multiLine: true);

String noteChecklistPlain(String text) => text
    .replaceAllMapped(RegExp(r'\*\*(.+?)\*\*'), (m) => m[1]!)
    .replaceAllMapped(RegExp(r'\*(.+?)\*'), (m) => m[1]!)
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

/// The note's checklist, in order.
List<NoteChecklistItem> noteChecklist(String body) => [
  for (final m in _item.allMatches(body))
    NoteChecklistItem(text: m[2]!.trim(), done: m[1] != ' '),
];

/// [body] with the checklist item reading [text] ticked or unticked. [text]
/// may be the item as written or its [NoteChecklistItem.plain] words.
/// Returns null unless exactly one item matches, so a page can never change
/// the wrong line or anything that is not a checklist item.
String? setNoteChecklistItem(String body, String text, bool done) {
  final wanted = text.trim();
  final plain = noteChecklistPlain(wanted);
  if (wanted.isEmpty) return null;
  final matches = [
    for (final m in _item.allMatches(body))
      if (m[2]!.trim() == wanted || noteChecklistPlain(m[2]!) == plain) m,
  ];
  if (matches.length != 1) return null;
  final m = matches.single;
  if ((m[1] != ' ') == done) return body;
  final line = '- [${done ? 'x' : ' '}] ${m[2]!.trim()}';
  return body.replaceRange(m.start, m.end, line);
}
