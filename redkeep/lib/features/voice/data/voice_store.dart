import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

/// One protected, recoverable draft per destination. Never synced to Drive.
class VoiceStore {
  VoiceStore({Future<Directory> Function()? supportDirectory})
    : _supportDirectory = supportDirectory ?? getApplicationSupportDirectory;
  final Future<Directory> Function() _supportDirectory;
  static int _epoch = 0;
  static Future<void> _tail = Future.value();
  final int _generation = _epoch;
  static Future<void> _serialize(Future<void> Function() action) {
    final next = _tail.catchError((_) {}).then((_) => action());
    _tail = next;
    return next;
  }

  static const storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      storageNamespace: 'redkeep_companion',
      resetOnError: false,
    ),
    iOptions: IOSOptions(
      accountName: 'redkeep.companion',
      accessibility: KeychainAccessibility.unlocked_this_device,
      synchronizable: false,
    ),
  );
  Future<Directory> directory() async {
    if (_generation != _epoch) throw StateError('Voice session expired');
    final support = await _supportDirectory();
    return Directory('${support.path}/voice_sessions').create(recursive: true);
  }

  Future<Map<String, dynamic>?> load(String target) async {
    final raw = await storage.read(key: 'redkeep.voice.$target');
    if (raw == null) return null;
    final value = jsonDecode(raw) as Map<String, dynamic>;
    if ((value['created'] as int) + 86400000 <=
        DateTime.now().millisecondsSinceEpoch) {
      await clear(target);
      return null;
    }
    return value;
  }

  Future<void> save(String target, Map<String, dynamic> value) =>
      _serialize(() async {
        if (_generation == _epoch) {
          await storage.write(
            key: 'redkeep.voice.$target',
            value: jsonEncode(value),
          );
        }
      });
  Future<void> clear(String target) async {
    await _serialize(() async {
      if (_generation == _epoch) {
        await storage.delete(key: 'redkeep.voice.$target');
      }
    });
  }

  Future<void> cleanup() async {
    await _serialize(() async {
      if (_generation != _epoch) return;
      final all = await storage.readAll();
      final expired = DateTime.now()
          .subtract(const Duration(hours: 24))
          .millisecondsSinceEpoch;
      for (final entry in all.entries.toList()) {
        if (!entry.key.startsWith('redkeep.voice.')) continue;
        try {
          final value = jsonDecode(entry.value) as Map;
          if (value['created'] is int && value['created'] < expired) {
            await storage.delete(key: entry.key);
          }
        } catch (_) {
          /* A corrupt draft remains available for explicit replacement. */
        }
      }
    });
    final root = await directory(),
        cutoff = DateTime.now().subtract(const Duration(hours: 24));
    await for (final entity in root.list(followLinks: false)) {
      if (entity is File && (await entity.stat()).modified.isBefore(cutoff)) {
        await entity.delete();
      }
    }
  }

  Future<void> deleteAudio(String id) async {
    if (!RegExp(r'^[a-zA-Z0-9_-]{8,80}$').hasMatch(id)) return;
    final file = File('${(await directory()).path}/$id.pcm');
    if (await file.exists()) await file.delete();
  }

  Future<void> consumed(String target) async {
    final data = await load(target);
    await clear(target);
    if (data != null) {
      await deleteAudio(data['id'] as String);
      for (final id in (data['previousIds'] as List? ?? []).cast<String>()) {
        await deleteAudio(id);
      }
    }
  }

  Future<void> clearAll() async {
    _epoch++;
    await _serialize(() async {
      final all = await storage.readAll();
      for (final key
          in all.keys.where((k) => k.startsWith('redkeep.voice.')).toList()) {
        await storage.delete(key: key);
      }
    });
    final support = await _supportDirectory();
    final root = Directory('${support.path}/voice_sessions');
    if (await root.exists()) await root.delete(recursive: true);
  }
}
