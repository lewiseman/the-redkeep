import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/storage_providers.dart';
import '../../../core/storage/app_database.dart';
import '../../ai/application/ai_cloud.dart';
import '../../ai/application/ai_jobs.dart';
import '../../ai/domain/ai_conversation.dart';
import '../../ai/domain/ai_provider.dart';
import '../domain/catalog_title.dart';
import '../domain/watch_title.dart';
import 'watchlist_providers.dart';

/// Messages kept per title, on this device only.
const watchChatKept = 40;

/// Exchanges sent back to the model for context.
const watchChatContext = 10;
const watchChatMessageChars = 600;

class WatchChatMessage {
  const WatchChatMessage({
    required this.id,
    required this.fromReader,
    required this.body,
    required this.at,
  });
  final String id;
  final bool fromReader;
  final String body;
  final DateTime at;
}

final watchChatMessagesProvider = StreamProvider.autoDispose
    .family<List<WatchChatMessage>, String>((ref, titleId) {
      final db = ref.watch(appDatabaseProvider);
      return (db.select(db.watchChatTurns)
            ..where((r) => r.titleId.equals(titleId))
            ..orderBy([
              (r) => OrderingTerm.asc(r.at),
              (r) => OrderingTerm.asc(r.id),
            ]))
          .watch()
          .map(
            (rows) => [
              for (final r in rows)
                WatchChatMessage(
                  id: r.id,
                  fromReader: r.fromReader,
                  body: r.body,
                  at: DateTime.fromMillisecondsSinceEpoch(r.at, isUtc: true),
                ),
            ],
          );
    }, retry: (_, _) => null);

class WatchChatState {
  const WatchChatState({this.sending = false, this.error});
  final bool sending;
  final String? error;
}

final watchChatProvider = NotifierProvider.autoDispose
    .family<WatchChatController, WatchChatState, WatchKey>(
      WatchChatController.new,
    );

/// The title speaks for itself, in character, through the reader's own AI
/// provider. Nothing here is synced.
class WatchChatController extends Notifier<WatchChatState> {
  WatchChatController(this.key);
  final WatchKey key;
  Completer<void>? _abort;

  @override
  WatchChatState build() {
    ref.onDispose(() => _abort?.complete());
    return const WatchChatState();
  }

  AppDatabase get _db => ref.read(appDatabaseProvider);

  Future<void> _add(bool fromReader, String body) async {
    final now = ref.read(watchClockProvider)().toUtc().millisecondsSinceEpoch;
    await _db.transaction(() async {
      await _db
          .into(_db.watchChatTurns)
          .insert(
            WatchChatTurnsCompanion.insert(
              id: ref.read(watchIdProvider)(),
              titleId: key.id,
              at: now,
              fromReader: fromReader,
              body: body,
            ),
          );
      final rows =
          await (_db.select(_db.watchChatTurns)
                ..where((r) => r.titleId.equals(key.id))
                ..orderBy([
                  (r) => OrderingTerm.desc(r.at),
                  (r) => OrderingTerm.desc(r.id),
                ]))
              .get();
      for (final old in rows.skip(watchChatKept)) {
        await (_db.delete(
          _db.watchChatTurns,
        )..where((r) => r.id.equals(old.id))).go();
      }
    });
  }

  Future<bool> send(String message) async {
    final ask = message.trim();
    if (state.sending || ask.isEmpty) return false;
    if (ask.runes.length > watchChatMessageChars) {
      state = const WatchChatState(
        error: 'Keep a message to at most $watchChatMessageChars characters.',
      );
      return false;
    }
    final earlier = await ref.read(watchChatMessagesProvider(key.id).future);
    await _add(true, ask);
    return _reply(ask, earlier);
  }

  /// Asks again when the last message went unanswered.
  Future<bool> retry() async {
    final messages = await ref.read(watchChatMessagesProvider(key.id).future);
    if (state.sending || messages.isEmpty || !messages.last.fromReader) {
      return false;
    }
    return _reply(messages.last.body, messages.sublist(0, messages.length - 1));
  }

  Future<bool> _reply(String ask, List<WatchChatMessage> earlier) async {
    final abort = _abort = Completer<void>();
    state = const WatchChatState(sending: true);
    try {
      CatalogTitle title;
      try {
        title = await ref.read(catalogTitleProvider(key).future);
      } on Object {
        title =
            await ref.read(watchlistRepositoryProvider).cachedTitle(key) ??
            CatalogTitle(key: key, title: 'this title');
      }
      final saved = await ref.read(watchTitleProvider(key.id).future);
      final exchanges = exchangesOf(earlier).toList();
      final reply = await ref
          .read(aiCloudProvider)
          .converse(
            system: watchPersonaPrompt(title, saved),
            history: exchanges.length > watchChatContext
                ? exchanges.sublist(exchanges.length - watchChatContext)
                : exchanges,
            user: ask,
            tools: const [],
            outputTokens: 400,
            temperature: .8,
            abort: abort.future,
          );
      if (!ref.mounted || abort.isCompleted) return false;
      final text = reply.text.trim();
      if (text.isEmpty) throw const FormatException('An empty reply.');
      await _add(false, text);
      state = const WatchChatState();
      return true;
    } catch (error) {
      if (!ref.mounted) return false;
      final cancelled =
          error is AiProviderFailure &&
          error.kind == AiProviderFailureKind.cancelled;
      state = WatchChatState(
        error: cancelled
            ? null
            : error is FormatException
            ? 'No reply came back. Try again.'
            : aiErrorMessage(error),
      );
      return false;
    } finally {
      if (identical(_abort, abort)) _abort = null;
    }
  }

  void stop() {
    _abort?.complete();
    _abort = null;
    state = const WatchChatState();
  }

  Future<void> clear() => (_db.delete(
    _db.watchChatTurns,
  )..where((r) => r.titleId.equals(key.id))).go();
}

/// Consecutive messages from the same side merge; an opening line from the
/// title gets a quiet reader turn before it, as every provider expects.
Iterable<AiExchange> exchangesOf(List<WatchChatMessage> messages) sync* {
  String? user;
  final reply = StringBuffer();
  for (final m in messages) {
    if (m.fromReader) {
      if (reply.isNotEmpty) {
        yield AiExchange(user: user ?? '(We just matched.)', reply: '$reply');
        reply.clear();
        user = null;
      }
      user = user == null ? m.body : '$user\n${m.body}';
    } else {
      if (reply.isNotEmpty) reply.write('\n');
      reply.write(m.body);
    }
  }
  if (reply.isNotEmpty) {
    yield AiExchange(user: user ?? '(We just matched.)', reply: '$reply');
  }
}

String watchPersonaPrompt(CatalogTitle title, WatchTitle? saved) {
  final kind = title.media == WatchMedia.tv ? 'TV series' : 'film';
  final relationship = switch (saved) {
    WatchTitle(outcome: NightOutcome.loved) =>
      'You spent a night together and they loved you. You are together now.',
    WatchTitle(outcome: final NightOutcome o?) =>
      'You spent a night together. They said: ${o.label.toLowerCase()}.',
    WatchTitle(matchState: MatchState.dated, :final nightAt?) =>
      'You have a watch night planned for ${nightAt.toLocal()}.',
    WatchTitle(matchState: MatchState.active) =>
      'You just matched and have not planned a night yet.',
    _ => 'You are getting to know each other.',
  };
  final facts = [
    'Title: ${title.title}${title.year == null ? '' : ' (${title.year})'}',
    'Kind: $kind',
    if (title.tagline.isNotEmpty) 'Tagline: ${title.tagline}',
    if (title.genres.isNotEmpty) 'Genres: ${title.genres.join(', ')}',
    if (title.runtime != null)
      title.media == WatchMedia.tv
          ? 'Episode length: ${title.runtime} minutes'
          : 'Runtime: ${title.runtime} minutes',
    if (title.seasons.isNotEmpty) 'Seasons: ${title.seasons.length}',
    if (title.director != null)
      '${title.media == WatchMedia.tv ? 'Created' : 'Directed'} by: ${title.director}',
    if (title.cast.isNotEmpty) 'Cast: ${title.cast.take(5).join(', ')}',
    if (title.keywords.isNotEmpty) 'Themes: ${title.keywords.join(', ')}',
    if (title.providers.isNotEmpty)
      'Streaming on: ${title.providers.join(', ')}',
    if (title.overview.isNotEmpty) 'Story: ${title.overview}',
  ].join('\n');
  return '''
You are the $kind "${title.title}", chatting in a playful dating-app style with someone deciding whether to watch you.

$facts

$relationship

Speak as the $kind in the first person, with its tone and personality. Keep replies to one to three short sentences. Stay warm and PG. Never reveal twists or the ending. Use only the facts above; if unsure, be playfully vague rather than inventing details. If asked whether you are real or an AI, say plainly that you are an AI playing the $kind.''';
}
