import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/storage_providers.dart';
import '../../ai/application/ai_lifecycle.dart';
import '../../companion/application/companion_controller.dart';
import '../../companion/data/companion_protocol.dart';
import '../../sync/application/sync_providers.dart'
    show writingSessionEpochProvider;
import '../data/voice_store.dart';

final voiceReceiptsProvider = Provider<VoiceReceipts>((ref) {
  ref.watch(writingSessionEpochProvider);
  return VoiceReceipts(ref);
});

/// Consuming a transcript removes local audio immediately and durably queues
/// acknowledgement against its original pairing. No speech or writing restarts.
class VoiceReceipts {
  VoiceReceipts(this.ref)
    : generation = ref.read(appDatabaseProvider).writingGeneration;
  final Ref ref;
  final int generation;
  final store = VoiceStore();
  Future<void> _tail = Future.value();
  Future<T> _serial<T>(Future<T> Function() work) {
    final next = _tail.then((_) => work());
    _tail = next.then<void>((_) {}, onError: (Object _) {});
    return next;
  }

  bool get _valid =>
      ref.mounted &&
      !ref.read(appDatabaseProvider).writingBlocked &&
      generation == ref.read(appDatabaseProvider).writingGeneration;
  Future<List<Map<String, dynamic>>> _pending() async => [
    for (final item in (await store.load('acks'))?['items'] as List? ?? [])
      Map<String, dynamic>.from(item as Map),
  ];
  Future<void> consume(String target, {VoiceStore? source}) async {
    source ??= store;
    final data = await source.load(target);
    if (!_valid) throw StateError('Voice session expired');
    if (data?['computer'] is String && data?['device'] is String) {
      await _serial(() async {
        if (!_valid) return;
        final pending = await _pending();
        for (final id in [data!['id'], ...data['previousIds'] as List? ?? []]) {
          if (id is String &&
              !pending.any(
                (r) =>
                    r['id'] == id &&
                    r['computer'] == data['computer'] &&
                    r['device'] == data['device'],
              )) {
            pending.add({
              'id': id,
              'computer': data['computer'],
              'device': data['device'],
              'created': data['created'],
            });
          }
        }
        await store.save('acks', {
          'created': DateTime.now().millisecondsSinceEpoch,
          'items': pending.take(256).toList(),
        });
      });
    }
    await source.consumed(target);
    unawaited(drain().catchError((_) {}));
  }

  Future<void> drain() => _serial(() async {
    if (!_valid || !ref.read(aiForegroundProvider)) return;
    final pending = await _pending(), remaining = <Map<String, dynamic>>[];
    for (final receipt in pending) {
      if (!_valid || !ref.read(aiForegroundProvider)) {
        remaining.add(receipt);
        continue;
      }
      if (DateTime.now().millisecondsSinceEpoch - (receipt['created'] as int) >
          86400000) {
        continue;
      }
      final computer = ref
          .read(companionControllerProvider)
          .computers
          .where(
            (c) =>
                c.id == receipt['computer'] &&
                c.deviceId == receipt['device'] &&
                c.enabled,
          )
          .firstOrNull;
      if (computer == null) {
        remaining.add(receipt);
        continue;
      }
      try {
        await CompanionClient(ref.read(companionTransportProvider))
            .authenticated(computer, 'POST', '/v1/voice/${receipt['id']}/ack');
      } catch (_) {
        remaining.add(receipt);
      }
    }
    if (_valid) {
      if (remaining.isEmpty) {
        await store.clear('acks');
      } else {
        await store.save('acks', {
          'created': DateTime.now().millisecondsSinceEpoch,
          'items': remaining,
        });
      }
    }
  });
}
