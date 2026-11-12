import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/core/storage/app_database.dart';
import 'package:redkeep/features/ai/domain/ai_conversation.dart';
import 'package:redkeep/features/notes/data/drift_note_chats.dart';
import 'package:redkeep/features/notes/domain/note_chat.dart';

void main() {
  late AppDatabase db;
  late DriftNoteChats chats;
  const note = '0123456789abcdef0123456789abcdef';
  const other = 'fedcba9876543210fedcba9876543210';
  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    chats = DriftNoteChats(db);
  });
  tearDown(() => db.close());

  NoteChatTurn turn(int i, {String noteId = note}) => NoteChatTurn(
    id: 'turn-${i.toString().padLeft(2, '0')}-$noteId',
    noteId: noteId,
    at: DateTime.utc(2026, 1, 1, 0, i),
    ask: 'Ask $i',
    reply: 'Reply $i',
  );

  test('keeps only the latest ten exchanges per note', () async {
    for (var i = 0; i < 13; i++) {
      await chats.add(turn(i));
    }
    await chats.add(turn(0, noteId: other));
    final kept = await chats.turns(note);
    expect(kept.map((t) => t.ask), [for (var i = 3; i < 13; i++) 'Ask $i']);
    expect(await chats.turns(other), hasLength(1));
    await chats.clear(note);
    expect(await chats.turns(note), isEmpty);
    expect(await chats.turns(other), hasLength(1));
  });

  test('records what came of a call and tells it back as history', () async {
    const call = AiToolCall(
      id: 'call_1',
      name: 'update_website',
      arguments: {'instruction': 'Bigger headings'},
    );
    await chats.add(
      NoteChatTurn(
        id: 't1',
        noteId: note,
        at: DateTime.utc(2026),
        ask: 'Make headings bigger',
        actions: const [
          NoteChatAction(call: call, status: NoteChatActionStatus.running),
        ],
      ),
    );
    expect(
      await chats.updateAction(
        't1',
        'call_1',
        (a) => a.copy(status: NoteChatActionStatus.kept),
      ),
      isTrue,
    );
    final exchange = (await chats.turns(note)).single.exchange;
    expect(exchange.calls.single.arguments['instruction'], 'Bigger headings');
    expect(exchange.results.single.content, 'The person kept this change.');
    expect(await chats.updateAction('gone', 'call_1', (a) => a), isFalse);
  });
}
