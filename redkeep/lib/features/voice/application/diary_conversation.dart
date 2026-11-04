import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../companion/data/companion_protocol.dart';

/// UI-independent conversation state. Durable entries and drafting are supplied
/// by the Riverpod feature coordinator; live talk only appends original turns.
class DiaryConversation extends ChangeNotifier {
  DiaryConversation({
    required this.computer,
    required this.dateString,
    this.diary,
    required this.writeDraft,
    required this.saveTurns,
  });
  final TrustedComputer Function() computer;
  final String dateString;
  final List<Map<String, Object>> Function()? diary;
  final Future<String> Function() writeDraft;
  final Future<void> Function() saveTurns;
  String id = const Uuid().v4().replaceAll('-', '');
  int created = DateTime.now().millisecondsSinceEpoch;
  String draft = '', message = '';
  List<Map<String, String>> turns = [];
  String? computerId, deviceId, jobState;
  Map<String, dynamic>? pending;
  bool busy = false, saved = false, disposed = false;
  bool get polling => busy;
  Future<void> _tail = Future.value();
  void update() {
    if (!disposed) notifyListeners();
  }

  TrustedComputer trusted() {
    final c = computer();
    if (!c.enabled ||
        computerId != null && (computerId != c.id || deviceId != c.deviceId)) {
      throw const CompanionFailure(
        'UNAUTHORIZED',
        'Reconnect the original computer or start a new conversation.',
      );
    }
    return c;
  }

  Future<void> append(String speaker, String text) async {
    if (saved || text.trim().isEmpty || disposed) return;
    if (!['user', 'assistant'].contains(speaker) || turns.length >= 24) {
      throw const FormatException('Conversation limit reached');
    }
    turns.add({'speaker': speaker, 'text': text.trim()});
    update();
    await persist();
  }

  Future<void> persist() {
    final next = _tail.then((_) => saveTurns());
    _tail = next.catchError((Object _) {});
    return next;
  }

  Future<void> request(String action) async {
    if (busy || disposed) return;
    busy = true;
    jobState = 'queued';
    update();
    try {
      draft = await writeDraft();
      message = '';
      pending = null;
    } catch (e) {
      message = e is CompanionFailure
          ? e.message
          : e is StateError
          ? e.message.toString()
          : 'Your conversation is kept. Could not write the entry; try again.';
    } finally {
      busy = false;
      jobState = null;
      update();
    }
  }

  Future<void> retrieve() => request('draft');
  Future<void> get settled => _tail;
  @override
  void dispose() {
    disposed = true;
    super.dispose();
  }
}
