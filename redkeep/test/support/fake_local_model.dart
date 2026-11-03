import 'dart:async';

import 'package:redkeep/features/ai/domain/local_inference.dart';

class FakeModel implements LocalModel {
  final sessions = <FakeSession>[];
  String? failAt;
  bool hold = false;
  int closed = 0;
  Completer<LocalSession>? creation;
  @override
  InferenceBackend get backend => InferenceBackend.cpu;
  @override
  Future<LocalSession> createSession() async {
    if (failAt == 'create') throw StateError('native path and text');
    if (creation != null) return creation!.future;
    final session = FakeSession()
      ..failAt = failAt
      ..hold = hold;
    sessions.add(session);
    return session;
  }

  @override
  Future<void> close() async {
    closed++;
    if (failAt == 'modelClose') throw StateError('native close');
  }
}

class FakeSession implements LocalSession {
  String? failAt;
  String? prompt;
  bool hold = false;
  int stopped = 0;
  int closed = 0;
  final output = StreamController<String>();
  @override
  Future<void> addPrompt(String text) async {
    if (failAt == 'prompt') throw StateError('private native details');
    prompt = text;
  }

  @override
  Stream<String> stream() {
    if (failAt == 'stream') return Stream.error(StateError('private details'));
    if (!hold) return Stream.fromIterable(['one', ' two']);
    output.add('one');
    return output.stream;
  }

  @override
  Future<void> stop() async {
    stopped++;
    output.add('late');
    unawaited(output.close());
    if (failAt == 'stop') throw StateError('stop failed');
  }

  @override
  Future<void> close() async {
    closed++;
    if (failAt == 'close') throw StateError('close failed');
  }
}
