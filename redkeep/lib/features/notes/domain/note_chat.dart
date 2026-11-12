import 'dart:convert';

import '../../ai/domain/ai_conversation.dart';

/// Each note keeps only its latest exchanges with the Maester, on this
/// device. Older ones are dropped and no longer sent.
const noteChatKeptTurns = 10;

/// The longest message the person can send.
const noteChatMessageChars = 1000;

/// What became of one tool call the Maester made.
enum NoteChatActionStatus {
  /// Shown to the person (choices); nothing to run.
  shown,

  /// A proposal is being written.
  running,

  /// A proposal is ready to review.
  ready,
  kept,
  discarded,
  failed,
  stopped,

  /// Not run: the call was invalid, or another change came first.
  skipped;

  bool get open => this == running || this == ready;

  static NoteChatActionStatus parse(Object? value) =>
      NoteChatActionStatus.values.firstWhere(
        (s) => s.name == value,
        orElse: () => NoteChatActionStatus.skipped,
      );
}

/// One tool call in a turn, with what came of it.
class NoteChatAction {
  const NoteChatAction({
    required this.call,
    required this.status,
    this.jobId,
    this.detail = '',
  });
  final AiToolCall call;
  final NoteChatActionStatus status;

  /// The proposal's request, while it can still be reviewed.
  final String? jobId;

  /// A short, fixed explanation (why it failed or was skipped).
  final String detail;

  NoteChatAction copy({
    NoteChatActionStatus? status,
    String? jobId,
    String? detail,
  }) => NoteChatAction(
    call: call,
    status: status ?? this.status,
    jobId: jobId ?? this.jobId,
    detail: detail ?? this.detail,
  );

  Map<String, Object?> toJson() => {
    'call': call.toJson(),
    'status': status.name,
    'jobId': ?jobId,
    if (detail.isNotEmpty) 'detail': detail,
  };

  static NoteChatAction? tryParse(Object? value) {
    if (value is! Map) return null;
    final call = AiToolCall.tryParse(value['call']);
    if (call == null) return null;
    return NoteChatAction(
      call: call,
      status: NoteChatActionStatus.parse(value['status']),
      jobId: value['jobId'] is String ? value['jobId'] as String : null,
      detail: value['detail'] is String ? value['detail'] as String : '',
    );
  }

  /// What the Maester is told about this call in later turns.
  String get outcome => switch (status) {
    NoteChatActionStatus.shown => 'Shown to the person.',
    NoteChatActionStatus.running ||
    NoteChatActionStatus.ready => 'Not reviewed yet; it was set aside.',
    NoteChatActionStatus.kept => 'The person kept this change.',
    NoteChatActionStatus.discarded =>
      detail.isEmpty ? 'The person discarded this proposal.' : detail,
    NoteChatActionStatus.failed =>
      'It could not be made${detail.isEmpty ? '' : ': $detail'}',
    NoteChatActionStatus.stopped => 'The person stopped it.',
    NoteChatActionStatus.skipped =>
      'Not run${detail.isEmpty ? '' : ': $detail'}',
  };
}

/// One exchange: the person's message, the Maester's answer and its calls.
class NoteChatTurn {
  const NoteChatTurn({
    required this.id,
    required this.noteId,
    required this.at,
    required this.ask,
    this.reply = '',
    this.actions = const [],
  });
  final String id, noteId, ask, reply;
  final DateTime at;
  final List<NoteChatAction> actions;

  NoteChatTurn withAction(
    String callId,
    NoteChatAction Function(NoteChatAction) change,
  ) => NoteChatTurn(
    id: id,
    noteId: noteId,
    at: at,
    ask: ask,
    reply: reply,
    actions: [for (final a in actions) a.call.id == callId ? change(a) : a],
  );

  /// This turn as conversation history for the model.
  AiExchange get exchange => AiExchange(
    user: ask,
    reply: reply,
    calls: [for (final a in actions) a.call],
    results: [for (final a in actions) AiToolResult(a.call.id, a.outcome)],
  );

  static String encodeActions(List<NoteChatAction> actions) =>
      jsonEncode([for (final a in actions) a.toJson()]);

  static List<NoteChatAction> decodeActions(String raw) {
    try {
      final value = jsonDecode(raw);
      if (value is! List) return const [];
      return [for (final item in value) ?NoteChatAction.tryParse(item)];
    } on FormatException {
      return const [];
    }
  }
}
