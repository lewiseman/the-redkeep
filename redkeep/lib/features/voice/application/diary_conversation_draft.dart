import '../../diary/domain/diary_document.dart';

/// Resolve a recovered draft's original save revision. A secondary device may
/// have appended its previously unsaved turns while the computer was working.
/// Only that exact, still-empty first append can adopt the accepted result.
int conversationDraftRevision(DiaryEntry entry, Map<String, dynamic> source) {
  final turns = source['turns'];
  final savedTurns = entry.conversation?.turns;
  if (source['id'] != entry.id ||
      source['date'] != entry.date.key ||
      source['revision'] is! int ||
      turns is! List ||
      savedTurns == null ||
      turns.length != savedTurns.length) {
    throw StateError(
      'The conversation changed after this draft was requested.',
    );
  }
  for (var i = 0; i < turns.length; i++) {
    final turn = turns[i];
    if (turn is! Map ||
        turn['speaker'] != savedTurns[i]['speaker'] ||
        turn['text'] != savedTurns[i]['text']) {
      throw StateError(
        'The conversation changed after this draft was requested.',
      );
    }
  }
  final revision = source['revision'] as int;
  if (source['new'] == true &&
      revision == 0 &&
      entry.revision == 1 &&
      entry.text.isEmpty &&
      entry.deletedAt == null) {
    return 1;
  }
  return revision;
}
